-- ============================================================================
-- Collision.lua - 碰撞检测工具函数
-- ============================================================================

local Collision = {}

--- 圆-圆碰撞检测
---@return boolean
function Collision.CircleCircle(ax, ay, ar, bx, by, br)
    local dx = bx - ax
    local dy = by - ay
    local rSum = ar + br
    return (dx * dx + dy * dy) < (rSum * rSum)
end

--- 点是否在扇形范围内（用于剑挥砍判定）
---@param px number 目标点x
---@param py number 目标点y
---@param cx number 扇形中心x
---@param cy number 扇形中心y
---@param radius number 扇形半径
---@param facingAngle number 扇形朝向角度（弧度）
---@param halfAngle number 扇形半张角（弧度）
---@return boolean
function Collision.PointInFan(px, py, cx, cy, radius, facingAngle, halfAngle)
    local dx = px - cx
    local dy = py - cy
    local distSq = dx * dx + dy * dy
    if distSq > radius * radius then return false end
    local angle = math.atan(dy, dx)
    local diff = math.abs(angle - facingAngle)
    if diff > math.pi then diff = 2 * math.pi - diff end
    return diff <= halfAngle
end

--- 计算两点间距离
---@return number
function Collision.Distance(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return math.sqrt(dx * dx + dy * dy)
end

--- 计算两点间距离的平方（避免开方，用于比较）
---@return number
function Collision.DistanceSq(ax, ay, bx, by)
    local dx = bx - ax
    local dy = by - ay
    return dx * dx + dy * dy
end

return Collision
