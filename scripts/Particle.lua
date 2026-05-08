-- ============================================================================
-- Particle.lua - 轻量粒子效果
-- ============================================================================

local Particle = {}

local MAX_PARTICLES = 200
local pool = {}

function Particle.Init()
    pool = {}
end

--- 生成一个粒子
---@param x number
---@param y number
---@param vx number
---@param vy number
---@param lifetime number
---@param color table {r,g,b,a}
---@param size number
---@param text string|nil 文字粒子（伤害数字）
local function spawn(x, y, vx, vy, lifetime, color, size, text)
    if #pool >= MAX_PARTICLES then
        table.remove(pool, 1)
    end
    table.insert(pool, {
        x = x, y = y, vx = vx, vy = vy,
        lifetime = lifetime, maxLifetime = lifetime,
        color = color, size = size, text = text,
        alive = true,
    })
end

--- 更新所有粒子
---@param dt number
function Particle.Update(dt)
    for i = #pool, 1, -1 do
        local p = pool[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.lifetime = p.lifetime - dt
        if p.lifetime <= 0 then
            table.remove(pool, i)
        end
    end
end

--- 获取所有活跃粒子
---@return table
function Particle.GetAll()
    return pool
end

--- 伤害数字
---@param x number
---@param y number
---@param damage number
function Particle.SpawnDamageNumber(x, y, damage)
    spawn(x, y - 10, 0, -40, 0.8,
        { 255, 255, 100, 255 }, 14,
        tostring(math.floor(damage)))
end

--- 死亡爆散
---@param x number
---@param y number
---@param color table
function Particle.SpawnDeathPuff(x, y, color)
    for _ = 1, 6 do
        local angle = math.random() * math.pi * 2
        local speed = 40 + math.random() * 60
        spawn(x, y,
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            0.4 + math.random() * 0.2,
            { color[1], color[2], color[3], 200 },
            3 + math.random() * 3, nil)
    end
end

--- 经验拾取闪光
---@param x number
---@param y number
function Particle.SpawnXPSparkle(x, y)
    for _ = 1, 3 do
        local angle = math.random() * math.pi * 2
        local speed = 20 + math.random() * 30
        spawn(x, y,
            math.cos(angle) * speed,
            math.sin(angle) * speed,
            0.3,
            { 100, 255, 150, 200 },
            2 + math.random() * 2, nil)
    end
end

return Particle
