-- ============================================================================
-- ItemDB.lua - 物品配置表
-- 品质体系 + 物品原型 + 实例创建
-- ============================================================================

local ItemDB = {}

-- ============================================================================
-- 品质定义（1=白 ~ 6=红）
-- ============================================================================

ItemDB.QUALITY_WHITE  = 1
ItemDB.QUALITY_GREEN  = 2
ItemDB.QUALITY_BLUE   = 3
ItemDB.QUALITY_PURPLE = 4
ItemDB.QUALITY_ORANGE = 5
ItemDB.QUALITY_RED    = 6

---@type table<number, {name:string, color:number[], borderColor:number[]}>
ItemDB.QUALITIES = {
    [1] = { name = "白", color = { 200, 200, 200, 255 }, borderColor = { 140, 140, 140, 255 } },
    [2] = { name = "绿", color = { 80, 220, 80, 255 },  borderColor = { 60, 180, 60, 255 } },
    [3] = { name = "蓝", color = { 80, 150, 255, 255 },  borderColor = { 60, 120, 230, 255 } },
    [4] = { name = "紫", color = { 180, 80, 255, 255 },  borderColor = { 150, 60, 220, 255 } },
    [5] = { name = "橙", color = { 255, 160, 40, 255 },  borderColor = { 230, 130, 20, 255 } },
    [6] = { name = "红", color = { 255, 60, 60, 255 },   borderColor = { 220, 40, 40, 255 } },
}

-- ============================================================================
-- 物品原型表（18个，每品质3个）
-- ============================================================================

---@type table<number, {id:number, name:string, quality:number, icon:string, type:string}>
ItemDB.PROTOTYPES = {
    -- 白色品质 (ID 1-3)
    { id = 1,  name = "白物品1", quality = 1, icon = "📦", type = "misc" },
    { id = 2,  name = "白物品2", quality = 1, icon = "🪨", type = "misc" },
    { id = 3,  name = "白物品3", quality = 1, icon = "🧱", type = "misc" },
    -- 绿色品质 (ID 4-6)
    { id = 4,  name = "绿物品1", quality = 2, icon = "🌿", type = "misc" },
    { id = 5,  name = "绿物品2", quality = 2, icon = "🍀", type = "misc" },
    { id = 6,  name = "绿物品3", quality = 2, icon = "🌱", type = "misc" },
    -- 蓝色品质 (ID 7-9)
    { id = 7,  name = "蓝物品1", quality = 3, icon = "💧", type = "misc" },
    { id = 8,  name = "蓝物品2", quality = 3, icon = "🔷", type = "misc" },
    { id = 9,  name = "蓝物品3", quality = 3, icon = "🧊", type = "misc" },
    -- 紫色品质 (ID 10-12)
    { id = 10, name = "紫物品1", quality = 4, icon = "🔮", type = "misc" },
    { id = 11, name = "紫物品2", quality = 4, icon = "🦄", type = "misc" },
    { id = 12, name = "紫物品3", quality = 4, icon = "🌌", type = "misc" },
    -- 橙色品质 (ID 13-15)
    { id = 13, name = "橙物品1", quality = 5, icon = "🔥", type = "misc" },
    { id = 14, name = "橙物品2", quality = 5, icon = "⚡", type = "misc" },
    { id = 15, name = "橙物品3", quality = 5, icon = "🌟", type = "misc" },
    -- 红色品质 (ID 16-18)
    { id = 16, name = "红物品1", quality = 6, icon = "💎", type = "misc" },
    { id = 17, name = "红物品2", quality = 6, icon = "👑", type = "misc" },
    { id = 18, name = "红物品3", quality = 6, icon = "🏆", type = "misc" },
}

-- 建立 ID → 原型索引映射
local protoById = {}
for _, proto in ipairs(ItemDB.PROTOTYPES) do
    protoById[proto.id] = proto
end

-- ============================================================================
-- API
-- ============================================================================

--- 按 ID 查找物品原型
---@param id number 原型 ID
---@return table|nil proto
function ItemDB.GetProto(id)
    return protoById[id]
end

--- 按品质等级查询品质信息
---@param quality number 品质等级 1~6
---@return table|nil qualityInfo {name, color, borderColor}
function ItemDB.GetQualityInfo(quality)
    return ItemDB.QUALITIES[quality]
end

-- 自增实例 ID
local nextInstanceId = 1

--- 从原型创建物品实例
---@param protoId number 原型 ID
---@return table|nil item 物品实例 {instanceId, id, name, quality, icon, type}
function ItemDB.CreateItem(protoId)
    local proto = protoById[protoId]
    if not proto then
        print("[ItemDB] ERROR: Unknown prototype ID: " .. tostring(protoId))
        return nil
    end
    local item = {
        instanceId = nextInstanceId,
        id = proto.id,
        name = proto.name,
        quality = proto.quality,
        icon = proto.icon,
        type = proto.type,
    }
    nextInstanceId = nextInstanceId + 1
    return item
end

return ItemDB
