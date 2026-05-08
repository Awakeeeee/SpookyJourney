-- ============================================================================
-- Inventory.lua - 背包数据模型
-- 纯数据层，不含 UI 逻辑
-- ============================================================================

---@class InventoryData
---@field cols number
---@field rows number
---@field slots table 格子数组，索引 1~cols*rows，nil 表示空
local Inventory = {}
Inventory.__index = Inventory

--- 创建新背包
---@param cols number 列数
---@param rows number 行数
---@return InventoryData
function Inventory.New(cols, rows)
    local self = setmetatable({}, Inventory)
    self.cols = cols
    self.rows = rows
    self.slots = {}
    -- 初始化所有格子为 nil
    for i = 1, cols * rows do
        self.slots[i] = nil
    end
    print("[Inventory] Created " .. cols .. "x" .. rows .. " = " .. (cols * rows) .. " slots")
    return self
end

--- 获取背包总格数
---@return number
function Inventory:GetSize()
    return self.cols * self.rows
end

--- 获取背包尺寸
---@return number cols, number rows
function Inventory:GetDimensions()
    return self.cols, self.rows
end

--- 获取指定格物品
---@param slotIndex number 格子索引 (1-based)
---@return table|nil item
function Inventory:GetItem(slotIndex)
    if slotIndex < 1 or slotIndex > self:GetSize() then
        return nil
    end
    return self.slots[slotIndex]
end

--- 在指定格放入物品（覆盖原有）
---@param slotIndex number 格子索引
---@param item table|nil 物品数据
function Inventory:SetItem(slotIndex, item)
    if slotIndex < 1 or slotIndex > self:GetSize() then
        print("[Inventory] ERROR: Invalid slot index " .. slotIndex)
        return
    end
    self.slots[slotIndex] = item
end

--- 找第一个空格放入物品
---@param item table 物品数据
---@return number|nil slotIndex 放入的格子索引，nil 表示满了
function Inventory:AddItem(item)
    for i = 1, self:GetSize() do
        if self.slots[i] == nil then
            self.slots[i] = item
            print("[Inventory] Added item '" .. (item.name or "?") .. "' to slot " .. i)
            return i
        end
    end
    print("[Inventory] ERROR: Inventory full, cannot add '" .. (item.name or "?") .. "'")
    return nil
end

--- 移除指定格物品
---@param slotIndex number
---@return table|nil item 被移除的物品
function Inventory:RemoveItem(slotIndex)
    if slotIndex < 1 or slotIndex > self:GetSize() then
        return nil
    end
    local item = self.slots[slotIndex]
    self.slots[slotIndex] = nil
    return item
end

--- 移动物品（仅当目标为空时）
---@param fromIndex number 源格子
---@param toIndex number 目标格子
---@return boolean success
function Inventory:MoveItem(fromIndex, toIndex)
    if fromIndex == toIndex then return false end
    if fromIndex < 1 or fromIndex > self:GetSize() then return false end
    if toIndex < 1 or toIndex > self:GetSize() then return false end

    local fromItem = self.slots[fromIndex]
    local toItem = self.slots[toIndex]

    if not fromItem then return false end
    if toItem then
        -- 目标不为空，不允许移动（暂不支持换位）
        return false
    end

    self.slots[toIndex] = fromItem
    self.slots[fromIndex] = nil
    print("[Inventory] Moved '" .. (fromItem.name or "?") .. "' from slot " .. fromIndex .. " to " .. toIndex)
    return true
end

--- 跨背包移动：从本背包某格移到目标背包某格
---@param fromIndex number 本背包源格子
---@param targetInv InventoryData 目标背包
---@param toIndex number 目标背包格子
---@return boolean success
function Inventory:MoveItemTo(fromIndex, targetInv, toIndex)
    if not targetInv then return false end
    if fromIndex < 1 or fromIndex > self:GetSize() then return false end
    if toIndex < 1 or toIndex > targetInv:GetSize() then return false end

    local fromItem = self.slots[fromIndex]
    if not fromItem then return false end

    local toItem = targetInv:GetItem(toIndex)
    if toItem then return false end  -- 目标不为空

    targetInv:SetItem(toIndex, fromItem)
    self.slots[fromIndex] = nil
    print("[Inventory] Cross-move '" .. (fromItem.name or "?") .. "' to another inventory slot " .. toIndex)
    return true
end

return Inventory
