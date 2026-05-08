-- ============================================================================
-- LevelUpUI.lua - 升级三选一弹窗
-- ============================================================================

local UI = require("urhox-libs/UI")
local Upgrade = require("Upgrade")
local Player = require("Player")

local LevelUpUI = {}

--- 创建升级 UI 管理器
---@param onChoose function(upgrade) 选择回调
---@return table lui 管理对象
function LevelUpUI.Create(onChoose)
    local lui = {}
    lui.onChoose = onChoose
    lui.modal = nil
    return lui
end

--- 显示升级选择弹窗
---@param lui table LevelUpUI.Create 返回的对象
function LevelUpUI.Show(lui)
    local choices = Upgrade.GetChoices(3, Player)

    if #choices == 0 then
        -- 没有可用升级，直接跳过
        print("[LevelUpUI] No upgrades available, skipping.")
        if lui.onChoose then lui.onChoose(nil) end
        return
    end

    -- 构建选项卡片
    local cards = {}
    for _, choice in ipairs(choices) do
        local levelText = ""
        if choice.maxLevel > 1 then
            levelText = " Lv." .. (choice.currentLevel + 1) .. "/" .. choice.maxLevel
        end

        -- 按类别着色
        local cardBg
        if choice.category == "weapon" then
            cardBg = { 70, 40, 90, 240 }
        elseif choice.category == "enhance" then
            cardBg = { 40, 55, 85, 240 }
        else
            cardBg = { 40, 70, 50, 240 }
        end

        -- 类别图标
        local icon
        if choice.category == "weapon" then
            icon = "[NEW] "
        elseif choice.category == "enhance" then
            icon = "[UP] "
        else
            icon = ""
        end

        table.insert(cards, UI.Button {
            width = "100%",
            height = 76,
            backgroundColor = cardBg,
            borderRadius = 10,
            borderColor = { 120, 120, 180, 180 },
            borderWidth = 1,
            onClick = function()
                if lui.onChoose then
                    lui.onChoose(choice)
                end
                if lui.modal then
                    lui.modal:Close()
                end
            end,
            children = {
                UI.Panel {
                    width = "100%",
                    height = "100%",
                    paddingLeft = 14,
                    paddingRight = 14,
                    justifyContent = "center",
                    gap = 4,
                    pointerEvents = "box-none",
                    children = {
                        UI.Label {
                            text = icon .. choice.name .. levelText,
                            fontSize = 16,
                            color = "#FFDD44",
                            fontWeight = "bold",
                        },
                        UI.Label {
                            text = choice.desc,
                            fontSize = 12,
                            color = "#CCCCDD",
                        },
                    }
                }
            }
        })
    end

    -- 创建或复用 Modal
    if lui.modal then
        lui.modal:ClearContent()
    else
        lui.modal = UI.Modal {
            title = "Level Up!",
            size = "sm",
            closeOnOverlay = false,
            closeOnEscape = false,
            showCloseButton = false,
        }
    end

    lui.modal:AddContent(UI.Panel {
        width = "100%",
        gap = 10,
        paddingTop = 4,
        paddingBottom = 4,
        children = cards,
    })

    lui.modal:Open()
end

--- 弹窗是否打开中
---@param lui table
---@return boolean
function LevelUpUI.IsOpen(lui)
    return lui.modal ~= nil and lui.modal:IsOpen()
end

return LevelUpUI
