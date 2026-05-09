-- ============================================================================
-- GameCanvas.lua - 自定义游戏渲染 Widget
-- 将游戏世界通过 NanoVG 渲染到 UI 组件中
-- ============================================================================

local UI = require("urhox-libs/UI")
local Config = require("Config")
local Renderer = require("Renderer")

local GameCanvas = UI.Widget:Extend("GameCanvas")

function GameCanvas:Init(props)
    props = props or {}
    props.backgroundColor = { Config.BG_COLOR[1], Config.BG_COLOR[2], Config.BG_COLOR[3], 255 }
    UI.Widget.Init(self, props)
    self.gameState_ = nil
    -- 当前帧的渲染变换（Render 时记录，供坐标转换使用）
    self.txOffsetX_ = 0
    self.txOffsetY_ = 0
    self.txScale_   = 1
end

--- 设置 GameState 引用，供 Render 时读取数据
---@param gs table GameState 模块
function GameCanvas:SetGameState(gs)
    self.gameState_ = gs
end

--- 自定义 NanoVG 渲染
---@param nvg userdata NanoVG 上下文
function GameCanvas:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if not l or l.w <= 0 or l.h <= 0 then return end

    -- 计算缩放：将 ROOM 等比缩放以适应 widget 大小
    local scaleX = l.w / Config.ROOM_WIDTH
    local scaleY = l.h / Config.ROOM_HEIGHT
    local scale = math.min(scaleX, scaleY)

    -- 居中偏移
    local offsetX = l.x + (l.w - Config.ROOM_WIDTH * scale) / 2
    local offsetY = l.y + (l.h - Config.ROOM_HEIGHT * scale) / 2

    -- 记录变换参数（供 ScreenToGame 使用）
    self.txOffsetX_ = offsetX
    self.txOffsetY_ = offsetY
    self.txScale_   = scale

    nvgSave(nvg)
    -- 裁剪到 widget 区域
    nvgScissor(nvg, l.x, l.y, l.w, l.h)
    -- 变换到游戏世界坐标
    nvgTranslate(nvg, offsetX, offsetY)
    nvgScale(nvg, scale, scale)

    -- 绘制所有游戏元素
    Renderer.DrawAll(nvg, self.gameState_)

    nvgResetScissor(nvg)
    nvgRestore(nvg)

    -- HUD 层：撤离倒计时（屏幕坐标）
    Renderer.DrawEvacuationCountdown(nvg, self.gameState_, l.w)
end

--- 将屏幕坐标转换为游戏世界坐标
---@param screenX number
---@param screenY number
---@return number gameX, number gameY
function GameCanvas:ScreenToGame(screenX, screenY)
    local scale = self.txScale_
    if scale <= 0 then return 0, 0 end
    return (screenX - self.txOffsetX_) / scale,
           (screenY - self.txOffsetY_) / scale
end

return GameCanvas
