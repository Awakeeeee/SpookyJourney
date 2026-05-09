-- ============================================================================
-- main.lua - 游戏入口
-- Roguelike 单房间战斗闭环 MVP
-- ============================================================================

local UI = require("urhox-libs/UI")
require "urhox-libs.UI.VirtualControls"

local Config = require("Config")
local GameState = require("GameState")
local GameCanvas = require("GameCanvas")
local HUD = require("HUD")
local LevelUpUI = require("LevelUpUI")
local Particle = require("Particle")
local ItemDB = require("ItemDB")
local Inventory = require("Inventory")
local InventoryUI = require("InventoryUI")
local DoorPreviewUI = require("DoorPreviewUI")

---@type any
local joystick_ = nil
---@type any
local gameCanvas_ = nil
---@type table
local hud_ = nil
---@type table
local levelUpUI_ = nil
---@type any
local debugBtn_ = nil
---@type any
local bagBtn_ = nil
---@type any
local openChestBtn_ = nil
---@type InventoryData
local playerBag_ = nil
---@type table
local inventoryUI_ = nil
---@type table
local doorPreviewUI_ = nil
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

    -- 通过 UI 指针事件检测门口点击（不受 VirtualControls 干扰）
    -- room_clear：战斗房通关后；playing：恢复/撤离房进入即有门
    gameCanvas_.OnPointerDown = function(self, event)
        local st = GameState.state
        if st ~= "room_clear" and st ~= "playing" then return end
        if DoorPreviewUI.IsOpen(doorPreviewUI_) then return end

        local sx, sy = event.x, event.y
        local gx, gy = gameCanvas_:ScreenToGame(sx, sy)
        local tapR = Config.DOOR.triggerRadius * 2.0
        print(string.format("[DoorPreview] tap game=(%.0f,%.0f) doors=%d", gx, gy, #(GameState.doors or {})))
        for _, door in ipairs(GameState.doors or {}) do
            if door.previewPool then
                local dx, dy = gx - door.x, gy - door.y
                if (dx * dx + dy * dy) < (tapR * tapR) then
                    print(string.format("[DoorPreview] hit door type=%s", door.type))
                    DoorPreviewUI.Show(doorPreviewUI_, door.previewPool)
                    return
                end
            end
        end
    end

    -- 创建 HUD
    hud_ = HUD.Create()

    -- 创建升级弹窗
    levelUpUI_ = LevelUpUI.Create(function(upgrade)
        GameState.ApplyUpgrade(upgrade)
        HUD.HideStatus(hud_)
    end)

    -- DEBUG 按钮（右下角）
    debugBtn_ = UI.Button {
        text = "DEBUG\nClear",
        fontSize = 11,
        width = 60,
        height = 44,
        variant = "outline",
        borderRadius = 6,
        color = "#FF8800",
        borderColor = "#FF8800",
        onClick = function()
            GameState.DebugClearRoom()
        end,
    }

    -- 初始化背包系统
    playerBag_ = Inventory.New(8, 3)
    inventoryUI_ = InventoryUI.Create(playerBag_)

    -- 初始化门预览 UI
    doorPreviewUI_ = DoorPreviewUI.Create()

    -- 背包按钮（左下角）
    bagBtn_ = UI.Button {
        text = "背包",
        fontSize = 12,
        width = 56,
        height = 40,
        variant = "outline",
        borderRadius = 6,
        color = "#AACCFF",
        borderColor = "#6688BB",
        onClick = function()
            if not InventoryUI.IsOpen(inventoryUI_) then
                InventoryUI.Open(inventoryUI_)
            end
        end,
    }

    -- 开箱按钮（摇杆右侧，初始隐藏）
    openChestBtn_ = UI.Button {
        text = "开启\n宝箱",
        fontSize = 11,
        width = 56,
        height = 44,
        variant = "outline",
        borderRadius = 6,
        color = "#FFD850",
        borderColor = "#CC9900",
        onClick = function()
            local chestInv = GameState.GetChestInventory()
            if chestInv and not InventoryUI.IsOpen(inventoryUI_) then
                -- 传入宝箱实例的 scanState，用于持久化各格扫描进度
                local scanState = GameState.chest and GameState.chest.scanState or nil
                InventoryUI.OpenChest(inventoryUI_, chestInv, scanState)
            end
        end,
    }

    -- 构建 UI 树：画布(底) + HUD(顶) + 按钮 + 背包Overlay
    local root = UI.Panel {
        width = "100%",
        height = "100%",
        children = {
            gameCanvas_,
            hud_.panel,
            -- 背包按钮（左下角定位）
            UI.Panel {
                position = "absolute",
                bottom = 20,
                left = 14,
                children = { bagBtn_ },
            },
            -- 开箱按钮容器（摇杆右侧，初始隐藏）
            UI.Panel {
                position = "absolute",
                bottom = 100,
                left = "56%",
                children = { openChestBtn_ },
            },
            -- DEBUG 按钮容器（右下角定位）
            UI.Panel {
                position = "absolute",
                bottom = 20,
                right = 14,
                children = { debugBtn_ },
            },
            -- 背包 Overlay（全屏覆盖，初始隐藏）
            InventoryUI.GetOverlay(inventoryUI_),
            -- 门预览 Overlay（全屏覆盖，初始隐藏）
            DoorPreviewUI.GetOverlay(doorPreviewUI_),
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

    -- 背包打开时暂停游戏逻辑（但仍推进宝箱扫描动画）
    if InventoryUI.IsOpen(inventoryUI_) then
        InventoryUI.UpdateChestScan(inventoryUI_, dt)
        return
    end

    -- 门预览弹窗打开时，暂停其他逻辑
    if DoorPreviewUI.IsOpen(doorPreviewUI_) then
        return
    end

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

    elseif state == "room_clear" then
        -- 房间已通关，玩家可移动选门
        -- 门口点击检测由 gameCanvas_.OnPointerDown 处理
        GameState.Update(dt, inputX, inputY)

    elseif state == "transition" then
        -- 过渡到下一房间
        GameState.Update(dt, inputX, inputY)

    elseif state == "victory" then
        if not statusShown_ then
            HUD.ShowStatus(hud_, "Victory!", "Successfully Evacuated!\nTap to restart")
            statusShown_ = true
        end
        Particle.Update(dt)
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

    -- 更新开箱按钮可见性
    if openChestBtn_ then
        openChestBtn_:SetVisible(GameState.CanOpenChest())
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
