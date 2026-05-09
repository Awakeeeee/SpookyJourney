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
-- 扫描时长（按品质插值，单位秒）
-- ============================================================================
local SCAN_DURATION_MIN = 0.5   -- 白色品质
local SCAN_DURATION_MAX = 4.0   -- 红色品质
local QUALITY_MAX = 6

local function GetScanDuration(quality)
    local t = (quality - 1) / (QUALITY_MAX - 1)  -- 0~1
    return SCAN_DURATION_MIN + t * (SCAN_DURATION_MAX - SCAN_DURATION_MIN)
end

-- 未鉴定格子的特殊背景色（比空格子更深，但无品质色）
local BG_UNKNOWN = { 28, 28, 35, 255 }

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
-- 宝箱格子扫描补丁
-- ============================================================================

--- 给宝箱格子打补丁，实现"搜索扫描"效果：
---  - 未 revealed → 深背景 + "?" + 冷却弧遮罩
---  - revealed → 正常品质显示
---@param slot table ItemSlot 实例
---@param slotIndex number 格子索引（1-based）
---@param scanStateRef function 返回当前 scanState 表的函数（延迟获取，防止引用失效）
local function PatchChestSlot(slot, slotIndex, scanStateRef)

    -- 工具函数：判断该格子当前是否为"未鉴定"状态
    -- s==nil → 玩家后来放入的道具，不参与扫描 → 视为正常已鉴定
    -- s~=nil and not s.revealed → 初始物品尚未读条完成 → 未鉴定
    local function IsUnrevealed(self)
        if not self.props.item then return false end
        local scanState = scanStateRef()
        local s = scanState and scanState[slotIndex]
        return s ~= nil and not s.revealed
    end

    -- ① 重写 UpdateDisplay：未鉴定时强制 "?" + 深背景（不显示品质色）
    local origUpdateDisplay = slot.UpdateDisplay
    slot.UpdateDisplay = function(self)
        if IsUnrevealed(self) then
            self.iconLabel_:SetText("?")
            self.iconLabel_.props.fontColor = { 140, 140, 160, 200 }
            self.props.backgroundColor = BG_UNKNOWN
            self.props.borderColor = BORDER_DEFAULT
            self.quantityBadge_:SetVisible(false)
        else
            origUpdateDisplay(self)
        end
    end

    -- ② 阻断所有指针交互：未鉴定时 return，彻底禁止悬停/选中/拖拽
    local origOnPointerDown  = slot.OnPointerDown
    local origOnPointerUp    = slot.OnPointerUp
    local origOnPointerEnter = slot.OnPointerEnter
    local origOnPointerLeave = slot.OnPointerLeave
    local origOnClick        = slot.OnClick

    slot.OnPointerDown = function(self, event)
        if IsUnrevealed(self) then return end
        if origOnPointerDown then return origOnPointerDown(self, event) end
    end
    slot.OnPointerUp = function(self, event)
        if IsUnrevealed(self) then return end
        if origOnPointerUp then return origOnPointerUp(self, event) end
    end
    slot.OnPointerEnter = function(self, event)
        if IsUnrevealed(self) then return end
        if origOnPointerEnter then return origOnPointerEnter(self, event) end
    end
    slot.OnPointerLeave = function(self, event)
        if IsUnrevealed(self) then return end
        if origOnPointerLeave then return origOnPointerLeave(self, event) end
    end
    slot.OnClick = function(self, event)
        if IsUnrevealed(self) then return end
        if origOnClick then return origOnClick(self, event) end
    end

    -- ③ 重写 CustomRenderChildren：顺时针扇形遮罩 + 高品质揭示 Punch 动画
    slot.CustomRenderChildren = function(self, nvg, renderFn)
        -- 先正常渲染子节点
        local renderList = self:GetRenderChildren()
        for i = 1, #renderList do
            renderFn(renderList[i], nvg)
        end

        local scanState = scanStateRef()
        local s = scanState and scanState[slotIndex]

        -- 扇形遮罩（未鉴定时）
        if IsUnrevealed(self) then
            local l = self:GetAbsoluteLayout()
            if l then
                local progress = s and s.progress or 0
                local remaining = 1 - progress
                if remaining > 0.001 then
                    local cx = l.x + l.w * 0.5
                    local cy = l.y + l.h * 0.5
                    local r  = math.min(l.w, l.h) * 0.5 + 2
                    -- NVG_CW = 2；从 12 点方向顺时针覆盖剩余比例
                    local startA = -math.pi * 0.5
                    local endA   = startA + remaining * 2 * math.pi
                    nvgBeginPath(nvg)
                    nvgMoveTo(nvg, cx, cy)
                    nvgArc(nvg, cx, cy, r, startA, endA, 2)
                    nvgClosePath(nvg)
                    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 180))
                    nvgFill(nvg)
                end
            end
        end

        -- Punch 动画（品质 >= 5 的物品揭示瞬间）
        if s and s.punchTimer and s.punchTimer > 0 then
            local l = self:GetAbsoluteLayout()
            if l then
                local PUNCH_DURATION = 0.4
                local t = s.punchTimer / PUNCH_DURATION  -- 1.0（开始）→ 0.0（结束）
                local cx = l.x + l.w * 0.5
                local cy = l.y + l.h * 0.5
                -- 扩散光环：半径从格子边缘向外扩展，同时 alpha 衰减
                local baseR = math.min(l.w, l.h) * 0.5
                local ringR = baseR * (1.0 + (1.0 - t) * 0.8)
                local alpha = math.floor(t * 220)
                nvgBeginPath(nvg)
                nvgCircle(nvg, cx, cy, ringR)
                nvgStrokeColor(nvg, nvgRGBA(255, 200, 80, alpha))
                nvgStrokeWidth(nvg, 3.0)
                nvgStroke(nvg)
                -- 内圈二次光晕（让效果更饱满）
                if t > 0.5 then
                    local innerAlpha = math.floor((t - 0.5) * 2 * 120)
                    nvgBeginPath(nvg)
                    nvgCircle(nvg, cx, cy, baseR * (1.0 + (1.0 - t) * 0.3))
                    nvgStrokeColor(nvg, nvgRGBA(255, 240, 180, innerAlpha))
                    nvgStrokeWidth(nvg, 2.0)
                    nvgStroke(nvg)
                end
            end
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
        -- 扫描状态（由 GameState.chest.scanState 传入，外部持有）
        chestScanState = nil,
        -- 当前正在推进扫描的格子索引（逐格扫描）
        chestScanCursor = 1,
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

            -- 迁移宝箱扫描状态（防止已鉴定物品移位后显示为未鉴定）
            if ctx.chestScanState then
                if fromCategory == "chest_inv" and toCategory == "chest_inv" then
                    -- 宝箱内移动：把源格子的扫描状态迁移到目标格子
                    ctx.chestScanState[toId] = ctx.chestScanState[fromId]
                    ctx.chestScanState[fromId] = nil
                elseif fromCategory == "chest_inv" then
                    -- 从宝箱移到玩家背包：物品已离开宝箱，清除其扫描状态
                    ctx.chestScanState[fromId] = nil
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

    -- 给每个宝箱格子打扫描补丁
    for i, slot in ipairs(ctx.chestSlots) do
        PatchChestSlot(slot, i, function() return ctx.chestScanState end)
    end

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
---@param scanState table|nil 宝箱实例的 scanState 表（由 GameState.chest.scanState 传入）
function InventoryUI.OpenChest(ctx, chestInventory, scanState)
    if not ctx.overlay then return end

    -- 保存扫描状态引用（已由 GameState._SpawnChest 在宝箱生成时完整初始化）
    -- 此处不做任何额外初始化，s==nil 永远意味着"玩家后来放入的道具"
    ctx.chestScanState = scanState or {}

    -- 游标定位到第一个未完成的格子
    ctx.chestScanCursor = 1
    local total = chestInventory:GetSize()
    for i = 1, total do
        local s = ctx.chestScanState[i]
        if s and not s.revealed then
            ctx.chestScanCursor = i
            break
        end
    end

    -- 构建/重建宝箱卡片（PatchChestSlot 会读取 ctx.chestScanState）
    BuildChestCard(ctx, chestInventory)

    -- 将宝箱卡片插入到背包卡片之前
    -- contentContainer 的 children: [topSpacer, bagCard]
    -- 需要变成: [topSpacer, chestCard, bagCard]
    -- 由于没有 insertBefore，先移除 bagCard，添加 chestCard，再加回 bagCard
    ctx.contentContainer:RemoveChild(ctx.bagCard)
    ctx.contentContainer:AddChild(ctx.chestCard)
    ctx.contentContainer:AddChild(ctx.bagCard)

    ctx.chestMode = true

    RefreshSlots(ctx.slots, ctx.inventory)
    RefreshSlots(ctx.chestSlots, chestInventory)
    ctx.overlay:SetVisible(true)
    ctx.isOpen = true
    print("[InventoryUI] Bag opened (chest mode), scanCursor=" .. ctx.chestScanCursor)
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

        -- 重置未完成格子的扫描进度（关闭时中途扫描视为作废，重新开始）
        local GameState = require("GameState")
        GameState.ResetChestScanProgress()
        ctx.chestScanState = nil
        ctx.chestScanCursor = 1
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

--- 每帧推进宝箱扫描进度（宝箱打开时由主循环调用）
--- 逐格扫描：当前游标格扫描完成后自动跳到下一格
---@param ctx table
---@param dt number 帧时间（秒）
function InventoryUI.UpdateChestScan(ctx, dt)
    if not ctx.chestMode then return end
    local scanState = ctx.chestScanState
    if not scanState then return end
    local chestInv = ctx.chestInventory
    if not chestInv then return end

    local totalSlots = chestInv:GetSize()

    -- 每帧递减所有活跃的 Punch 动画计时器
    for _, s in pairs(scanState) do
        if s.punchTimer and s.punchTimer > 0 then
            s.punchTimer = math.max(0, s.punchTimer - dt)
        end
    end

    -- 从游标开始，推进当前格扫描进度
    while ctx.chestScanCursor <= totalSlots do
        local idx = ctx.chestScanCursor
        local item = chestInv:GetItem(idx)
        local s = scanState[idx]

        -- 跳过：无物品 / 玩家后来放入（无 scanState 条目）/ 已完成
        if not item or not s or s.revealed then
            ctx.chestScanCursor = idx + 1
        else
            -- 正在扫描：推进进度
            local dur = GetScanDuration(item.quality or 1)
            s.progress = math.min(1, (s.progress or 0) + dt / dur)

            if s.progress >= 1 then
                s.revealed = true
                -- 橙色（quality=5）及以上启动 Punch 动画
                if (item.quality or 1) >= 5 then
                    s.punchTimer = 0.4
                end
                -- 刷新该格显示（"?" → 正常图标）
                local slot = ctx.chestSlots[idx]
                if slot then
                    slot:SetItem(item)
                end
                print("[ChestScan] slot " .. idx .. " revealed (quality=" .. (item.quality or 1) .. ")")
                ctx.chestScanCursor = idx + 1
            end
            -- 本帧只推进一格
            break
        end
    end
end

return InventoryUI
