-- ============================================================================
-- Config.lua - 游戏配置常量
-- ============================================================================

local Config = {}

-- 房间/世界尺寸（虚拟像素）
Config.ROOM_WIDTH = 500
Config.ROOM_HEIGHT = 700

-- 玩家
Config.PLAYER_SPEED = 180        -- 像素/秒
Config.PLAYER_HP = 100
Config.PLAYER_RADIUS = 14
Config.PLAYER_INVULN_TIME = 0.5  -- 受伤后无敌时间（秒）
Config.PLAYER_COLOR = { 80, 220, 255, 255 }

-- 经验
Config.XP_PICKUP_RADIUS = 28
Config.XP_GEM_RADIUS = 5
Config.XP_TABLE = { 5, 10, 18, 28, 40, 55, 73, 95, 120, 150 }

-- 敌人类型
Config.ENEMY_TYPES = {
    bat = {
        speed = 70, hp = 3, radius = 10, damage = 8,
        color = { 160, 80, 200, 255 }, xp = 1,
    },
    slime = {
        speed = 40, hp = 8, radius = 14, damage = 12,
        color = { 80, 200, 80, 255 }, xp = 2,
    },
    skull = {
        speed = 55, hp = 15, radius = 12, damage = 18,
        color = { 220, 220, 220, 255 }, xp = 3,
    },
}

-- 波次配置（单房间，约1分钟）
Config.WAVES = {
    {
        enemies = { { type = "bat", count = 5 } },
        spawnInterval = 0.3,
    },
    {
        enemies = { { type = "bat", count = 4 }, { type = "slime", count = 3 } },
        spawnInterval = 0.3,
    },
    {
        enemies = { { type = "slime", count = 5 }, { type = "bat", count = 5 } },
        spawnInterval = 0.25,
    },
    {
        enemies = { { type = "skull", count = 3 }, { type = "slime", count = 4 } },
        spawnInterval = 0.25,
    },
    {
        enemies = { { type = "skull", count = 5 }, { type = "bat", count = 6 }, { type = "slime", count = 4 } },
        spawnInterval = 0.2,
    },
}
Config.WAVE_WARN_TIME = 1.0      -- 预警时间（秒）
Config.WAVE_INTERVAL = 2.0       -- 波次间等待时间（秒）

-- 武器
Config.WEAPONS = {
    sword = {
        cooldown = 1.2, damage = 12,
        sweepRadius = 50, sweepAngle = 120,  -- 度
        sweepDuration = 0.25,
    },
    knife = {
        cooldown = 0.8, damage = 6,
        speed = 350, radius = 5, pierce = 2, lifetime = 1.5,
    },
    wand = {
        cooldown = 1.5, damage = 8,
        speed = 250, radius = 6, lifetime = 2.0,
        explosionRadius = 40, explosionDamage = 10,
    },
}

-- 背景颜色
Config.BG_COLOR = { 22, 22, 35, 255 }
Config.BG_GRID_COLOR = { 35, 35, 50, 255 }
Config.ROOM_BORDER_COLOR = { 60, 60, 90, 255 }

return Config
