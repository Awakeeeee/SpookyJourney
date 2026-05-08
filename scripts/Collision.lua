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

--- 圆是否与有方向的长条矩形碰撞（剑气判定）
--- 长条从 (ox, oy) 沿 (dirX, dirY) 方向延伸 length，宽度 width
---@param cx number 圆心x
---@param cy number 圆心y
---@param cr number 圆半径
---@param ox number 长条起点x
---@param oy number 长条起点y
---@param dirX number 方向单位向量x
---@param dirY number 方向单位向量y
---@param length number 长条长度
---@param halfWidth number 长条半宽
---@return boolean
function Collision.CircleInSlash(cx, cy, cr, ox, oy, dirX, dirY, length, halfWidth)
    -- 计算圆心相对于长条起点的偏移
    local dx = cx - ox
    local dy = cy - oy
    -- 投影到长条方向轴（纵向）
    local along = dx * dirX + dy * dirY
    -- 投影到垂直轴（横向）
    local perp = dx * (-dirY) + dy * dirX
    -- 判定：纵向在 [-cr, length+cr] 且 横向距离 <= halfWidth+cr
    return along > -cr and along < length + cr
       and math.abs(perp) < halfWidth + cr
end

return Collision
