-- ============================================================================
-- HUD.lua - 游戏信息界面（血条、经验条、波次信息）
-- ============================================================================

local UI = require("urhox-libs/UI")
local Player = require("Player")
local EnemySpawner = require("EnemySpawner")

local HUD = {}

--- 创建 HUD 面板
---@return table hud 对象，包含 panel 和各 UI 引用
function HUD.Create()
    local hud = {}

    -- 血条
    hud.hpBar = UI.ProgressBar {
        value = 1,
        width = "100%",
        height = 14,
        fillColor = "#FF4444",
        backgroundColor = { 40, 40, 40, 200 },
        borderRadius = 7,
    }

    hud.hpLabel = UI.Label {
        text = "100/100",
        fontSize = 10,
        color = "#FFFFFF",
    }

    -- 经验条
    hud.xpBar = UI.ProgressBar {
        value = 0,
        width = "100%",
        height = 8,
        fillGradient = {
            direction = "to-right",
            from = "#66FF99",
            to = "#33CC66",
        },
        backgroundColor = { 40, 40, 40, 200 },
        borderRadius = 4,
    }

    -- 等级标签
    hud.levelLabel = UI.Label {
        text = "Lv.1",
        fontSize = 16,
        color = "#FFDD44",
        fontWeight = "bold",
    }

    -- 波次标签
    hud.waveLabel = UI.Label {
        text = "Wave 1/5",
        fontSize = 13,
        color = "#AAAACC",
    }

    -- 状态文字（胜利/失败）
    hud.statusLabel = UI.Label {
        text = "",
        fontSize = 28,
        color = "#FFFFFF",
        fontWeight = "bold",
        display = "none",
    }

    hud.restartHint = UI.Label {
        text = "",
        fontSize = 14,
        color = "#AAAAAA",
        display = "none",
    }

    -- 组装面板
    hud.panel = UI.Panel {
        width = "100%",
        height = "100%",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        paddingTop = 48,  -- 留出安全区域
        paddingLeft = 14,
        paddingRight = 14,
        pointerEvents = "box-none",
        gap = 4,
        children = {
            -- 顶部行：等级 + 波次
            UI.Panel {
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                width = "100%",
                children = {
                    hud.levelLabel,
                    hud.waveLabel,
                }
            },
            -- 血条 + 数值
            UI.Panel {
                width = "100%",
                gap = 2,
                children = {
                    hud.hpBar,
                    UI.Panel {
                        flexDirection = "row",
                        justifyContent = "center",
                        width = "100%",
                        children = { hud.hpLabel }
                    },
                }
            },
            -- 经验条
            hud.xpBar,
            -- 状态文字居中
            UI.Panel {
                width = "100%",
                flexGrow = 1,
                justifyContent = "center",
                alignItems = "center",
                pointerEvents = "box-none",
                gap = 8,
                children = {
                    hud.statusLabel,
                    hud.restartHint,
                },
            },
        }
    }

    return hud
end

--- 刷新 HUD 显示
---@param hud table HUD.Create() 返回的对象
function HUD.Refresh(hud)
    if not hud then return end

    -- 血条
    local hpRatio = Player.hp / Player.maxHp
    hud.hpBar:SetValue(math.max(0, math.min(1, hpRatio)))
    hud.hpLabel:SetText(math.floor(Player.hp) .. "/" .. math.floor(Player.maxHp))

    -- 经验条
    hud.xpBar:SetValue(Player.GetXPProgress())

    -- 等级
    hud.levelLabel:SetText("Lv." .. Player.level)

    -- 波次
    local wave, total = EnemySpawner.GetWaveInfo()
    local stateIcon = ""
    if EnemySpawner.waveState == "warning" then
        stateIcon = " !"
    elseif EnemySpawner.waveState == "done" then
        stateIcon = " OK"
    end
    hud.waveLabel:SetText("Wave " .. wave .. "/" .. total .. stateIcon)
end

--- 显示状态文字（胜利/失败）
---@param hud table
---@param text string
---@param hint string|nil 提示文字
function HUD.ShowStatus(hud, text, hint)
    if hud and hud.statusLabel then
        hud.statusLabel:SetText(text)
        hud.statusLabel:SetStyle({ display = "flex" })
    end
    if hud and hud.restartHint and hint then
        hud.restartHint:SetText(hint)
        hud.restartHint:SetStyle({ display = "flex" })
    end
end

--- 隐藏状态文字
---@param hud table
function HUD.HideStatus(hud)
    if hud and hud.statusLabel then
        hud.statusLabel:SetText("")
        hud.statusLabel:SetStyle({ display = "none" })
    end
    if hud and hud.restartHint then
        hud.restartHint:SetText("")
        hud.restartHint:SetStyle({ display = "none" })
    end
end

return HUD
