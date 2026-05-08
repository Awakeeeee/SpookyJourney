-- ============================================================================
-- GameState.lua - 游戏状态机
-- 管理游戏流程：playing → room_clear → transition → playing(下一房间)
-- ============================================================================

local Config = require("Config")
local Player = require("Player")
local EnemySpawner = require("EnemySpawner")
local Weapon = require("Weapon")
local Particle = require("Particle")
local Upgrade = require("Upgrade")
local Collision = require("Collision")
local Inventory = require("Inventory")
local ItemDB = require("ItemDB")

local GameState = {}

--- 初始化/重置游戏（完全重置，包括 depth）
function GameState.Init()
    GameState.state = "playing"  -- playing / levelup / room_clear / transition / gameover / victory
    GameState.depth = 1          -- 当前房间层数
    GameState.xpGems = {}
    GameState.enemyBullets = {}
    GameState.doors = {}         -- 通关后出现的门列表
    GameState.transitionTimer = 0
    GameState.pendingLevelUp = false

    -- 房间类型
    GameState.currentRoomType = "combat"
    GameState.selectedDoorType = nil

    -- 撤离房状态
    GameState.evacuationTimer = 0
    GameState.evacuationActive = false

    -- 恢复房状态
    GameState.recoveryUsed = false

    -- 宝箱状态
    GameState.chest = nil           -- 宝箱实体 {x, y, alive, locked, shakeTimer, shakeCooldown}
    GameState.chestInventory = nil  -- 宝箱背包 (Inventory)
    GameState.chestInRange = false  -- 玩家是否在检测范围内

    Player.Init()
    EnemySpawner.Init()
    Weapon.Init()
    Particle.Init()
    Upgrade.Init()

    -- 生成宝箱
    GameState._SpawnChest()

    print("[GameState] Game initialized. Depth = 1, State = playing")
end

--- 每帧更新
---@param dt number 帧间隔
---@param inputX number 摇杆输入 X [-1, 1]
---@param inputY number 摇杆输入 Y [-1, 1]
function GameState.Update(dt, inputX, inputY)

    -- ================================================================
    -- 非战斗房间（恢复/撤离）：playing 状态的独立逻辑
    -- ================================================================
    if GameState.state == "playing" and GameState.currentRoomType ~= "combat" then
        Player.Update(dt, inputX, inputY)
        Particle.Update(dt)

        local cx = Config.ROOM_WIDTH / 2
        local cy = Config.ROOM_HEIGHT / 2

        if GameState.currentRoomType == "evacuation" then
            local zCfg = Config.ROOM_TYPES.evacuation.zone
            local dist = Collision.Distance(Player.x, Player.y, cx, cy)
            local inZone = (dist < zCfg.radius)

            if inZone then
                if not GameState.evacuationActive then
                    GameState.evacuationActive = true
                end
                GameState.evacuationTimer = GameState.evacuationTimer - dt
                if GameState.evacuationTimer <= 0 then
                    GameState.evacuationTimer = 0
                    GameState.state = "victory"
                    print("[GameState] Evacuation complete! VICTORY!")
                    return
                end
            else
                if GameState.evacuationActive then
                    GameState.evacuationTimer = zCfg.countdownTime
                    GameState.evacuationActive = false
                end
            end

        elseif GameState.currentRoomType == "recovery" then
            local zCfg = Config.ROOM_TYPES.recovery.zone
            local dist = Collision.Distance(Player.x, Player.y, cx, cy)
            local inZone = (dist < zCfg.radius)

            if inZone and not GameState.recoveryUsed then
                local healAmount = math.floor(Player.maxHp * zCfg.healPercent)
                Player.hp = math.min(Player.maxHp, Player.hp + healAmount)
                GameState.recoveryUsed = true
                Particle.SpawnHealNumber(Player.x, Player.y - 20, healAmount)
                print("[GameState] Recovery: +" .. healAmount .. " HP")
            end
        end

        -- 门旋转
        for _, door in ipairs(GameState.doors) do
            door.rotation = door.rotation + Config.DOOR.rotateSpeed * dt
        end

        -- 门碰撞检测
        for _, door in ipairs(GameState.doors) do
            if Collision.CircleCircle(Player.x, Player.y, Player.radius,
                door.x, door.y, Config.DOOR.triggerRadius) then
                GameState.selectedDoorType = door.type
                GameState.state = "transition"
                GameState.transitionTimer = Config.TRANSITION_TIME
                print("[GameState] Door touched (" .. door.type .. ")! Transitioning...")
                return
            end
        end
        return  -- 非战斗房到此结束，不进入下方战斗逻辑
    end

    -- ================================================================
    -- room_clear: 玩家可移动，等待选门
    -- ================================================================
    if GameState.state == "room_clear" then
        Player.Update(dt, inputX, inputY)
        Particle.Update(dt)

        -- 经验球自动吸向玩家
        local attractSpeed = 300
        for i = #GameState.xpGems, 1, -1 do
            local g = GameState.xpGems[i]
            if g.alive then
                local dx = Player.x - g.x
                local dy = Player.y - g.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < Config.XP_GEM_RADIUS + Player.radius then
                    -- 拾取
                    g.alive = false
                    Particle.SpawnXPSparkle(g.x, g.y)
                    local leveledUp = Player.AddXP(g.value)
                    if leveledUp then
                        GameState.state = "levelup"
                        GameState.pendingLevelUp = true
                    end
                    table.remove(GameState.xpGems, i)
                else
                    -- 向玩家移动
                    local spd = attractSpeed * dt / dist
                    g.x = g.x + dx * spd
                    g.y = g.y + dy * spd
                end
            end
        end

        -- 更新宝箱（room_clear 阶段也需要检测）
        GameState.UpdateChest(dt)

        -- 更新门旋转
        for _, door in ipairs(GameState.doors) do
            door.rotation = door.rotation + Config.DOOR.rotateSpeed * dt
        end

        -- 检测玩家与门碰撞
        for _, door in ipairs(GameState.doors) do
            if Collision.CircleCircle(Player.x, Player.y, Player.radius,
                door.x, door.y, Config.DOOR.triggerRadius) then
                GameState.selectedDoorType = door.type
                GameState.state = "transition"
                GameState.transitionTimer = Config.TRANSITION_TIME
                print("[GameState] Door touched (" .. door.type .. ")! Transitioning...")
                return
            end
        end
        return
    end

    -- ================================================================
    -- transition: 短暂过渡后进入下一房间
    -- ================================================================
    if GameState.state == "transition" then
        GameState.transitionTimer = GameState.transitionTimer - dt
        if GameState.transitionTimer <= 0 then
            GameState._EnterNextRoom()
        end
        return
    end

    -- ================================================================
    -- playing: 正常战斗
    -- ================================================================
    if GameState.state ~= "playing" then return end

    -- 1. 更新玩家移动
    Player.Update(dt, inputX, inputY)

    -- 2. 更新波次系统
    EnemySpawner.Update(dt)

    -- 3. 更新敌人移动和 AI（返回射击信息和近战命中）
    local shots, meleeHits = EnemySpawner.UpdateEnemies(dt, Player.x, Player.y)

    -- 4. 处理近战命中（mob_common lunge）
    for _, hit in ipairs(meleeHits) do
        local dead = Player.TakeDamage(hit.damage)
        if dead then
            GameState.state = "gameover"
            print("[GameState] Player killed by melee lunge! State = gameover")
            return
        end
    end

    -- 5. 处理敌人射击：创建敌人子弹
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

    -- 6. 更新敌人子弹
    for i = #GameState.enemyBullets, 1, -1 do
        local b = GameState.enemyBullets[i]
        if b.alive then
            b.x = b.x + b.vx * dt
            b.y = b.y + b.vy * dt
            b.lifetime = b.lifetime - dt
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

    -- 7. 检查敌人子弹命中玩家
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

    -- 8. 通用伤害回调（玩家武器 → 敌人）
    local function onHitEnemy(enemy, damage)
        local killed = enemy:TakeDamage(damage)
        Particle.SpawnDamageNumber(enemy.x, enemy.y, damage)
        if killed then
            GameState._OnEnemyKilled(enemy)
        end
    end

    -- 9. 更新武器（自动攻击），剑命中走回调
    Weapon.Update(dt, Player, EnemySpawner.enemies, onHitEnemy)

    -- 10. 检查投射物碰撞
    Weapon.CheckProjectileCollisions(EnemySpawner.enemies, onHitEnemy)

    -- 11. 检查 mob_clash 冲锋碰撞玩家
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive and e.aiType == "mob_clash" and e.aiState == "charging" then
            if Collision.CircleCircle(Player.x, Player.y, Player.radius,
                e.x, e.y, e.radius) then
                local dead = Player.TakeDamage(e.damage)
                e.aiState = "cooldown"
                e.aiTimer = 0.6
                if dead then
                    GameState.state = "gameover"
                    print("[GameState] Player killed by charge! State = gameover")
                    return
                end
            end
        end
    end

    -- 12. 经验宝石拾取
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

    -- 13. 更新粒子
    Particle.Update(dt)

    -- 14. 更新宝箱（检测距离、摇晃计时等）
    GameState.UpdateChest(dt)

    -- 15. 检查房间通关（所有波次完成 + 无存活敌人）
    if EnemySpawner.IsAllDone() then
        local alive = 0
        for _, e in ipairs(EnemySpawner.enemies) do
            if e.alive then alive = alive + 1 end
        end
        if alive == 0 then
            GameState._OnRoomCleared()
        end
    end
end

-- ============================================================================
-- 房间推进
-- ============================================================================

--- 房间通关：生成门
function GameState._OnRoomCleared()
    GameState.doors = GameState._GenerateDoors()
    GameState._UnlockChest()
    GameState.state = "room_clear"
    print("[GameState] Room cleared! Depth=" .. GameState.depth .. " Doors generated: " .. #GameState.doors)
end

--- 进入下一房间
function GameState._EnterNextRoom()
    local doorType = GameState.selectedDoorType or "combat"
    local isBackDoor = (doorType == "back")
    local roomType = isBackDoor and "combat" or doorType

    -- Depth：back 门不增加层数
    if not isBackDoor then
        GameState.depth = GameState.depth + 1
    end

    -- 通用重置
    GameState.currentRoomType = roomType
    GameState.selectedDoorType = nil
    GameState.doors = {}
    GameState.xpGems = {}
    GameState.enemyBullets = {}
    Weapon.ClearProjectiles()
    Player.x = Config.ROOM_WIDTH / 2
    Player.y = Config.ROOM_HEIGHT / 2

    local rtCfg = Config.ROOM_TYPES[roomType]

    -- 敌人
    if rtCfg.hasEnemies then
        EnemySpawner.Init()
    else
        EnemySpawner.enemies = {}
        EnemySpawner.waveState = "done"
        EnemySpawner.warnings = {}
        EnemySpawner.spawnQueue = {}
    end

    -- 宝箱
    if rtCfg.hasChest then
        GameState._SpawnChest()
    else
        GameState.chest = nil
        GameState.chestInventory = nil
        GameState.chestInRange = false
    end

    -- 撤离房初始化
    GameState.evacuationActive = false
    if roomType == "evacuation" then
        GameState.evacuationTimer = Config.ROOM_TYPES.evacuation.zone.countdownTime
    else
        GameState.evacuationTimer = 0
    end

    -- 恢复房初始化
    GameState.recoveryUsed = false

    -- 非战斗房进入即生成门
    if rtCfg.doorsOnEntry then
        GameState.doors = GameState._GenerateDoors()
    end

    GameState.state = "playing"
    print("[GameState] Room depth=" .. GameState.depth .. " type=" .. roomType)
end

--- 根据当前房间类型随机生成门类型列表（仅战斗房需要随机）
---@param count number
---@return string[]
function GameState._RollDoorTypes(count)
    local roomType = GameState.currentRoomType

    if roomType == "evacuation" then
        -- 撤离房：仅 1 个 back 门
        local types = {}
        for i = 1, count do types[i] = "back" end
        return types
    end

    if roomType == "recovery" then
        -- 恢复房：全部 combat 门
        local types = {}
        for i = 1, count do types[i] = "combat" end
        return types
    end

    -- 战斗房：第 1 个固定 combat，其余按概率随机
    local types = { "combat" }
    local gen = Config.DOOR_GENERATION
    for i = 2, count do
        local r = math.random()
        if GameState.depth >= gen.evacuationMinDepth and r < gen.evacuationChance then
            types[i] = "evacuation"
        elseif r < gen.evacuationChance + gen.recoveryChance then
            types[i] = "recovery"
        else
            types[i] = "combat"
        end
    end
    return types
end

--- 生成门（四面墙随机位置，类型由房间规则决定）
---@return table[] doors
function GameState._GenerateDoors()
    local doors = {}
    local rtCfg = Config.ROOM_TYPES[GameState.currentRoomType]
    local count = rtCfg.doorCount
    local margin = 40  -- 距离墙角最小距离
    local W = Config.ROOM_WIDTH
    local H = Config.ROOM_HEIGHT

    -- 可选墙壁及其生成范围
    local walls = {
        { wall = "top",    genX = true,  fixed = 0, min = margin, max = W - margin },
        { wall = "bottom", genX = true,  fixed = H, min = margin, max = W - margin },
        { wall = "left",   genX = false, fixed = 0, min = margin, max = H - margin },
        { wall = "right",  genX = false, fixed = W, min = margin, max = H - margin },
    }

    -- 随机打乱墙壁顺序
    for i = #walls, 2, -1 do
        local j = math.random(1, i)
        walls[i], walls[j] = walls[j], walls[i]
    end

    -- 生成门类型列表
    local doorTypes = GameState._RollDoorTypes(count)

    -- 在前 count 面墙上各放一扇门
    for i = 1, math.min(count, #walls) do
        local w = walls[i]
        local pos = math.random(w.min, w.max)
        local x, y
        if w.genX then
            x, y = pos, w.fixed
        else
            x, y = w.fixed, pos
        end
        table.insert(doors, {
            x = x,
            y = y,
            wall = w.wall,
            rotation = math.random() * math.pi * 2,
            type = doorTypes[i],
        })
    end

    return doors
end

-- ============================================================================
-- DEBUG
-- ============================================================================

--- DEBUG: 立即通关当前房间（仅战斗房有效）
function GameState.DebugClearRoom()
    if GameState.state ~= "playing" then return end
    if GameState.currentRoomType ~= "combat" then
        print("[GameState] DEBUG: Can only clear combat rooms!")
        return
    end
    print("[GameState] DEBUG: Clearing room!")

    -- 杀死所有存活敌人（触发掉落经验球）
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive then
            e.alive = false
            GameState._OnEnemyKilled(e)
        end
    end

    -- 强制完成所有波次（设为最后一波 + done）
    EnemySpawner.waveIndex = #Config.WAVES
    EnemySpawner.waveState = "done"
    EnemySpawner.spawnQueue = {}
    EnemySpawner.warnings = {}

    -- 清除敌人子弹
    GameState.enemyBullets = {}

    -- 直接进入通关状态（生成门 + 经验球将自动吸附）
    GameState._OnRoomCleared()
end

-- ============================================================================
-- 其他
-- ============================================================================

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

-- ============================================================================
-- 宝箱系统
-- ============================================================================

--- 生成宝箱（随机位置 + 随机物品）
function GameState._SpawnChest()
    local cc = Config.CHEST
    local margin = cc.MARGIN
    local x = math.random(margin, Config.ROOM_WIDTH - margin)
    local y = math.random(margin, Config.ROOM_HEIGHT - margin)

    GameState.chest = {
        x = x,
        y = y,
        alive = true,
        locked = true,        -- 房间未通关时锁定
        shakeTimer = 0,       -- 摇晃动画计时
        shakeCooldown = 0,    -- 摇晃冷却计时
    }

    -- 创建宝箱背包并填入随机物品
    GameState.chestInventory = Inventory.New(8, 3)
    local totalProtos = #ItemDB.PROTOTYPES
    for i = 1, cc.ITEM_COUNT do
        local protoId = math.random(1, totalProtos)
        local item = ItemDB.CreateItem(protoId)
        if item then
            GameState.chestInventory:AddItem(item)
        end
    end

    GameState.chestInRange = false
    print("[GameState] Chest spawned at (" .. x .. ", " .. y .. ") with " .. cc.ITEM_COUNT .. " items")
end

--- 每帧更新宝箱状态（距离检测、摇晃动画）
---@param dt number
function GameState.UpdateChest(dt)
    local chest = GameState.chest
    if not chest or not chest.alive then return end

    local cc = Config.CHEST
    local dist = Collision.Distance(Player.x, Player.y, chest.x, chest.y)
    local inRange = dist < cc.DETECT_RADIUS

    GameState.chestInRange = inRange

    -- 更新摇晃计时器
    if chest.shakeTimer > 0 then
        chest.shakeTimer = chest.shakeTimer - dt
        if chest.shakeTimer < 0 then chest.shakeTimer = 0 end
    end

    -- 更新冷却计时器
    if chest.shakeCooldown > 0 then
        chest.shakeCooldown = chest.shakeCooldown - dt
        if chest.shakeCooldown < 0 then chest.shakeCooldown = 0 end
    end

    -- 锁定状态下，玩家进入范围触发摇晃
    if chest.locked and inRange then
        if chest.shakeTimer <= 0 and chest.shakeCooldown <= 0 then
            chest.shakeTimer = cc.SHAKE_DURATION
            chest.shakeCooldown = cc.SHAKE_COOLDOWN
        end
    end
end

--- 房间通关时解锁宝箱
function GameState._UnlockChest()
    if GameState.chest and GameState.chest.alive then
        GameState.chest.locked = false
        print("[GameState] Chest unlocked!")
    end
end

--- 查询是否可以打开宝箱（房间通关 + 玩家在范围内 + 宝箱存活）
---@return boolean
function GameState.CanOpenChest()
    local chest = GameState.chest
    if not chest or not chest.alive then return false end
    if chest.locked then return false end
    return GameState.chestInRange
end

--- 获取宝箱背包数据（供 UI 使用）
---@return InventoryData|nil
function GameState.GetChestInventory()
    return GameState.chestInventory
end

return GameState
