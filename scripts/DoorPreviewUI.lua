-- ============================================================================
-- DoorPreviewUI.lua - 战斗房门宝箱预览弹窗
-- 点击战斗房门口时弹出，横向展示宝箱候选道具列表
-- ============================================================================

local UI = require("urhox-libs/UI")
local ItemDB = require("ItemDB")

local DoorPreviewUI = {}

local MAX_SLOTS = 12   -- 预分配格子上限（品质1+2*5=11，留余量）
local SLOT_W    = 56
local SLOT_H    = 72

-- 与 InventoryUI 保持一致的品质背景色
local QUALITY_BG = {
    [1] = { 55,  55,  55 },
    [2] = { 38,  58,  38 },
    [3] = { 38,  45,  65 },
    [4] = { 52,  38,  62 },
    [5] = { 62,  48,  30 },
    [6] = { 62,  32,  32 },
}

-- ============================================================================
-- PreviewSlot - 纯展示物品格子（NanoVG 渲染，无交互）
-- ============================================================================

local PreviewSlot = UI.Widget:Extend("PreviewSlot")

function PreviewSlot:Init(props)
    props = props or {}
    props.width  = SLOT_W
    props.height = SLOT_H
    UI.Widget.Init(self, props)
    self.proto_ = nil
end

function PreviewSlot:SetProto(proto)
    self.proto_ = proto
end

function PreviewSlot:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if not l then return end
    local x, y, w, h = l.x, l.y, l.w, l.h

    local proto = self.proto_

    -- 背景
    local bg = proto and (QUALITY_BG[proto.quality] or { 55, 55, 55 }) or { 40, 45, 55 }
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, x + 1, y + 1, w - 2, h - 2, 5)
    nvgFillColor(nvg, nvgRGBA(bg[1], bg[2], bg[3], 255))
    nvgFill(nvg)

    if not proto then
        -- 空格边框
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + 0.5, y + 0.5, w - 1, h - 1, 5)
        nvgStrokeColor(nvg, nvgRGBA(70, 75, 85, 255))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
        return
    end

    -- 品质边框
    local qInfo = ItemDB.GetQualityInfo(proto.quality)
    if qInfo then
        local bc = qInfo.borderColor
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + 0.5, y + 0.5, w - 1, h - 1, 5)
        nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end

    -- 物品图标（emoji）
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 30)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 255))
    nvgText(nvg, x + w / 2, y + h / 2 - 7, proto.icon)

    -- 品质名称
    if qInfo then
        local qc = qInfo.color
        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, nvgRGBA(qc[1], qc[2], qc[3], 255))
        nvgText(nvg, x + w / 2, y + h - 9, qInfo.name)
    end
end

-- ============================================================================
-- DoorPreviewUI 公共接口
-- ============================================================================

function DoorPreviewUI.Create()
    local ctx = {}

    -- 预分配 MAX_SLOTS 个展示格
    ctx.slots_ = {}
    local slotPanels = {}
    for i = 1, MAX_SLOTS do
        local slot = PreviewSlot {}
        ctx.slots_[i] = slot
        slotPanels[i] = slot
    end

    -- 道具横向列表（自动换行，居中对齐）
    local itemRow = UI.Panel {
        flexDirection  = "row",
        flexWrap       = "wrap",
        gap            = 6,
        justifyContent = "center",
        children       = slotPanels,
    }

    -- 关闭按钮
    local closeBtn = UI.Button {
        text         = "关闭",
        fontSize     = 12,
        width        = 80,
        height       = 32,
        variant      = "outline",
        borderRadius = 6,
        color        = "#AACCFF",
        borderColor  = "#6688BB",
        onClick      = function()
            DoorPreviewUI.Hide(ctx)
        end,
    }

    -- 卡片容器
    local card = UI.Panel {
        backgroundColor = "rgb(18, 20, 30)",
        borderWidth     = 1.5,
        borderColor     = "rgb(80, 80, 110)",
        borderRadius    = 12,
        padding         = 18,
        flexDirection   = "column",
        gap             = 14,
        alignItems      = "center",
        maxWidth        = 420,
        children        = {
            UI.Label {
                text       = "有可能摸出以下物品",
                fontSize   = 14,
                color      = "rgb(200, 200, 220)",
                fontWeight = "bold",
            },
            itemRow,
            closeBtn,
        }
    }

    -- 点击卡片区域不关闭（吸收事件，不冒泡到遮罩）
    card.OnPointerDown = function(self, event) end

    -- 全屏半透明遮罩
    local overlay = UI.Panel {
        position        = "absolute",
        width           = "100%",
        height          = "100%",
        alignItems      = "center",
        justifyContent  = "center",
        backgroundColor = "rgba(0, 0, 0, 160)",
        visible         = false,
        children        = { card },
    }

    -- 点击遮罩空白区域关闭
    overlay.OnPointerDown = function(self, event)
        DoorPreviewUI.Hide(ctx)
    end

    ctx.overlay_ = overlay
    return ctx
end

--- 展示预览弹窗
---@param ctx table
---@param previewPool table[] 原型列表（BuildChestPreviewPool 的返回值）
function DoorPreviewUI.Show(ctx, previewPool)
    for i = 1, MAX_SLOTS do
        local slot  = ctx.slots_[i]
        local proto = previewPool[i]
        slot:SetProto(proto or nil)
        slot:SetVisible(proto ~= nil)
    end
    ctx.overlay_:SetVisible(true)
end

--- 关闭弹窗
---@param ctx table
function DoorPreviewUI.Hide(ctx)
    ctx.overlay_:SetVisible(false)
end

--- 当前是否打开
---@param ctx table
---@return boolean
function DoorPreviewUI.IsOpen(ctx)
    return ctx.overlay_:IsVisible()
end

--- 获取 overlay Panel（需插入 UI 树）
---@param ctx table
---@return any
function DoorPreviewUI.GetOverlay(ctx)
    return ctx.overlay_
end

return DoorPreviewUI
