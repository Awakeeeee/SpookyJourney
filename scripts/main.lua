-- ============================================================================
-- main.lua - 游戏入口
-- Roguelike 单房间战斗闭环 MVP
-- ============================================================================

local UI = require("urhox-libs/UI")
require "urhox-libs.UI.VirtualControls"

local GameState = require("GameState")
local GameCanvas = require("GameCanvas")
local HUD = require("HUD")
local LevelUpUI = require("LevelUpUI")
local Particle = require("Particle")

---@type any
local joystick_ = nil
---@type any
local gameCanvas_ = nil
---@type table
local hud_ = nil
---@type table
local levelUpUI_ = nil
local statusShown_ = false

-- ============================================================================
-- Start / Stop
-- ============================================================================

function Start()
    print("[Main] ===== Game Starting =====")

    -- 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 初始化游戏
    GameState.Init()
    statusShown_ = false

    -- 创建虚拟摇杆（底部中央）
    joystick_ = VirtualControls.CreateJoystick({
        alignment = { HA_CENTER, VA_BOTTOM },
        position = Vector2(0, -130),
        baseRadius = 55,
        knobRadius = 22,
        moveRadius = 38,
        deadZone = 0.15,
        opacity = 0.35,
        activeOpacity = 0.7,
        keyBinding = "WASD",
        alwaysShow = true,
    })
    -- 强制移动端模式：PC浏览器也显示圆形摇杆（而非WASD按键提示）
    VirtualControls.SetMobileMode(true)
    -- 启用鼠标模拟触摸：PC端鼠标拖拽可操作摇杆
    VirtualControls.SetMouseEmulation(true)

    -- 创建游戏画布
    gameCanvas_ = GameCanvas {
        width = "100%",
        height = "100%",
    }
    gameCanvas_:SetGameState(GameState)

    -- 创建 HUD
    hud_ = HUD.Create()

    -- 创建升级弹窗
    levelUpUI_ = LevelUpUI.Create(function(upgrade)
        GameState.ApplyUpgrade(upgrade)
        HUD.HideStatus(hud_)
    end)

    -- 构建 UI 树：画布(底) + HUD(顶)
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        children = {
            gameCanvas_,
            hud_.panel,
        }
    }
    UI.SetRoot(root)

    -- 订阅更新事件
    SubscribeToEvent("Update", "HandleUpdate")

    print("[Main] Game initialized successfully!")
end

function Stop()
    print("[Main] Game stopping.")
    UI.Shutdown()
end

-- ============================================================================
-- 主循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 读取摇杆输入
    local inputX = 0
    local inputY = 0
    if joystick_ then
        inputX = joystick_.x or 0
        inputY = joystick_.y or 0
    end

    local state = GameState.state

    if state == "playing" then
        GameState.Update(dt, inputX, inputY)

    elseif state == "levelup" then
        -- 升级暂停：显示选择弹窗
        if GameState.pendingLevelUp and not LevelUpUI.IsOpen(levelUpUI_) then
            LevelUpUI.Show(levelUpUI_)
            GameState.pendingLevelUp = false
        end
        -- 暂停时仍更新粒子动画
        Particle.Update(dt)

    elseif state == "victory" then
        if not statusShown_ then
            HUD.ShowStatus(hud_, "Victory!", "Tap to restart")
            statusShown_ = true
        end
        Particle.Update(dt)
        -- 点击重开
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            _RestartGame()
        end

    elseif state == "gameover" then
        if not statusShown_ then
            HUD.ShowStatus(hud_, "Game Over", "Tap to restart")
            statusShown_ = true
        end
        Particle.Update(dt)
        -- 点击重开
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            _RestartGame()
        end
    end

    -- 刷新 HUD
    HUD.Refresh(hud_)
end

--- 重新开始游戏
function _RestartGame()
    print("[Main] Restarting game...")
    GameState.Restart()
    HUD.HideStatus(hud_)
    statusShown_ = false
    if gameCanvas_ then
        gameCanvas_:SetGameState(GameState)
    end
end
