-- ============================================================================
-- GameState.lua - 游戏状态机
-- 管理游戏流程：playing → levelup → playing → victory/gameover
-- ============================================================================

local Config = require("Config")
local Player = require("Player")
local EnemySpawner = require("EnemySpawner")
local Weapon = require("Weapon")
local Particle = require("Particle")
local Upgrade = require("Upgrade")
local Collision = require("Collision")

local GameState = {}

--- 初始化/重置游戏
function GameState.Init()
    GameState.state = "playing"  -- playing / levelup / victory / gameover
    GameState.xpGems = {}        -- 掉落的经验宝石列表
    GameState.enemyBullets = {}  -- 敌人子弹列表 {x,y,vx,vy,damage,radius,lifetime,alive}
    GameState.pendingLevelUp = false

    Player.Init()
    EnemySpawner.Init()
    Weapon.Init()
    Particle.Init()
    Upgrade.Init()

    print("[GameState] Game initialized. State = playing")
end

--- 每帧更新
---@param dt number 帧间隔
---@param inputX number 摇杆输入 X [-1, 1]
---@param inputY number 摇杆输入 Y [-1, 1]
function GameState.Update(dt, inputX, inputY)
    if GameState.state ~= "playing" then return end

    -- 1. 更新玩家移动
    Player.Update(dt, inputX, inputY)

    -- 2. 更新波次系统
    EnemySpawner.Update(dt)

    -- 3. 更新敌人移动和 AI（返回射击信息）
    local shots = EnemySpawner.UpdateEnemies(dt, Player.x, Player.y)

    -- 4. 处理敌人射击：创建敌人子弹
    for _, s in ipairs(shots) do
        table.insert(GameState.enemyBullets, {
            x = s.x, y = s.y,
            vx = s.vx, vy = s.vy,
            damage = s.damage,
            radius = s.radius,
            lifetime = s.lifetime,
            alive = true,
        })
    end

    -- 5. 更新敌人子弹
    for i = #GameState.enemyBullets, 1, -1 do
        local b = GameState.enemyBullets[i]
        if b.alive then
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            b.lifetime = b.lifetime - dt
            -- 超时或出界
            if b.lifetime <= 0
                or b.x < -20 or b.x > Config.ROOM_WIDTH + 20
                or b.y < -20 or b.y > Config.ROOM_HEIGHT + 20 then
                b.alive = false
            end
        end
        if not b.alive then
            table.remove(GameState.enemyBullets, i)
        end
    end

    -- 6. 检查敌人子弹命中玩家
    for _, b in ipairs(GameState.enemyBullets) do
        if b.alive then
            if Collision.CircleCircle(Player.x, Player.y, Player.radius,
                b.x, b.y, b.radius) then
                b.alive = false
                local dead = Player.TakeDamage(b.damage)
                if dead then
                    GameState.state = "gameover"
                    print("[GameState] Player killed by enemy bullet! State = gameover")
                    return
                end
            end
        end
    end

    -- 7. 通用伤害回调（玩家武器 → 敌人）
    local function onHitEnemy(enemy, damage)
        local killed = enemy:TakeDamage(damage)
        Particle.SpawnDamageNumber(enemy.x, enemy.y, damage)
        if killed then
            GameState._OnEnemyKilled(enemy)
        end
    end

    -- 8. 更新武器（自动攻击），剑命中走回调
    Weapon.Update(dt, Player, EnemySpawner.enemies, onHitEnemy)

    -- 9. 检查投射物碰撞
    Weapon.CheckProjectileCollisions(EnemySpawner.enemies, onHitEnemy)

    -- 10. 检查敌人碰撞玩家（区分类型）
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive then
            if Collision.CircleCircle(Player.x, Player.y, Player.radius,
                e.x, e.y, e.radius) then
                if e.aiType == "mob_common" then
                    -- 近战攻击有间隔
                    if e:CanMeleeAttack() then
                        local dead = Player.TakeDamage(e.damage)
                        if dead then
                            GameState.state = "gameover"
                            print("[GameState] Player died! State = gameover")
                            return
                        end
                    end
                elseif e.aiType == "mob_clash" and e.aiState == "charging" then
                    -- 冲锋中碰到玩家造成伤害，并结束冲锋
                    local dead = Player.TakeDamage(e.damage)
                    e.aiState = "cooldown"
                    e.aiTimer = 0.6
                    if dead then
                        GameState.state = "gameover"
                        print("[GameState] Player killed by charge! State = gameover")
                        return
                    end
                end
                -- mob_shooter 碰到玩家不造成接触伤害（它靠子弹攻击）
            end
        end
    end

    -- 11. 经验宝石拾取
    for i = #GameState.xpGems, 1, -1 do
        local g = GameState.xpGems[i]
        if g.alive then
            if Collision.CircleCircle(Player.x, Player.y, Player.xpPickupRadius,
                g.x, g.y, Config.XP_GEM_RADIUS) then
                g.alive = false
                Particle.SpawnXPSparkle(g.x, g.y)
                local leveledUp = Player.AddXP(g.value)
                if leveledUp then
                    GameState.state = "levelup"
                    GameState.pendingLevelUp = true
                    print("[GameState] Level up! State = levelup")
                end
                table.remove(GameState.xpGems, i)
            end
        end
    end

    -- 12. 更新粒子
    Particle.Update(dt)

    -- 13. 检查胜利条件
    if EnemySpawner.IsAllDone() then
        local alive = 0
        for _, e in ipairs(EnemySpawner.enemies) do
            if e.alive then alive = alive + 1 end
        end
        if alive == 0 and #GameState.xpGems == 0 then
            GameState.state = "victory"
            print("[GameState] Victory! All waves cleared. State = victory")
        end
    end
end

--- 敌人被击杀的处理
---@param enemy EnemyObj
function GameState._OnEnemyKilled(enemy)
    Player.kills = Player.kills + 1
    Particle.SpawnDeathPuff(enemy.x, enemy.y, enemy.color)

    -- 掉落经验宝石
    table.insert(GameState.xpGems, {
        x = enemy.x + (math.random() - 0.5) * 10,
        y = enemy.y + (math.random() - 0.5) * 10,
        value = enemy.xpValue,
        alive = true,
    })
end

--- 应用升级选择
---@param upgrade table|nil
function GameState.ApplyUpgrade(upgrade)
    if upgrade then
        Upgrade.Apply(upgrade, Player)
    end
    GameState.state = "playing"
    GameState.pendingLevelUp = false
    print("[GameState] Upgrade applied, back to playing.")
end

--- 重新开始游戏
function GameState.Restart()
    print("[GameState] Restarting game...")
    GameState.Init()
end

return GameState
