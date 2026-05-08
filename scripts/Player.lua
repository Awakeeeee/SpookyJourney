-- ============================================================================
-- Player.lua - 玩家状态和逻辑
-- ============================================================================

local Config = require("Config")

local Player = {}

function Player.Init()
    Player.x = Config.ROOM_WIDTH / 2
    Player.y = Config.ROOM_HEIGHT / 2
    Player.hp = Config.PLAYER_HP
    Player.maxHp = Config.PLAYER_HP
    Player.speed = Config.PLAYER_SPEED
    Player.radius = Config.PLAYER_RADIUS
    Player.facing = -math.pi / 2  -- 初始朝上
    Player.invulnTimer = 0
    Player.xp = 0
    Player.level = 1
    Player.kills = 0
    Player.weapons = { "sword" }  -- 初始武器：剑
    Player.xpPickupRadius = Config.XP_PICKUP_RADIUS
end

--- 更新玩家位置
---@param dt number 帧间隔
---@param inputX number 摇杆x方向 [-1, 1]
---@param inputY number 摇杆y方向 [-1, 1]
function Player.Update(dt, inputX, inputY)
    -- 移动
    if math.abs(inputX) > 0.01 or math.abs(inputY) > 0.01 then
        -- 归一化方向
        local len = math.sqrt(inputX * inputX + inputY * inputY)
        if len > 1 then
            inputX = inputX / len
            inputY = inputY / len
        end
        Player.x = Player.x + inputX * Player.speed * dt
        Player.y = Player.y + inputY * Player.speed * dt
        Player.facing = math.atan(inputY, inputX)
    end

    -- 限制在房间范围内
    Player.x = math.max(Player.radius, math.min(Config.ROOM_WIDTH - Player.radius, Player.x))
    Player.y = math.max(Player.radius, math.min(Config.ROOM_HEIGHT - Player.radius, Player.y))

    -- 无敌计时
    if Player.invulnTimer > 0 then
        Player.invulnTimer = Player.invulnTimer - dt
    end
end

--- 玩家受伤
---@param amount number 伤害值
---@return boolean 是否死亡
function Player.TakeDamage(amount)
    if Player.invulnTimer > 0 then return false end
    Player.hp = Player.hp - amount
    Player.invulnTimer = Config.PLAYER_INVULN_TIME
    if Player.hp <= 0 then
        Player.hp = 0
        return true
    end
    return false
end

--- 增加经验
---@param amount number 经验值
---@return boolean 是否升级
function Player.AddXP(amount)
    Player.xp = Player.xp + amount
    local needed = Player.GetXPNeeded()
    if Player.xp >= needed then
        Player.xp = Player.xp - needed
        Player.level = Player.level + 1
        return true
    end
    return false
end

--- 获取当前等级所需经验
---@return number
function Player.GetXPNeeded()
    if Player.level <= #Config.XP_TABLE then
        return Config.XP_TABLE[Player.level]
    end
    -- 超出表格后线性增长
    return Config.XP_TABLE[#Config.XP_TABLE] + (Player.level - #Config.XP_TABLE) * 25
end

--- 获取经验进度 [0, 1]
---@return number
function Player.GetXPProgress()
    return Player.xp / Player.GetXPNeeded()
end

--- 是否拥有某武器
---@param name string
---@return boolean
function Player.HasWeapon(name)
    for _, w in ipairs(Player.weapons) do
        if w == name then return true end
    end
    return false
end

return Player
