-- ============================================================================
-- EnemySpawner.lua - 波次管理
-- ============================================================================

local Config = require("Config")
local Enemy = require("Enemy")

local EnemySpawner = {}

--- 初始化生成器
function EnemySpawner.Init()
    EnemySpawner.enemies = {}         -- 活着的敌人列表
    EnemySpawner.waveIndex = 1        -- 当前波次索引
    EnemySpawner.waveState = "waiting" -- waiting / warning / spawning / fighting / done
    EnemySpawner.stateTimer = 0
    EnemySpawner.spawnQueue = {}      -- 待生成的敌人队列
    EnemySpawner.spawnTimer = 0
    EnemySpawner.warnings = {}        -- 预警点 { x, y, timer }
    EnemySpawner.totalKillsInWave = 0
    EnemySpawner.totalEnemiesInWave = 0
    -- 开始第一波的等待
    EnemySpawner.stateTimer = 1.0     -- 开局1秒后开始预警
end

--- 更新波次系统
---@param dt number
function EnemySpawner.Update(dt)
    local state = EnemySpawner.waveState

    if state == "waiting" then
        -- 波次间等待
        EnemySpawner.stateTimer = EnemySpawner.stateTimer - dt
        if EnemySpawner.stateTimer <= 0 then
            EnemySpawner._StartWarning()
        end

    elseif state == "warning" then
        -- 预警阶段：显示生成点闪烁
        EnemySpawner.stateTimer = EnemySpawner.stateTimer - dt
        -- 更新预警点的计时
        for _, w in ipairs(EnemySpawner.warnings) do
            w.timer = w.timer + dt
        end
        if EnemySpawner.stateTimer <= 0 then
            EnemySpawner._StartSpawning()
        end

    elseif state == "spawning" then
        -- 逐个生成敌人
        EnemySpawner.spawnTimer = EnemySpawner.spawnTimer - dt
        if EnemySpawner.spawnTimer <= 0 and #EnemySpawner.spawnQueue > 0 then
            local info = table.remove(EnemySpawner.spawnQueue, 1)
            local enemy = Enemy.new(info.type, info.x, info.y)
            table.insert(EnemySpawner.enemies, enemy)
            local wave = Config.WAVES[EnemySpawner.waveIndex]
            EnemySpawner.spawnTimer = wave and wave.spawnInterval or 0.3
        end
        if #EnemySpawner.spawnQueue == 0 then
            EnemySpawner.waveState = "fighting"
        end

    elseif state == "fighting" then
        -- 等待所有敌人被击杀
        local aliveCount = 0
        for _, e in ipairs(EnemySpawner.enemies) do
            if e.alive then aliveCount = aliveCount + 1 end
        end
        if aliveCount == 0 then
            -- 当前波次清完
            EnemySpawner._CleanDead()
            if EnemySpawner.waveIndex >= #Config.WAVES then
                EnemySpawner.waveState = "done"
            else
                EnemySpawner.waveIndex = EnemySpawner.waveIndex + 1
                EnemySpawner.waveState = "waiting"
                EnemySpawner.stateTimer = Config.WAVE_INTERVAL
            end
        end

    elseif state == "done" then
        -- 所有波次完成
    end
end

--- 开始预警
function EnemySpawner._StartWarning()
    local wave = Config.WAVES[EnemySpawner.waveIndex]
    if not wave then
        EnemySpawner.waveState = "done"
        return
    end

    EnemySpawner.warnings = {}
    EnemySpawner.spawnQueue = {}
    EnemySpawner.totalEnemiesInWave = 0

    -- 生成所有敌人的预警点和生成队列
    for _, group in ipairs(wave.enemies) do
        for i = 1, group.count do
            local x, y = EnemySpawner._RandomSpawnPos()
            table.insert(EnemySpawner.warnings, { x = x, y = y, timer = 0 })
            table.insert(EnemySpawner.spawnQueue, { type = group.type, x = x, y = y })
            EnemySpawner.totalEnemiesInWave = EnemySpawner.totalEnemiesInWave + 1
        end
    end

    EnemySpawner.waveState = "warning"
    EnemySpawner.stateTimer = Config.WAVE_WARN_TIME
end

--- 预警结束，开始生成
function EnemySpawner._StartSpawning()
    EnemySpawner.warnings = {}  -- 清除预警显示
    EnemySpawner.waveState = "spawning"
    EnemySpawner.spawnTimer = 0  -- 立即生成第一个
end

--- 随机生成点（房间边缘）
---@return number, number
function EnemySpawner._RandomSpawnPos()
    local margin = 30
    local side = math.random(1, 4)
    local x, y
    if side == 1 then -- 上
        x = math.random(margin, Config.ROOM_WIDTH - margin)
        y = margin
    elseif side == 2 then -- 下
        x = math.random(margin, Config.ROOM_WIDTH - margin)
        y = Config.ROOM_HEIGHT - margin
    elseif side == 3 then -- 左
        x = margin
        y = math.random(margin, Config.ROOM_HEIGHT - margin)
    else -- 右
        x = Config.ROOM_WIDTH - margin
        y = math.random(margin, Config.ROOM_HEIGHT - margin)
    end
    return x, y
end

--- 清除已死亡的敌人
function EnemySpawner._CleanDead()
    local alive = {}
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive then table.insert(alive, e) end
    end
    EnemySpawner.enemies = alive
end

--- 更新所有敌人的移动和 AI
---@param dt number
---@param targetX number 玩家x
---@param targetY number 玩家y
---@return table 敌人射击信息列表 {{x,y,vx,vy,damage,radius,lifetime}, ...}
function EnemySpawner.UpdateEnemies(dt, targetX, targetY)
    local shots = {}
    for _, e in ipairs(EnemySpawner.enemies) do
        if e.alive then
            local shot = e:Update(dt, targetX, targetY)
            if shot then
                table.insert(shots, shot)
            end
        end
    end
    return shots
end

--- 获取当前波次/总波次信息
---@return number, number
function EnemySpawner.GetWaveInfo()
    return EnemySpawner.waveIndex, #Config.WAVES
end

--- 是否所有波次完成
---@return boolean
function EnemySpawner.IsAllDone()
    return EnemySpawner.waveState == "done"
end

return EnemySpawner
