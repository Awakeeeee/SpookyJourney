-- ============================================================================
-- Projectile.lua - 投射物管理
-- ============================================================================

---@class ProjectileObj
---@field x number
---@field y number
---@field vx number
---@field vy number
---@field damage number
---@field radius number
---@field pierce number
---@field pierced number
---@field lifetime number
---@field alive boolean
---@field weaponType string
---@field hitEnemies table

local Projectile = {}
Projectile.__index = Projectile

--- 创建投射物
---@param weaponType string "knife" 或 "wand"
---@param x number 起始x
---@param y number 起始y
---@param vx number 速度x
---@param vy number 速度y
---@param damage number 伤害
---@param radius number 碰撞半径
---@param pierce number 穿透次数
---@param lifetime number 存在时间
---@return ProjectileObj
function Projectile.new(weaponType, x, y, vx, vy, damage, radius, pierce, lifetime)
    local self = setmetatable({}, Projectile)
    self.weaponType = weaponType
    self.x = x
    self.y = y
    self.vx = vx
    self.vy = vy
    self.damage = damage
    self.radius = radius
    self.pierce = pierce or 0
    self.pierced = 0
    self.lifetime = lifetime or 2.0
    self.alive = true
    self.hitEnemies = {}  -- 已命中的敌人引用，防止重复伤害
    return self
end

--- 更新位置
---@param dt number
function Projectile:Update(dt)
    if not self.alive then return end
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.lifetime = self.lifetime - dt
    if self.lifetime <= 0 then
        self.alive = false
    end
end

--- 标记命中了某敌人
---@param enemy EnemyObj
---@return boolean 是否应继续存活
function Projectile:HitEnemy(enemy)
    self.hitEnemies[enemy] = true
    self.pierced = self.pierced + 1
    if self.pierced > self.pierce then
        self.alive = false
        return false
    end
    return true
end

--- 是否已命中过该敌人
---@param enemy EnemyObj
---@return boolean
function Projectile:HasHit(enemy)
    return self.hitEnemies[enemy] == true
end

return Projectile
