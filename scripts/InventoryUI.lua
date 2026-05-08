-- ============================================================================
-- InventoryUI.lua - 背包界面（支持普通模式 + 宝箱双栏模式）
-- 普通模式：仅显示玩家背包网格
-- 宝箱模式：上方宝箱网格 + 下方玩家背包网格，支持跨背包拖拽
-- ============================================================================

local UI = require("urhox-libs/UI")
local ItemDB = require("ItemDB")

local InventoryUI = {}

-- ============================================================================
-- 品质背景色（柔和暗色调，不影响图标辨识度）
-- ============================================================================

local QUALITY_BG_COLORS = {
    [1] = { 55, 55, 55, 255 },    -- 白：深灰
    [2] = { 38, 58, 38, 255 },    -- 绿：暗绿
    [3] = { 38, 45, 65, 255 },    -- 蓝：暗蓝
    [4] = { 52, 38, 62, 255 },    -- 紫：暗紫
    [5] = { 62, 48, 30, 255 },    -- 橙：暗橙
    [6] = { 62, 32, 32, 255 },    -- 红：暗红
}

local BORDER_DEFAULT = { 100, 100, 110, 255 }  -- 默认浅灰
local BORDER_HOVER   = { 255, 220, 60, 255 }   -- 悬停亮黄
local BG_EMPTY       = { 40, 45, 55, 255 }     -- 空格背景

local SLOT_SIZE = 36
local SLOT_GAP  = 4

-- ============================================================================
-- Monkey-patch ItemSlot 的 hover 行为
-- ============================================================================

local function PatchSlotHover(slot)
    local origEnter = slot.OnPointerEnter
    local origLeave = slot.OnPointerLeave
    local origUpdateDisplay = slot.UpdateDisplay

    slot.OnPointerEnter = function(self, event)
        origEnter(self, event)
        local dragCtx = self.props.dragContext
        if dragCtx and dragCtx:IsDragging() then
            -- 拖拽中保留绿/红色
        else
            self.props.borderColor = BORDER_HOVER
        end
    end

    slot.OnPointerLeave = function(self, event)
        origLeave(self, event)
        self.props.borderColor = BORDER_DEFAULT
    end

    slot.UpdateDisplay = function(self)
        origUpdateDisplay(self)
        local item = self.props.item
        if item then
            local bgc = QUALITY_BG_COLORS[item.quality]
            if bgc then
                self.props.backgroundColor = bgc
            end
        else
            self.props.backgroundColor = BG_EMPTY
        end
    end
end

-- ============================================================================
-- 构建网格组件
-- ============================================================================

--- 构建一个背包网格（slots 表 + UI 面板）
---@param inventory InventoryData
---@param category string  slot 类别标识（"player_bag" 或 "chest_inv"）
---@param dragContext table  共享的 DragDropContext
---@return table[] slots, table gridPanel
local function BuildGrid(inventory, category, dragContext)
    local cols, rows = inventory:GetDimensions()
    local slots = {}
    local gridChildren = {}
    local slotIndex = 1

    for r = 1, rows do
        local rowChildren = {}
        for c = 1, cols do
            local slot = UI.ItemSlot {
                slotId = slotIndex,
                slotCategory = category,
                size = SLOT_SIZE,
                showTypeIcon = false,
                dragContext = dragContext,
                borderColor = BORDER_DEFAULT,
            }
            PatchSlotHover(slot)
            slots[slotIndex] = slot
            rowChildren[#rowChildren + 1] = slot
            slotIndex = slotIndex + 1
        end
        gridChildren[#gridChildren + 1] = UI.Panel {
            flexDirection = "row",
            gap = SLOT_GAP,
            justifyContent = "center",
            children = rowChildren,
        }
    end

    local gridPanel = UI.Panel {
        flexDirection = "column",
        gap = SLOT_GAP,
        alignItems = "center",
        paddingLeft = 12,
        paddingRight = 12,
        paddingTop = 8,
        paddingBottom = 8,
        children = gridChildren,
    }

    return slots, gridPanel
end

-- ============================================================================
-- 刷新格子
-- ============================================================================

local function RefreshSlots(slots, inventory)
    for i, slot in ipairs(slots) do
        local item = inventory:GetItem(i)
        slot:SetItem(item)
        slot.props.borderColor = BORDER_DEFAULT
    end
end

-- ============================================================================
-- 创建背包 UI
-- ============================================================================

--- 创建背包界面（不自动打开）
---@param inventory InventoryData 玩家背包数据
---@return table ctx 背包 UI 控制对象
function InventoryUI.Create(inventory)
    local ctx = {
        inventory = inventory,     -- 玩家背包
        slots = {},                -- 玩家背包格子
        overlay = nil,
        dragContext = nil,
        isOpen = false,
        -- 宝箱模式
        chestMode = false,
        chestInventory = nil,
        chestSlots = {},
        chestCard = nil,           -- 宝箱卡片 UI 组件
        bagCard = nil,             -- 背包卡片 UI 组件
        contentContainer = nil,    -- overlay 内容容器
    }

    -- 创建 DragDropContext（同/跨背包统一处理）
    ctx.dragContext = UI.DragDropContext {
        canDrop = function(itemData, sourceSlot, targetSlot)
            local targetItem = targetSlot:GetItem()
            if targetItem then
                return false  -- 目标格有物品则不允许（暂不支持交换）
            end
            return true
        end,

        onDragEnd = function(itemData, sourceSlot, targetSlot, success)
            if not success or not targetSlot then return end

            local fromCategory = sourceSlot:GetSlotCategory()
            local fromId = sourceSlot:GetSlotId()
            local toCategory = targetSlot:GetSlotCategory()
            local toId = targetSlot:GetSlotId()

            -- 确定源/目标背包实例
            local fromInv = (fromCategory == "player_bag") and ctx.inventory or ctx.chestInventory
            local toInv   = (toCategory == "player_bag")   and ctx.inventory or ctx.chestInventory

            if not fromInv or not toInv then return end

            if fromInv == toInv then
                -- 同背包内移动
                local moved = fromInv:MoveItem(fromId, toId)
                if moved then
                    print("[InventoryUI] Same-inv move: " .. fromCategory .. " " .. fromId .. " -> " .. toId)
                end
            else
                -- 跨背包移动
                local moved = fromInv:MoveItemTo(fromId, toInv, toId)
                if moved then
                    print("[InventoryUI] Cross-inv move: " .. fromCategory .. ":" .. fromId .. " -> " .. toCategory .. ":" .. toId)
                end
            end

            -- 刷新所有格子
            RefreshSlots(ctx.slots, ctx.inventory)
            if ctx.chestMode and ctx.chestInventory then
                RefreshSlots(ctx.chestSlots, ctx.chestInventory)
            end
        end,
    }

    -- 构建玩家背包网格
    ctx.slots, ctx.bagGrid = BuildGrid(inventory, "player_bag", ctx.dragContext)

    -- 标题栏
    local titleBar = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        width = "100%",
        height = 36,
        children = {
            UI.Label {
                text = "背包",
                fontSize = 16,
                fontColor = { 220, 220, 230, 255 },
                textAlign = "center",
            },
        },
    }
    ctx.bagTitleLabel = titleBar

    -- 关闭按钮
    local closeBtn = UI.Button {
        text = "关闭",
        variant = "secondary",
        width = 100,
        height = 32,
        fontSize = 13,
        onClick = function()
            InventoryUI.Close(ctx)
        end,
    }

    local closeBtnRow = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        width = "100%",
        paddingTop = 6,
        paddingBottom = 10,
        children = { closeBtn },
    }

    -- 背包卡片
    ctx.bagCard = UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        width = "100%",
        backgroundColor = { 25, 28, 38, 240 },
        borderRadius = 12,
        paddingTop = 6,
        paddingBottom = 4,
        paddingLeft = 4,
        paddingRight = 4,
        marginLeft = 10,
        marginRight = 10,
        children = {
            titleBar,
            ctx.bagGrid,
            closeBtnRow,
            ctx.dragContext,
        },
    }

    -- 上半空白区域（点击关闭）
    local topSpacer = UI.Panel {
        flexGrow = 1,
        width = "100%",
    }

    -- 内容容器（column 布局，宝箱卡片会动态添加到这里）
    ctx.contentContainer = UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        width = "100%",
        flexGrow = 1,
        justifyContent = "flex-end",
        children = {
            topSpacer,
            ctx.bagCard,
        },
    }

    -- 全屏 Overlay
    ctx.overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0,
        width = "100%",
        height = "100%",
        backgroundColor = { 0, 0, 0, 120 },
        flexDirection = "column",
        alignItems = "center",
        children = {
            ctx.contentContainer,
        },
        onClick = function(self, event)
            InventoryUI.Close(ctx)
        end,
    }

    -- 阻止点击背包卡片冒泡关闭
    ctx.bagCard.props.onClick = function(self, event) end

    -- 初始隐藏
    ctx.overlay:SetVisible(false)

    -- 初始刷新
    RefreshSlots(ctx.slots, ctx.inventory)

    print("[InventoryUI] Created inventory UI")
    return ctx
end

-- ============================================================================
-- 宝箱卡片（延迟构建，首次打开宝箱时创建）
-- ============================================================================

--- 构建宝箱卡片 UI
---@param ctx table
---@param chestInv InventoryData
local function BuildChestCard(ctx, chestInv)
    ctx.chestInventory = chestInv
    ctx.chestSlots, ctx.chestGrid = BuildGrid(chestInv, "chest_inv", ctx.dragContext)

    -- 宝箱标题
    local chestTitle = UI.Panel {
        flexDirection = "row",
        justifyContent = "center",
        alignItems = "center",
        width = "100%",
        height = 36,
        children = {
            UI.Label {
                text = "宝箱",
                fontSize = 16,
                fontColor = { 255, 220, 80, 255 },
                textAlign = "center",
            },
        },
    }

    ctx.chestCard = UI.Panel {
        flexDirection = "column",
        alignItems = "center",
        width = "100%",
        backgroundColor = { 35, 30, 18, 240 },
        borderRadius = 12,
        paddingTop = 6,
        paddingBottom = 8,
        paddingLeft = 4,
        paddingRight = 4,
        marginLeft = 10,
        marginRight = 10,
        marginBottom = 8,
        children = {
            chestTitle,
            ctx.chestGrid,
        },
    }

    -- 阻止点击宝箱卡片冒泡关闭
    ctx.chestCard.props.onClick = function(self, event) end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 获取 overlay 组件（需要挂载到 UI 树）
---@param ctx table
---@return table overlayPanel
function InventoryUI.GetOverlay(ctx)
    return ctx.overlay
end

--- 打开普通背包模式
---@param ctx table
function InventoryUI.Open(ctx)
    if not ctx.overlay then return end

    -- 确保移除宝箱卡片（如果之前是宝箱模式）
    if ctx.chestMode and ctx.chestCard then
        ctx.contentContainer:RemoveChild(ctx.chestCard)
    end

    ctx.chestMode = false
    ctx.chestInventory = nil

    RefreshSlots(ctx.slots, ctx.inventory)
    ctx.overlay:SetVisible(true)
    ctx.isOpen = true
    print("[InventoryUI] Bag opened (normal mode)")
end

--- 打开宝箱模式（上方宝箱 + 下方背包）
---@param ctx table
---@param chestInventory InventoryData 宝箱背包数据
function InventoryUI.OpenChest(ctx, chestInventory)
    if not ctx.overlay then return end

    -- 构建/重建宝箱卡片
    BuildChestCard(ctx, chestInventory)

    -- 将宝箱卡片插入到背包卡片之前
    -- contentContainer 的 children: [topSpacer, bagCard]
    -- 需要变成: [topSpacer, chestCard, bagCard]
    -- 使用 AddChild 动态添加，再重新排列
    -- 由于没有 insertBefore，先移除 bagCard，添加 chestCard，再加回 bagCard
    ctx.contentContainer:RemoveChild(ctx.bagCard)
    ctx.contentContainer:AddChild(ctx.chestCard)
    ctx.contentContainer:AddChild(ctx.bagCard)

    ctx.chestMode = true

    RefreshSlots(ctx.slots, ctx.inventory)
    RefreshSlots(ctx.chestSlots, chestInventory)
    ctx.overlay:SetVisible(true)
    ctx.isOpen = true
    print("[InventoryUI] Bag opened (chest mode)")
end

--- 关闭背包（任意模式）
---@param ctx table
function InventoryUI.Close(ctx)
    if not ctx.overlay then return end

    ctx.overlay:SetVisible(false)
    ctx.isOpen = false

    -- 清理宝箱模式
    if ctx.chestMode and ctx.chestCard then
        ctx.contentContainer:RemoveChild(ctx.chestCard)
        ctx.chestMode = false
    end

    print("[InventoryUI] Bag closed")
end

--- 背包是否打开
---@param ctx table
---@return boolean
function InventoryUI.IsOpen(ctx)
    return ctx.isOpen == true
end

--- 刷新显示（外部数据变更后调用）
---@param ctx table
function InventoryUI.Refresh(ctx)
    RefreshSlots(ctx.slots, ctx.inventory)
    if ctx.chestMode and ctx.chestInventory then
        RefreshSlots(ctx.chestSlots, ctx.chestInventory)
    end
end

return InventoryUI
