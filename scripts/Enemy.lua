-- ============================================================================
-- Enemy.lua - 敌人类
-- ============================================================================

local Config = require("Config")

---@class EnemyObj
---@field type string
---@field x number
---@field y number
---@field speed number
---@field hp number
---@field maxHp number
---@field radius number
---@field damage number
---@field color table
---@field xpValue number
---@field alive boolean
---@field flashTimer number

local Enemy = {}
Enemy.__index = Enemy

--- 创建新敌人
---@param typeName string 敌人类型名
---@param x number 生成位置x
---@param y number 生成位置y
---@return EnemyObj
function Enemy.new(typeName, x, y)
    local def = Config.ENEMY_TYPES[typeName]
    if not def then
        print("[Enemy] Unknown type: " .. tostring(typeName))
        def = Config.ENEMY_TYPES["bat"]
    end
    local self = setmetatable({}, Enemy)
    self.type = typeName
    self.x = x
    self.y = y
    self.speed = def.speed
    self.hp = def.hp
    self.maxHp = def.hp
    self.radius = def.radius
    self.damage = def.damage
    self.color = def.color
    self.xpValue = def.xp
    self.alive = true
    self.flashTimer = 0
    return self
end

--- 更新敌人（追踪目标）
---@param dt number
---@param targetX number
---@param targetY number
function Enemy:Update(dt, targetX, targetY)
    if not self.alive then return end
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist > 1 then
        self.x = self.x + (dx / dist) * self.speed * dt
        self.y = self.y + (dy / dist) * self.speed * dt
    end
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
end

--- 敌人受伤
---@param amount number
---@return boolean 是否死亡
function Enemy:TakeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
    if self.hp <= 0 then
        self.alive = false
        return true
    end
    return false
end

return Enemy
