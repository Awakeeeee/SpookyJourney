-- ============================================================================
-- Upgrade.lua - 升级系统
-- ============================================================================

local Config = require("Config")

local Upgrade = {}

--- 升级项定义
local upgradePool = {}

--- 初始化升级池
function Upgrade.Init()
    upgradePool = {
        -- 新增武器
        {
            id = "knife_unlock", name = "飞刀", desc = "随机索敌，发射可穿透飞刀",
            category = "weapon", maxLevel = 1, currentLevel = 0,
            apply = function(player)
                if not player.HasWeapon("knife") then
                    table.insert(player.weapons, "knife")
                end
            end,
        },
        {
            id = "wand_unlock", name = "魔杖", desc = "随机索敌，发射爆炸火球",
            category = "weapon", maxLevel = 1, currentLevel = 0,
            apply = function(player)
                if not player.HasWeapon("wand") then
                    table.insert(player.weapons, "wand")
                end
            end,
        },
        -- 剑强化
        {
            id = "sword_damage", name = "利刃", desc = "剑伤害 +5",
            category = "enhance", maxLevel = 5, currentLevel = 0,
            apply = function()
                Config.WEAPONS.sword.damage = Config.WEAPONS.sword.damage + 5
            end,
        },
        {
            id = "sword_range", name = "长剑", desc = "剑攻击长度 +10",
            category = "enhance", maxLevel = 3, currentLevel = 0,
            apply = function()
                Config.WEAPONS.sword.slashLength = Config.WEAPONS.sword.slashLength + 10
            end,
        },
        {
            id = "sword_speed", name = "疾斩", desc = "剑冷却 -15%",
            category = "enhance", maxLevel = 3, currentLevel = 0,
            apply = function()
                Config.WEAPONS.sword.cooldown = Config.WEAPONS.sword.cooldown * 0.85
            end,
        },
        -- 飞刀强化
        {
            id = "knife_pierce", name = "贯穿", desc = "飞刀穿透 +1",
            category = "enhance", maxLevel = 3, currentLevel = 0,
            requires = "knife",
            apply = function()
                Config.WEAPONS.knife.pierce = Config.WEAPONS.knife.pierce + 1
            end,
        },
        {
            id = "knife_speed_cd", name = "连发", desc = "飞刀冷却 -15%",
            category = "enhance", maxLevel = 3, currentLevel = 0,
            requires = "knife",
            apply = function()
                Config.WEAPONS.knife.cooldown = Config.WEAPONS.knife.cooldown * 0.85
            end,
        },
        -- 魔杖强化
        {
            id = "wand_explosion", name = "大爆炸", desc = "火球爆炸范围 +15",
            category = "enhance", maxLevel = 3, currentLevel = 0,
            requires = "wand",
            apply = function()
                Config.WEAPONS.wand.explosionRadius = Config.WEAPONS.wand.explosionRadius + 15
            end,
        },
        {
            id = "wand_damage", name = "烈焰", desc = "火球伤害 +4",
            category = "enhance", maxLevel = 5, currentLevel = 0,
            requires = "wand",
            apply = function()
                Config.WEAPONS.wand.damage = Config.WEAPONS.wand.damage + 4
                Config.WEAPONS.wand.explosionDamage = Config.WEAPONS.wand.explosionDamage + 4
            end,
        },
        -- 通用强化
        {
            id = "max_hp", name = "生命强化", desc = "最大生命 +20",
            category = "stat", maxLevel = 5, currentLevel = 0,
            apply = function(player)
                player.maxHp = player.maxHp + 20
                player.hp = player.hp + 20
            end,
        },
        {
            id = "move_speed", name = "疾步", desc = "移动速度 +12%",
            category = "stat", maxLevel = 3, currentLevel = 0,
            apply = function(player)
                player.speed = player.speed * 1.12
            end,
        },
        {
            id = "heal", name = "治愈", desc = "立即恢复 30 生命",
            category = "stat", maxLevel = 99, currentLevel = 0,
            apply = function(player)
                player.hp = math.min(player.maxHp, player.hp + 30)
            end,
        },
    }
end

--- 随机获取 n 个可用升级选项
---@param n number
---@param player table Player模块
---@return table 升级选项列表
function Upgrade.GetChoices(n, player)
    local available = {}
    for _, u in ipairs(upgradePool) do
        -- 未达到最大等级
        if u.currentLevel < u.maxLevel then
            -- 如果有武器前置要求，检查是否拥有
            if not u.requires or player.HasWeapon(u.requires) then
                table.insert(available, u)
            end
        end
    end

    -- 随机打乱
    for i = #available, 2, -1 do
        local j = math.random(1, i)
        available[i], available[j] = available[j], available[i]
    end

    -- 取前 n 个
    local choices = {}
    for i = 1, math.min(n, #available) do
        choices[i] = available[i]
    end
    return choices
end

--- 应用升级
---@param upgrade table 升级项
---@param player table Player模块
function Upgrade.Apply(upgrade, player)
    upgrade.currentLevel = upgrade.currentLevel + 1
    upgrade.apply(player)
    print("[Upgrade] Applied: " .. upgrade.name .. " Lv." .. upgrade.currentLevel)
end

return Upgrade
