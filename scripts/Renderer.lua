-- ============================================================================
-- Renderer.lua - NanoVG 绘制函数（游戏世界坐标系）
-- ============================================================================

local Config = require("Config")
local Player = require("Player")
local EnemySpawner = require("EnemySpawner")
local Weapon = require("Weapon")
local Particle = require("Particle")

local Renderer = {}

--- 绘制所有游戏元素（在游戏世界坐标系下调用）
---@param nvg userdata NanoVG 上下文
---@param gameState table GameState 模块
function Renderer.DrawAll(nvg, gameState)
    Renderer.DrawBackground(nvg)
    Renderer.DrawWarnings(nvg)
    Renderer.DrawXPGems(nvg, gameState and gameState.xpGems)
    Renderer.DrawEnemies(nvg)
    Renderer.DrawEnemyBullets(nvg, gameState and gameState.enemyBullets)
    Renderer.DrawProjectiles(nvg)
    Renderer.DrawWeaponEffects(nvg)
    Renderer.DrawPlayer(nvg)
    Renderer.DrawParticles(nvg)
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
        else
            -- 剑挥砍扇形（闪白）
            local halfAngle = math.rad(e.sweepAngle / 2)
            local startAngle = e.angle - halfAngle
            local endAngle = e.angle + halfAngle
            -- 白色闪光强度随时间衰减
            local flash = math.floor(math.max(0, (e.timer / e.maxTime)) * 220)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, e.x, e.y)
            nvgArc(nvg, e.x, e.y, e.radius, startAngle, endAngle, 2) -- NVG_CCW=2
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, flash))
            nvgFill(nvg)
            -- 扇形边缘描边
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, e.x, e.y)
            nvgArc(nvg, e.x, e.y, e.radius, startAngle, endAngle, 2)
            nvgClosePath(nvg)
            nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, flash))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
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

return Renderer
