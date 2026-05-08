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
        orbitRadius = 30,       -- 围绕玩家的距离（玩家半径+此值）
        attackInterval = 1.2,   -- 攻击间隔（秒）
        lungeSpeed = 320,       -- 冲顶速度
        lungeDuration = 0.10,   -- 冲顶单程时长（秒），来回共 0.20s
    },
    mob_shooter = {
        attackRange = 200,      -- 攻击距离：进入此范围才开火
        fleeRange = 80,         -- 逃离距离：小于此值则逃跑
        fleeSpeed = 1.5,        -- 逃跑速度倍率
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
        cooldown = 1.0, damage = 12,
        slashLength = 55,    -- 长条攻击长度（从玩家向外延伸）
        slashWidth = 24,     -- 长条攻击宽度
        detectRange = 70,    -- 索敌范围
        sweepDuration = 0.2, -- 特效持续时间
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

-- 门（房间通关后出现）
Config.DOOR = {
    count = 3,              -- 每次生成门数量
    width = 28,             -- 门的宽度（绘制用）
    height = 8,             -- 门的厚度（绘制用）
    rotateSpeed = 2.0,      -- 旋转速度（弧度/秒）
    triggerRadius = 22,     -- 玩家碰撞触发半径
    color = { 120, 200, 255, 255 },
    glowColor = { 80, 160, 255, 60 },
}

-- 宝箱
Config.CHEST = {
    RADIUS = 16,              -- 箱体视觉半径
    DETECT_RADIUS = 50,       -- 玩家检测范围
    MARGIN = 60,              -- 距墙最小距离（生成位置）
    ITEM_COUNT = 5,           -- 随机生成物品数
    -- 视觉颜色
    BODY_COLOR  = { 180, 130, 50, 255 },
    LID_COLOR   = { 200, 150, 60, 255 },
    LOCK_COLOR  = { 140, 140, 150, 255 },
    GLOW_COLOR  = { 255, 220, 80, 40 },
    -- 摇晃动画（锁定状态，玩家进入范围时触发）
    SHAKE_DURATION  = 0.4,
    SHAKE_INTENSITY = 3,
    SHAKE_FREQUENCY = 24,
    SHAKE_COOLDOWN  = 1.2,
}

-- ============================================================================
-- 房间类型
-- ============================================================================
Config.ROOM_TYPES = {
    combat = {
        doorCount = 3,
        hasEnemies = true,
        hasChest = true,
        doorsOnEntry = false,       -- 通关后才出门
    },
    recovery = {
        doorCount = 2,
        hasEnemies = false,
        hasChest = false,
        doorsOnEntry = true,        -- 进入即出门
        zone = {
            radius = 60,
            healPercent = 0.30,
            fillColor   = { 255, 140, 60, 30 },
            borderColor = { 255, 180, 80, 120 },
            glowColor   = { 255, 120, 40, 20 },
        },
    },
    evacuation = {
        doorCount = 1,              -- 仅 back 门
        hasEnemies = false,
        hasChest = false,
        doorsOnEntry = true,
        zone = {
            radius = 55,
            countdownTime = 10.0,
            fillColor   = { 80, 200, 255, 20 },
            borderColor = { 80, 220, 255, 150 },
            dashLength  = 8,
            dashGap     = 5,
        },
    },
}

-- 门的视觉样式（按目标房间类型着色）
Config.DOOR_STYLES = {
    combat     = { color = { 255, 80, 60, 255 },   glowColor = { 255, 60, 40, 50 }  },
    recovery   = { color = { 80, 255, 120, 255 },  glowColor = { 60, 255, 100, 50 } },
    evacuation = { color = { 80, 200, 255, 255 },  glowColor = { 60, 180, 255, 50 } },
    back       = { color = { 200, 200, 200, 255 }, glowColor = { 180, 180, 180, 50 } },
}

-- 战斗房门的随机类型概率
Config.DOOR_GENERATION = {
    recoveryChance = 0.25,          -- 恢复房门概率
    evacuationMinDepth = 5,         -- 撤离门最低层数
    evacuationChance = 0.15,        -- 撤离房门概率
}

-- 房间过渡
Config.TRANSITION_TIME = 0.3  -- 过渡动画时长（秒）

-- 背景颜色
Config.BG_COLOR = { 22, 22, 35, 255 }
Config.BG_GRID_COLOR = { 35, 35, 50, 255 }
Config.ROOM_BORDER_COLOR = { 60, 60, 90, 255 }

return Config
