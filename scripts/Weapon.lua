-- ============================================================================
-- Weapon.lua - 武器系统（自动攻击）
-- ============================================================================

local Config = require("Config")
local Collision = require("Collision")
local Projectile = require("Projectile")

local Weapon = {}

--- 武器运行时状态
---@class WeaponState
---@field cooldownTimer number
---@field sweepTimer number 剑的挥砍动画计时
---@field sweepAngle number 当前挥砍角度

--- 初始化武器系统
function Weapon.Init()
    Weapon.states = {}       -- 每种武器的运行时状态
    Weapon.projectiles = {}  -- 所有活跃投射物
    Weapon.sweepEffects = {} -- 剑挥砍特效 { x, y, angle, timer, maxTime, radius, sweepAngle }

    for name, _ in pairs(Config.WEAPONS) do
        Weapon.states[name] = {
            cooldownTimer = 0,
            sweepTimer = 0,
            sweepAngle = 0,
        }
    end
end

--- 每帧更新武器系统
---@param dt number
---@param player table Player模块
---@param enemies table 敌人列表
---@param onSwordHit function|nil 剑命中回调 (enemy, damage)
function Weapon.Update(dt, player, enemies, onSwordHit)
    -- 更新每个拥有的武器
    for _, weaponName in ipairs(player.weapons) do
        local state = Weapon.states[weaponName]
        local cfg = Config.WEAPONS[weaponName]
        if state and cfg then
            state.cooldownTimer = state.cooldownTimer - dt
            if state.cooldownTimer <= 0 then
                Weapon._Fire(weaponName, cfg, state, player, enemies, onSwordHit)
                state.cooldownTimer = cfg.cooldown
            end
        end
    end

    -- 更新投射物
    for i = #Weapon.projectiles, 1, -1 do
        local p = Weapon.projectiles[i]
        p:Update(dt)
        if not p.alive then
            table.remove(Weapon.projectiles, i)
        end
    end

    -- 更新挥砍特效
    for i = #Weapon.sweepEffects, 1, -1 do
        local e = Weapon.sweepEffects[i]
        e.timer = e.timer - dt
        if e.timer <= 0 then
            table.remove(Weapon.sweepEffects, i)
        end
    end
end

--- 处理投射物与敌人的碰撞
---@param enemies table
---@param onHit function(enemy, damage, projectile) 命中回调
function Weapon.CheckProjectileCollisions(enemies, onHit)
    for _, p in ipairs(Weapon.projectiles) do
        if p.alive then
            for _, e in ipairs(enemies) do
                if e.alive and not p:HasHit(e) then
                    if Collision.CircleCircle(p.x, p.y, p.radius, e.x, e.y, e.radius) then
                        p:HitEnemy(e)
                        if onHit then
                            onHit(e, p.damage, p)
                        end
                        -- 魔杖火球：碰撞后爆炸
                        if p.weaponType == "wand" then
                            Weapon._Explode(p, enemies, onHit)
                            p.alive = false
                        end
                    end
                end
            end
        end
    end
end

--- 发射武器
function Weapon._Fire(weaponName, cfg, state, player, enemies, onSwordHit)
    if weaponName == "sword" then
        Weapon._FireSword(cfg, state, player, enemies, onSwordHit)
    elseif weaponName == "knife" then
        Weapon._FireKnife(cfg, player, enemies)
    elseif weaponName == "wand" then
        Weapon._FireWand(cfg, player, enemies)
    end
end

--- 剑：扇形挥砍
function Weapon._FireSword(cfg, state, player, enemies, onSwordHit)
    local halfAngle = math.rad(cfg.sweepAngle / 2)

    -- 添加挥砍特效
    table.insert(Weapon.sweepEffects, {
        x = player.x,
        y = player.y,
        angle = player.facing,
        timer = cfg.sweepDuration,
        maxTime = cfg.sweepDuration,
        radius = cfg.sweepRadius,
        sweepAngle = cfg.sweepAngle,
    })

    -- 判定伤害：扇形范围内所有敌人，通过回调处理
    for _, e in ipairs(enemies) do
        if e.alive then
            if Collision.PointInFan(e.x, e.y, player.x, player.y,
                cfg.sweepRadius + e.radius, player.facing, halfAngle) then
                if onSwordHit then
                    onSwordHit(e, cfg.damage)
                else
                    e:TakeDamage(cfg.damage)
                end
            end
        end
    end
end

--- 飞刀：随机索敌，发射可穿透投射物
function Weapon._FireKnife(cfg, player, enemies)
    local target = Weapon._RandomTarget(player, enemies, 300)
    if not target then return end

    local dx = target.x - player.x
    local dy = target.y - player.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local vx = (dx / dist) * cfg.speed
    local vy = (dy / dist) * cfg.speed

    local proj = Projectile.new("knife", player.x, player.y, vx, vy,
        cfg.damage, cfg.radius, cfg.pierce, cfg.lifetime)
    table.insert(Weapon.projectiles, proj)
end

--- 魔杖：随机索敌，发射火球
function Weapon._FireWand(cfg, player, enemies)
    local target = Weapon._RandomTarget(player, enemies, 400)
    if not target then return end

    local dx = target.x - player.x
    local dy = target.y - player.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1 then return end

    local vx = (dx / dist) * cfg.speed
    local vy = (dy / dist) * cfg.speed

    local proj = Projectile.new("wand", player.x, player.y, vx, vy,
        cfg.damage, cfg.radius, 0, cfg.lifetime)
    table.insert(Weapon.projectiles, proj)
end

--- 火球爆炸
function Weapon._Explode(projectile, enemies, onHit)
    local cfg = Config.WEAPONS["wand"]
    -- 对爆炸范围内所有敌人造成伤害
    for _, e in ipairs(enemies) do
        if e.alive and not projectile:HasHit(e) then
            if Collision.CircleCircle(projectile.x, projectile.y, cfg.explosionRadius,
                e.x, e.y, e.radius) then
                if onHit then
                    onHit(e, cfg.explosionDamage, projectile)
                end
            end
        end
    end
    -- 添加爆炸特效
    table.insert(Weapon.sweepEffects, {
        x = projectile.x,
        y = projectile.y,
        angle = 0,
        timer = 0.3,
        maxTime = 0.3,
        radius = cfg.explosionRadius,
        sweepAngle = 360,
        isExplosion = true,
    })
end

--- 清除所有投射物和特效（房间切换时调用）
function Weapon.ClearProjectiles()
    Weapon.projectiles = {}
    Weapon.sweepEffects = {}
    -- 重置冷却
    for name, state in pairs(Weapon.states) do
        state.cooldownTimer = 0
    end
end

--- 随机选取一个范围内的敌人作为目标
---@param player table
---@param enemies table
---@param range number
---@return EnemyObj|nil
function Weapon._RandomTarget(player, enemies, range)
    local inRange = {}
    for _, e in ipairs(enemies) do
        if e.alive then
            local dist = Collision.Distance(player.x, player.y, e.x, e.y)
            if dist <= range then
                table.insert(inRange, e)
            end
        end
    end
    if #inRange == 0 then return nil end
    return inRange[math.random(1, #inRange)]
end

return Weapon
