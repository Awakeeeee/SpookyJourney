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

-- 敌人 AI 类型
-- mob_common: 靠近玩家后围绕玩家攻击（圆形）
-- mob_shooter: 保持距离发射子弹（三角形）
-- mob_clash: 蓄力后冲锋（正方形）
Config.ENEMY_AI = {
    mob_common = {
        stopRadius = 28,        -- 停止接近的距离（玩家半径+此值≈围绕距离）
        attackInterval = 0.8,   -- 碰撞攻击间隔
    },
    mob_shooter = {
        preferDist = 150,       -- 理想射击距离
        minDist = 100,          -- 太近会后退
        fireInterval = 1.6,     -- 射击间隔
        bulletSpeed = 200,      -- 子弹速度
        bulletRadius = 4,       -- 子弹碰撞半径
        bulletLifetime = 2.5,   -- 子弹存活时间
    },
    mob_clash = {
        preferDist = 120,       -- 蓄力距离
        chargeDelay = 0.8,      -- 蓄力时间（红色闪烁）
        chargeSpeed = 400,      -- 冲锋速度
        chargeWidth = 24,       -- 冲锋路径宽度（用于预警渲染）
    },
}

-- 敌人类型
Config.ENEMY_TYPES = {
    bat = {
        aiType = "mob_common",
        speed = 70, hp = 3, radius = 10, damage = 8,
        color = { 160, 80, 200, 255 }, xp = 1,
    },
    slime = {
        aiType = "mob_common",
        speed = 40, hp = 8, radius = 14, damage = 12,
        color = { 80, 200, 80, 255 }, xp = 2,
    },
    skull = {
        aiType = "mob_common",
        speed = 55, hp = 15, radius = 12, damage = 18,
        color = { 220, 220, 220, 255 }, xp = 3,
    },
    archer = {
        aiType = "mob_shooter",
        speed = 45, hp = 6, radius = 11, damage = 10,
        color = { 220, 160, 50, 255 }, xp = 2,
    },
    brute = {
        aiType = "mob_clash",
        speed = 35, hp = 20, radius = 14, damage = 25,
        color = { 200, 60, 60, 255 }, xp = 3,
    },
}

-- 波次配置（单房间，约1分钟）
Config.WAVES = {
    {
        enemies = { { type = "bat", count = 5 } },
        spawnInterval = 0.3,
    },
    {
        enemies = { { type = "bat", count = 3 }, { type = "archer", count = 2 } },
        spawnInterval = 0.3,
    },
    {
        enemies = { { type = "slime", count = 4 }, { type = "archer", count = 2 }, { type = "brute", count = 1 } },
        spawnInterval = 0.25,
    },
    {
        enemies = { { type = "skull", count = 3 }, { type = "archer", count = 3 }, { type = "brute", count = 2 } },
        spawnInterval = 0.25,
    },
    {
        enemies = { { type = "skull", count = 4 }, { type = "bat", count = 4 }, { type = "archer", count = 3 }, { type = "brute", count = 2 } },
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
