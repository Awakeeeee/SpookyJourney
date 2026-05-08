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
            if e.flashTimer > 0 then
                -- 受伤闪白
                nvgBeginPath(nvg)
                nvgCircle(nvg, e.x, e.y, e.radius)
                nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
                nvgFill(nvg)
            else
                local c = e.color
                nvgBeginPath(nvg)
                nvgCircle(nvg, e.x, e.y, e.radius)
                nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], c[4]))
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
