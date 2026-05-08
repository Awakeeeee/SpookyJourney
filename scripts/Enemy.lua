-- ============================================================================
-- Enemy.lua - 敌人类（含三种 AI 行为）
-- AI 类型:
--   mob_common  - 靠近玩家围绕攻击（圆形）
--   mob_shooter - 保持距离射击（三角形）
--   mob_clash   - 蓄力冲锋（正方形）
-- ============================================================================

local Config = require("Config")

---@class EnemyObj
---@field type string
---@field aiType string
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
---@field facing number 朝向角度（弧度）
---@field aiState string AI 子状态
---@field aiTimer number AI 计时器
---@field attackTimer number 攻击间隔计时
---@field chargeTargetX number 冲锋目标 X
---@field chargeTargetY number 冲锋目标 Y
---@field chargeDirX number 冲锋方向 X（归一化）
---@field chargeDirY number 冲锋方向 Y（归一化）
---@field chargeDistTotal number 冲锋总距离
---@field chargeDistDone number 已冲锋距离

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
    self.aiType = def.aiType or "mob_common"
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
    self.facing = 0
    -- AI 状态
    self.aiState = "chase"   -- 通用初始状态：追逐
    self.aiTimer = 0
    self.attackTimer = 0
    -- 冲锋专用
    self.chargeTargetX = 0
    self.chargeTargetY = 0
    self.chargeDirX = 0
    self.chargeDirY = 0
    self.chargeDistTotal = 0
    self.chargeDistDone = 0
    return self
end

--- 更新敌人（分 AI 类型处理）
---@param dt number
---@param targetX number 玩家 x
---@param targetY number 玩家 y
---@return table|nil 返回射击信息 {x,y,vx,vy,damage,radius,lifetime} 或 nil
function Enemy:Update(dt, targetX, targetY)
    if not self.alive then return nil end
    -- 受伤闪白衰减
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    -- 更新朝向（始终朝向玩家，冲锋中除外）
    if self.aiState ~= "charging" then
        local dx = targetX - self.x
        local dy = targetY - self.y
        if math.abs(dx) > 0.1 or math.abs(dy) > 0.1 then
            self.facing = math.atan(dy, dx)
        end
    end

    local result
    if self.aiType == "mob_common" then
        result = self:_UpdateCommon(dt, targetX, targetY)
    elseif self.aiType == "mob_shooter" then
        result = self:_UpdateShooter(dt, targetX, targetY)
    elseif self.aiType == "mob_clash" then
        result = self:_UpdateClash(dt, targetX, targetY)
    end

    -- 统一边界钳制（所有 AI 类型、所有状态）
    self.x = math.max(self.radius, math.min(Config.ROOM_WIDTH - self.radius, self.x))
    self.y = math.max(self.radius, math.min(Config.ROOM_HEIGHT - self.radius, self.y))

    return result
end

-- ============================================================================
-- mob_common: chase → orbit → lunge_forward → lunge_back → orbit
-- ============================================================================
function Enemy:_UpdateCommon(dt, targetX, targetY)
    local ai = Config.ENEMY_AI.mob_common
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local orbitDist = Config.PLAYER_RADIUS + self.radius + ai.orbitRadius

    if self.aiState == "chase" then
        -- 追逐至轨道距离
        if dist > orbitDist then
            self.x = self.x + (dx / dist) * self.speed * dt
            self.y = self.y + (dy / dist) * self.speed * dt
        else
            self.aiState = "orbit"
            self.attackTimer = ai.attackInterval * (0.5 + math.random() * 0.5)
        end

    elseif self.aiState == "orbit" then
        -- 环绕玩家，保持 orbitDist 距离
        if dist > 1 then
            local tangentX = -dy / dist
            local tangentY = dx / dist
            self.x = self.x + tangentX * self.speed * 0.5 * dt
            self.y = self.y + tangentY * self.speed * 0.5 * dt
            -- 维持距离（轻微推拉）
            local drift = dist - orbitDist
            self.x = self.x + (dx / dist) * drift * 2.0 * dt
            self.y = self.y + (dy / dist) * drift * 2.0 * dt
        end
        -- 攻击计时
        self.attackTimer = self.attackTimer - dt
        if self.attackTimer <= 0 then
            -- 开始冲顶：记录出发点，冲向玩家
            self.lungeOriginX = self.x
            self.lungeOriginY = self.y
            self.aiState = "lunge_forward"
            self.aiTimer = ai.lungeDuration
            self.lungeHit = false  -- 本次冲顶是否已命中
        end

    elseif self.aiState == "lunge_forward" then
        -- 冲向玩家
        if dist > 1 then
            self.x = self.x + (dx / dist) * ai.lungeSpeed * dt
            self.y = self.y + (dy / dist) * ai.lungeSpeed * dt
        end
        self.aiTimer = self.aiTimer - dt
        -- 检测是否接触玩家
        local touchDist = Config.PLAYER_RADIUS + self.radius
        if dist <= touchDist and not self.lungeHit then
            self.lungeHit = true
        end
        if self.aiTimer <= 0 then
            self.aiState = "lunge_back"
            self.aiTimer = ai.lungeDuration
        end

    elseif self.aiState == "lunge_back" then
        -- 回到出发点
        local bx = self.lungeOriginX - self.x
        local by = self.lungeOriginY - self.y
        local bdist = math.sqrt(bx * bx + by * by)
        if bdist > 2 then
            self.x = self.x + (bx / bdist) * ai.lungeSpeed * dt
            self.y = self.y + (by / bdist) * ai.lungeSpeed * dt
        end
        self.aiTimer = self.aiTimer - dt
        if self.aiTimer <= 0 then
            self.aiState = "orbit"
            self.attackTimer = ai.attackInterval
        end
    end

    -- 返回近战命中信息
    if self.lungeHit then
        self.lungeHit = false
        return { melee = true, damage = self.damage }
    end
    return nil
end

-- ============================================================================
-- mob_shooter: dist > attackRange → 移动靠近
--              fleeRange < dist < attackRange → 站定射击
--              dist < fleeRange → 逃离
-- ============================================================================
function Enemy:_UpdateShooter(dt, targetX, targetY)
    local ai = Config.ENEMY_AI.mob_shooter
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > ai.attackRange then
        -- 太远：靠近玩家
        if dist > 1 then
            self.x = self.x + (dx / dist) * self.speed * dt
            self.y = self.y + (dy / dist) * self.speed * dt
        end
        -- 移动中不射击
        return nil
    elseif dist < ai.fleeRange then
        -- 太近：逃离玩家
        if dist > 1 then
            local flee = self.speed * ai.fleeSpeed
            self.x = self.x - (dx / dist) * flee * dt
            self.y = self.y - (dy / dist) * flee * dt
        end
        -- 逃跑中不射击
        return nil
    end

    -- 在攻击范围内：站定射击
    self.attackTimer = self.attackTimer - dt
    if self.attackTimer <= 0 then
        self.attackTimer = ai.fireInterval
        if dist > 1 then
            local ndx = dx / dist
            local ndy = dy / dist
            local spawnX = self.x + ndx * self.radius
            local spawnY = self.y + ndy * self.radius
            return {
                x = spawnX, y = spawnY,
                vx = ndx * ai.bulletSpeed,
                vy = ndy * ai.bulletSpeed,
                damage = self.damage,
                radius = ai.bulletRadius,
                lifetime = ai.bulletLifetime,
            }
        end
    end
    return nil
end

-- ============================================================================
-- mob_clash: chase → windup（蓄力） → charging（冲锋） → cooldown
-- ============================================================================
function Enemy:_UpdateClash(dt, targetX, targetY)
    local ai = Config.ENEMY_AI.mob_clash
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if self.aiState == "chase" then
        -- 接近到 preferDist
        if dist > ai.preferDist then
            self.x = self.x + (dx / dist) * self.speed * dt
            self.y = self.y + (dy / dist) * self.speed * dt
        else
            -- 进入蓄力
            self.aiState = "windup"
            self.aiTimer = ai.chargeDelay
            -- 锁定冲锋目标为此刻玩家位置
            self.chargeTargetX = targetX
            self.chargeTargetY = targetY
            local cdx = targetX - self.x
            local cdy = targetY - self.y
            local cdist = math.sqrt(cdx * cdx + cdy * cdy)
            if cdist > 1 then
                self.chargeDirX = cdx / cdist
                self.chargeDirY = cdy / cdist
            else
                self.chargeDirX = math.cos(self.facing)
                self.chargeDirY = math.sin(self.facing)
            end
            self.chargeDistTotal = cdist + 40  -- 冲过目标一段距离
            self.chargeDistDone = 0
        end

    elseif self.aiState == "windup" then
        -- 蓄力中：原地不动，红色闪烁（由 Renderer 处理）
        self.aiTimer = self.aiTimer - dt
        if self.aiTimer <= 0 then
            self.aiState = "charging"
        end

    elseif self.aiState == "charging" then
        -- 冲锋中：沿锁定方向高速移动
        local move = ai.chargeSpeed * dt
        self.x = self.x + self.chargeDirX * move
        self.y = self.y + self.chargeDirY * move
        self.chargeDistDone = self.chargeDistDone + move
        -- 冲锋结束
        if self.chargeDistDone >= self.chargeDistTotal then
            self.aiState = "cooldown"
            self.aiTimer = 0.6  -- 冲锋后短暂停顿
        end
        -- 碰到房间边界也停止冲锋（位置由 Update 统一 clamp）
        if self.x < self.radius or self.x > Config.ROOM_WIDTH - self.radius
            or self.y < self.radius or self.y > Config.ROOM_HEIGHT - self.radius then
            self.aiState = "cooldown"
            self.aiTimer = 0.6
        end

    elseif self.aiState == "cooldown" then
        -- 冲锋后短暂停顿
        self.aiTimer = self.aiTimer - dt
        if self.aiTimer <= 0 then
            self.aiState = "chase"
        end
    end
    return nil
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
