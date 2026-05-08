-- ============================================================================
-- Renderer.lua - NanoVG 绘制函数（游戏世界坐标系）
-- ============================================================================

local Config = require("Config")
local Player = require("Player")
local EnemySpawner = require("EnemySpawner")
local Weapon = require("Weapon")
local Particle = require("Particle")
local Collision = require("Collision")

local Renderer = {}

--- 绘制所有游戏元素（在游戏世界坐标系下调用）
---@param nvg userdata NanoVG 上下文
---@param gameState table GameState 模块
function Renderer.DrawAll(nvg, gameState)
    Renderer.DrawBackground(nvg)
    Renderer.DrawRoomZone(nvg, gameState)
    Renderer.DrawWarnings(nvg)
    Renderer.DrawXPGems(nvg, gameState and gameState.xpGems)
    Renderer.DrawChest(nvg, gameState and gameState.chest)
    Renderer.DrawEnemies(nvg)
    Renderer.DrawEnemyBullets(nvg, gameState and gameState.enemyBullets)
    Renderer.DrawProjectiles(nvg)
    Renderer.DrawWeaponEffects(nvg)
    Renderer.DrawPlayer(nvg)
    Renderer.DrawParticles(nvg)
    Renderer.DrawDoors(nvg, gameState and gameState.doors)
    Renderer.DrawRoomBorder(nvg)
end

--- 绘制背景网格
function Renderer.DrawBackground(nvg)
    local bg = Config.BG_COLOR
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, Config.ROOM_WIDTH, Config.ROOM_HEIGHT)
    nvgFillColor(nvg, nvgRGBA(bg[1], bg[2], bg[3], bg[4]))
    nvgFill(nvg)

    -- 网格线
    local gc = Config.BG_GRID_COLOR
    nvgStrokeColor(nvg, nvgRGBA(gc[1], gc[2], gc[3], gc[4]))
    nvgStrokeWidth(nvg, 0.5)
    local gridSize = 40
    for x = 0, Config.ROOM_WIDTH, gridSize do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, 0)
        nvgLineTo(nvg, x, Config.ROOM_HEIGHT)
        nvgStroke(nvg)
    end
    for y = 0, Config.ROOM_HEIGHT, gridSize do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, 0, y)
        nvgLineTo(nvg, Config.ROOM_WIDTH, y)
        nvgStroke(nvg)
    end
end

--- 绘制房间边框
function Renderer.DrawRoomBorder(nvg)
    local bc = Config.ROOM_BORDER_COLOR
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, 0, Config.ROOM_WIDTH, Config.ROOM_HEIGHT)
    nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
end

--- 绘制玩家
function Renderer.DrawPlayer(nvg)
    local p = Player
    local alpha = 255
    -- 无敌闪烁效果
    if p.invulnTimer > 0 then
        alpha = (math.floor(p.invulnTimer * 10) % 2 == 0) and 100 or 255
    end
    local c = Config.PLAYER_COLOR

    -- 身体圆形
    nvgBeginPath(nvg)
    nvgCircle(nvg, p.x, p.y, p.radius)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], alpha))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, alpha))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 方向指示点
    local dirX = math.cos(p.facing) * p.radius * 1.3
    local dirY = math.sin(p.facing) * p.radius * 1.3
    nvgBeginPath(nvg)
    nvgCircle(nvg, p.x + dirX, p.y + dirY, 3)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, alpha))
    nvgFill(nvg)
end

--- 绘制敌人
function Renderer.DrawEnemies(nvg)
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive then
            -- 冲锋路径预警（蓄力阶段红色闪烁矩形）
            if e.aiType == "mob_clash" and e.aiState == "windup" then
                Renderer._DrawChargeWarning(nvg, e)
            end

            -- 根据 AI 类型绘制不同形状
            local fillR, fillG, fillB, fillA
            if e.flashTimer > 0 then
                fillR, fillG, fillB, fillA = 255, 255, 255, 220
            else
                fillR, fillG, fillB, fillA = e.color[1], e.color[2], e.color[3], e.color[4]
            end

            if e.aiType == "mob_shooter" then
                Renderer._DrawTriangle(nvg, e.x, e.y, e.radius, e.facing, fillR, fillG, fillB, fillA)
            elseif e.aiType == "mob_clash" then
                Renderer._DrawSquare(nvg, e.x, e.y, e.radius, fillR, fillG, fillB, fillA)
                -- 蓄力/冲锋中额外红色闪烁外框
                if e.aiState == "windup" then
                    local flash = math.sin(e.aiTimer * 16) * 0.5 + 0.5
                    local s = e.radius
                    nvgBeginPath(nvg)
                    nvgRect(nvg, e.x - s, e.y - s, s * 2, s * 2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 50, 50, math.floor(flash * 200)))
                    nvgStrokeWidth(nvg, 2.5)
                    nvgStroke(nvg)
                elseif e.aiState == "charging" then
                    nvgBeginPath(nvg)
                    local s = e.radius
                    nvgRect(nvg, e.x - s, e.y - s, s * 2, s * 2)
                    nvgStrokeColor(nvg, nvgRGBA(255, 100, 50, 180))
                    nvgStrokeWidth(nvg, 2)
                    nvgStroke(nvg)
                end
            else
                -- mob_common: 圆形
                nvgBeginPath(nvg)
                nvgCircle(nvg, e.x, e.y, e.radius)
                nvgFillColor(nvg, nvgRGBA(fillR, fillG, fillB, fillA))
                nvgFill(nvg)
            end

            -- 血条（受伤后显示）
            if e.hp < e.maxHp then
                local barW = e.radius * 2.2
                local barH = 3
                local barX = e.x - barW / 2
                local barY = e.y - e.radius - 7
                nvgBeginPath(nvg)
                nvgRect(nvg, barX, barY, barW, barH)
                nvgFillColor(nvg, nvgRGBA(40, 40, 40, 180))
                nvgFill(nvg)
                local ratio = math.max(0, e.hp / e.maxHp)
                nvgBeginPath(nvg)
                nvgRect(nvg, barX, barY, barW * ratio, barH)
                nvgFillColor(nvg, nvgRGBA(255, 60, 60, 220))
                nvgFill(nvg)
            end
        end
    end
end

--- 绘制三角形（远程敌人，顶点朝向 facing 方向）
function Renderer._DrawTriangle(nvg, cx, cy, r, facing, fr, fg, fb, fa)
    local r1 = r * 1.3  -- 前顶点稍长
    -- 三个顶点：前、左后、右后
    local ax = cx + math.cos(facing) * r1
    local ay = cy + math.sin(facing) * r1
    local bAngle = facing + math.rad(135)
    local bx = cx + math.cos(bAngle) * r
    local by = cy + math.sin(bAngle) * r
    local cAngle = facing - math.rad(135)
    local px = cx + math.cos(cAngle) * r
    local py = cy + math.sin(cAngle) * r
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, ax, ay)
    nvgLineTo(nvg, bx, by)
    nvgLineTo(nvg, px, py)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(fr, fg, fb, fa))
    nvgFill(nvg)
end

--- 绘制正方形（冲锋敌人）
function Renderer._DrawSquare(nvg, cx, cy, r, fr, fg, fb, fa)
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - r, cy - r, r * 2, r * 2)
    nvgFillColor(nvg, nvgRGBA(fr, fg, fb, fa))
    nvgFill(nvg)
end

--- 绘制冲锋路径预警（蓄力阶段，从敌人到目标的红色闪烁矩形）
function Renderer._DrawChargeWarning(nvg, e)
    local ai = Config.ENEMY_AI.mob_clash
    local flash = math.sin(e.aiTimer * 16) * 0.5 + 0.5
    local alpha = math.floor(flash * 80)
    local halfW = ai.chargeWidth / 2

    nvgSave(nvg)
    nvgTranslate(nvg, e.x, e.y)
    nvgRotate(nvg, math.atan(e.chargeDirY, e.chargeDirX))
    -- 从敌人位置到冲锋目标的矩形
    nvgBeginPath(nvg)
    nvgRect(nvg, 0, -halfW, e.chargeDistTotal, halfW * 2)
    nvgFillColor(nvg, nvgRGBA(255, 40, 40, alpha))
    nvgFill(nvg)
    -- 边框
    nvgStrokeColor(nvg, nvgRGBA(255, 60, 60, alpha + 30))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
    nvgRestore(nvg)
end

--- 绘制敌人子弹
function Renderer.DrawEnemyBullets(nvg, bullets)
    if not bullets then return end
    for _, b in ipairs(bullets) do
        if b.alive then
            -- 红色小菱形
            local s = b.radius + 1
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, b.x, b.y - s)
            nvgLineTo(nvg, b.x + s, b.y)
            nvgLineTo(nvg, b.x, b.y + s)
            nvgLineTo(nvg, b.x - s, b.y)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 80, 60, 240))
            nvgFill(nvg)
            -- 外发光
            nvgBeginPath(nvg)
            nvgCircle(nvg, b.x, b.y, s + 2)
            nvgFillColor(nvg, nvgRGBA(255, 60, 40, 60))
            nvgFill(nvg)
        end
    end
end

--- 绘制投射物
function Renderer.DrawProjectiles(nvg)
    for _, p in ipairs(Weapon.projectiles) do
        if p.alive then
            if p.weaponType == "knife" then
                -- 飞刀：白色小圆
                nvgBeginPath(nvg)
                nvgCircle(nvg, p.x, p.y, p.radius)
                nvgFillColor(nvg, nvgRGBA(220, 220, 240, 255))
                nvgFill(nvg)
            elseif p.weaponType == "wand" then
                -- 火球：橙色光晕
                nvgBeginPath(nvg)
                nvgCircle(nvg, p.x, p.y, p.radius + 3)
                nvgFillColor(nvg, nvgRGBA(255, 120, 30, 100))
                nvgFill(nvg)
                nvgBeginPath(nvg)
                nvgCircle(nvg, p.x, p.y, p.radius)
                nvgFillColor(nvg, nvgRGBA(255, 200, 60, 255))
                nvgFill(nvg)
            end
        end
    end
end

--- 绘制武器特效（剑挥砍弧、爆炸）
function Renderer.DrawWeaponEffects(nvg)
    for _, e in ipairs(Weapon.sweepEffects) do
        local alpha = math.floor(math.max(0, (e.timer / e.maxTime)) * 150)
        if e.isExplosion then
            -- 爆炸圆
            local progress = 1 - (e.timer / e.maxTime)
            local r = e.radius * (0.5 + progress * 0.5)
            nvgBeginPath(nvg)
            nvgCircle(nvg, e.x, e.y, r)
            nvgFillColor(nvg, nvgRGBA(255, 150, 30, alpha))
            nvgFill(nvg)
        elseif e.isSlash then
            -- 剑矩形斩击（闪白剑气）
            local progress = e.timer / e.maxTime  -- 1→0
            local flash = math.floor(math.max(0, progress) * 240)
            local halfW = e.slashWidth / 2

            nvgSave(nvg)
            nvgTranslate(nvg, e.x, e.y)
            nvgRotate(nvg, e.angle)

            -- 白色矩形填充
            nvgBeginPath(nvg)
            nvgRect(nvg, 0, -halfW, e.slashLength, e.slashWidth)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, flash))
            nvgFill(nvg)

            -- 淡蓝色描边（剑气感）
            nvgStrokeColor(nvg, nvgRGBA(180, 220, 255, flash))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)

            nvgRestore(nvg)
        end
    end
end

--- 绘制生成预警
function Renderer.DrawWarnings(nvg)
    for _, w in ipairs(EnemySpawner.warnings) do
        local flash = math.sin(w.timer * 12) * 0.5 + 0.5
        local alpha = math.floor(flash * 120)
        -- 闪烁圆
        nvgBeginPath(nvg)
        nvgCircle(nvg, w.x, w.y, 15)
        nvgFillColor(nvg, nvgRGBA(255, 60, 60, alpha))
        nvgFill(nvg)
        -- 外圈
        nvgBeginPath(nvg)
        nvgCircle(nvg, w.x, w.y, 18)
        nvgStrokeColor(nvg, nvgRGBA(255, 60, 60, math.min(255, alpha + 40)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end
end

--- 绘制经验宝石
function Renderer.DrawXPGems(nvg, gems)
    if not gems then return end
    for _, g in ipairs(gems) do
        if g.alive then
            local s = Config.XP_GEM_RADIUS
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, g.x, g.y - s)
            nvgLineTo(nvg, g.x + s * 0.7, g.y)
            nvgLineTo(nvg, g.x, g.y + s)
            nvgLineTo(nvg, g.x - s * 0.7, g.y)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(100, 255, 150, 220))
            nvgFill(nvg)
        end
    end
end

-- ============================================================================
-- 房间区域绘制
-- ============================================================================

--- 绘制房间特殊区域（恢复/撤离）
function Renderer.DrawRoomZone(nvg, gameState)
    if not gameState then return end
    local roomType = gameState.currentRoomType
    if roomType == "recovery" then
        Renderer._DrawRecoveryZone(nvg, gameState)
    elseif roomType == "evacuation" then
        Renderer._DrawEvacuationZone(nvg, gameState)
    end
end

--- 绘制恢复区域（温泉 — 暖色光圈 + 涟漪效果）
function Renderer._DrawRecoveryZone(nvg, gameState)
    local zCfg = Config.ROOM_TYPES.recovery.zone
    local cx = Config.ROOM_WIDTH / 2
    local cy = Config.ROOM_HEIGHT / 2
    local r = zCfg.radius

    -- 外层光晕
    local gc = zCfg.glowColor
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r + 12)
    nvgFillColor(nvg, nvgRGBA(gc[1], gc[2], gc[3], gc[4]))
    nvgFill(nvg)

    -- 半透明填充
    local fc = zCfg.fillColor
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgFillColor(nvg, nvgRGBA(fc[1], fc[2], fc[3], fc[4]))
    nvgFill(nvg)

    -- 边框
    local bc = zCfg.borderColor
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 已使用标记
    if gameState.recoveryUsed then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, 2 + 16) -- CENTER|MIDDLE
        nvgFillColor(nvg, nvgRGBA(200, 200, 200, 150))
        nvgText(nvg, cx, cy, "已恢复")
    else
        -- 温泉 ~ 符号
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, 2 + 16)
        nvgFillColor(nvg, nvgRGBA(255, 200, 100, 180))
        nvgText(nvg, cx, cy, "♨")
    end
end

--- 绘制撤离区域（蓝色虚线圆 + 脉冲效果）
function Renderer._DrawEvacuationZone(nvg, gameState)
    local zCfg = Config.ROOM_TYPES.evacuation.zone
    local cx = Config.ROOM_WIDTH / 2
    local cy = Config.ROOM_HEIGHT / 2
    local r = zCfg.radius

    -- 半透明填充
    local fc = zCfg.fillColor
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, r)
    nvgFillColor(nvg, nvgRGBA(fc[1], fc[2], fc[3], fc[4]))
    nvgFill(nvg)

    -- 虚线圆边框（用多段弧线模拟）
    local bc = zCfg.borderColor
    local dashLen = zCfg.dashLength
    local dashGap = zCfg.dashGap
    local circumference = 2 * math.pi * r
    local segTotal = dashLen + dashGap
    local segCount = math.floor(circumference / segTotal)
    local dashAngle = (dashLen / circumference) * 2 * math.pi

    nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(nvg, 2)
    for i = 0, segCount - 1 do
        local startAngle = (i * segTotal / circumference) * 2 * math.pi
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy, r, startAngle, startAngle + dashAngle, 1)  -- NVG_CW
        nvgStroke(nvg)
    end

    -- 进入区域时脉冲外圈
    if gameState.evacuationActive then
        local pulse = math.sin(gameState.evacuationTimer * 4) * 0.4 + 0.6
        local pulseR = r + 6 * pulse
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy, pulseR)
        nvgStrokeColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], math.floor(pulse * 100)))
        nvgStrokeWidth(nvg, 1.5)
        nvgStroke(nvg)
    end

    -- 中心图标
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 18)
    nvgTextAlign(nvg, 2 + 16)
    if gameState.evacuationActive then
        nvgFillColor(nvg, nvgRGBA(80, 220, 255, 220))
    else
        nvgFillColor(nvg, nvgRGBA(80, 200, 255, 120))
    end
    nvgText(nvg, cx, cy, "▲ EXIT")
end

--- 绘制撤离倒计时（HUD 层，在游戏世界坐标上方大字显示）
---@param nvg userdata
---@param gameState table
---@param screenW number 屏幕逻辑宽度
function Renderer.DrawEvacuationCountdown(nvg, gameState, screenW)
    if not gameState then return end
    if gameState.currentRoomType ~= "evacuation" then return end
    if not gameState.evacuationActive then return end

    local secs = math.ceil(gameState.evacuationTimer)
    local text = tostring(secs)

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 72)
    nvgTextAlign(nvg, 2 + 16) -- CENTER|MIDDLE
    -- 阴影
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 150))
    nvgText(nvg, screenW / 2 + 2, 62, text)
    -- 主字
    local urgency = (secs <= 3) and 1 or 0
    local r = 80 + urgency * 175
    local g = 220 - urgency * 180
    local b = 255 - urgency * 200
    nvgFillColor(nvg, nvgRGBA(r, g, b, 255))
    nvgText(nvg, screenW / 2, 60, text)
end

-- ============================================================================
-- 门绘制 + 图标
-- ============================================================================

--- 绘制通关后出现的门（类型颜色 + 图标）
function Renderer.DrawDoors(nvg, doors)
    if not doors or #doors == 0 then return end
    local dc = Config.DOOR

    for _, door in ipairs(doors) do
        local style = Config.DOOR_STYLES[door.type] or Config.DOOR_STYLES.combat
        nvgSave(nvg)
        nvgTranslate(nvg, door.x, door.y)

        -- 外发光圈（脉冲）
        local gc = style.glowColor
        local pulse = math.sin(door.rotation * 3) * 0.3 + 0.7
        local glowR = dc.triggerRadius * pulse
        nvgBeginPath(nvg)
        nvgCircle(nvg, 0, 0, glowR)
        nvgFillColor(nvg, nvgRGBA(gc[1], gc[2], gc[3], gc[4]))
        nvgFill(nvg)

        -- 底圈
        local c = style.color
        nvgBeginPath(nvg)
        nvgCircle(nvg, 0, 0, 14)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 60))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(c[1], c[2], c[3], 200))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 绘制对应图标
        if door.type == "combat" then
            Renderer._DrawIconSwords(nvg, c)
        elseif door.type == "recovery" then
            Renderer._DrawIconHeart(nvg, c)
        elseif door.type == "evacuation" then
            Renderer._DrawIconExit(nvg, c)
        elseif door.type == "back" then
            Renderer._DrawIconBack(nvg, c)
        end

        nvgRestore(nvg)
    end
end

--- 图标：交叉剑（战斗）
function Renderer._DrawIconSwords(nvg, color)
    local s = 8
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgStrokeWidth(nvg, 2)
    -- 左剑 ╲
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, -s, -s)
    nvgLineTo(nvg, s, s)
    nvgStroke(nvg)
    -- 右剑 ╱
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, s, -s)
    nvgLineTo(nvg, -s, s)
    nvgStroke(nvg)
    -- 交叉点小圆
    nvgBeginPath(nvg)
    nvgCircle(nvg, 0, 0, 2)
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgFill(nvg)
end

--- 图标：爱心（恢复）
function Renderer._DrawIconHeart(nvg, color)
    nvgFillColor(nvg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 20)
    nvgTextAlign(nvg, 2 + 16) -- CENTER|MIDDLE
    nvgText(nvg, 0, 0, "♥")
end

--- 图标：箭头向上（撤离/出口）
function Renderer._DrawIconExit(nvg, color)
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgStrokeWidth(nvg, 2)
    -- 向上箭头
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, 0, 7)
    nvgLineTo(nvg, 0, -7)
    nvgStroke(nvg)
    -- 箭头头部
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, -5, -2)
    nvgLineTo(nvg, 0, -7)
    nvgLineTo(nvg, 5, -2)
    nvgStroke(nvg)
end

--- 图标：回退箭头（返回上一房间）
function Renderer._DrawIconBack(nvg, color)
    nvgStrokeColor(nvg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgStrokeWidth(nvg, 2)
    -- 向左弧线箭头
    nvgBeginPath(nvg)
    nvgArc(nvg, 0, 0, 7, -math.pi * 0.8, math.pi * 0.3, 1)
    nvgStroke(nvg)
    -- 箭头头部
    local tipX = 7 * math.cos(-math.pi * 0.8)
    local tipY = 7 * math.sin(-math.pi * 0.8)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, tipX - 4, tipY - 1)
    nvgLineTo(nvg, tipX, tipY)
    nvgLineTo(nvg, tipX + 1, tipY + 4)
    nvgStroke(nvg)
end

--- 绘制粒子效果
function Renderer.DrawParticles(nvg)
    for _, p in ipairs(Particle.GetAll()) do
        local ratio = math.max(0, p.lifetime / p.maxLifetime)
        local alpha = math.floor(ratio * p.color[4])
        if p.text then
            -- 伤害数字
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, p.size)
            nvgTextAlign(nvg, 2 + 16)  -- NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE
            nvgFillColor(nvg, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgText(nvg, p.x, p.y, p.text)
        else
            -- 圆形粒子
            nvgBeginPath(nvg)
            nvgCircle(nvg, p.x, p.y, p.size * ratio)
            nvgFillColor(nvg, nvgRGBA(p.color[1], p.color[2], p.color[3], alpha))
            nvgFill(nvg)
        end
    end
end

--- 绘制宝箱
function Renderer.DrawChest(nvg, chest)
    if not chest or not chest.alive then return end

    local cc = Config.CHEST
    local cx, cy = chest.x, chest.y
    local r = cc.RADIUS

    -- 摇晃偏移
    local shakeOfs = 0
    if chest.shakeTimer > 0 then
        local progress = chest.shakeTimer / cc.SHAKE_DURATION  -- 1→0
        local wave = math.sin(chest.shakeTimer * cc.SHAKE_FREQUENCY * math.pi * 2)
        shakeOfs = wave * cc.SHAKE_INTENSITY * progress
    end

    nvgSave(nvg)
    nvgTranslate(nvg, cx + shakeOfs, cy)

    -- 检测范围光环（解锁后显示金色光晕）
    if not chest.locked then
        local gc = cc.GLOW_COLOR
        nvgBeginPath(nvg)
        nvgCircle(nvg, 0, 0, cc.DETECT_RADIUS)
        nvgFillColor(nvg, nvgRGBA(gc[1], gc[2], gc[3], gc[4]))
        nvgFill(nvg)
    end

    -- 箱体（圆角矩形）
    local bodyW = r * 2
    local bodyH = r * 1.4
    local bc = cc.BODY_COLOR
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, -bodyW / 2, -bodyH / 2 + 2, bodyW, bodyH, 3)
    nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(120, 80, 20, 255))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 箱盖（上半部分圆角矩形）
    local lidH = bodyH * 0.35
    local lc = cc.LID_COLOR
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, -bodyW / 2, -bodyH / 2 - lidH + 4, bodyW, lidH, 3)
    nvgFillColor(nvg, nvgRGBA(lc[1], lc[2], lc[3], lc[4]))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(140, 100, 30, 255))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 锁/装饰（中心小矩形）
    local lockSize = 6
    if chest.locked then
        -- 锁定：灰色锁
        local kc = cc.LOCK_COLOR
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, -lockSize / 2, -lockSize / 2, lockSize, lockSize, 1)
        nvgFillColor(nvg, nvgRGBA(kc[1], kc[2], kc[3], kc[4]))
        nvgFill(nvg)
        -- 锁孔
        nvgBeginPath(nvg)
        nvgCircle(nvg, 0, -1, 1.5)
        nvgFillColor(nvg, nvgRGBA(60, 60, 70, 255))
        nvgFill(nvg)
    else
        -- 解锁：金色装饰
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, -lockSize / 2, -lockSize / 2, lockSize, lockSize, 1)
        nvgFillColor(nvg, nvgRGBA(255, 220, 80, 255))
        nvgFill(nvg)
    end

    nvgRestore(nvg)
end

return Renderer
