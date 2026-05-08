# SpookyJourney 开发进度

> 供 AI 恢复上下文用，人类也可阅读。

## 项目概述

Roguelike 地牢探索游戏，NanoVG 2D 渲染，虚拟摇杆操控。
玩家在单房间内自动攻击敌人，击杀获取经验升级，通关后选门进入下一房间。

## 当前架构

```
scripts/
├── main.lua          # 入口，UI 树组装，HandleUpdate 状态分发
├── Config.lua        # 全局配置（房间尺寸、武器参数、敌人AI、房间类型等）
├── GameState.lua     # 状态机核心（playing/levelup/room_clear/transition/gameover/victory）
├── GameCanvas.lua    # NanoVG 渲染 Widget，世界坐标变换
├── Renderer.lua      # 所有 NanoVG 绘制函数（背景/玩家/敌人/门/区域/粒子/宝箱等）
├── HUD.lua           # 顶部 HUD（HP条、等级、层数、击杀数）
├── Player.lua        # 玩家状态（移动、HP、经验、升级）
├── EnemySpawner.lua  # 波次系统 + 敌人 AI（mob_common/mob_shooter/mob_clash）
├── Weapon.lua        # 武器系统（knife/sword/wand，自动攻击+投射物）
├── Collision.lua     # 碰撞检测工具（CircleCircle/CircleInSlash/Distance）
├── Particle.lua      # 粒子系统（伤害数字/死亡烟雾/经验闪光/治疗数字）
├── Upgrade.lua       # Roguelike 升级项（随机3选1）
├── LevelUpUI.lua     # 升级选择弹窗
├── ItemDB.lua        # 物品原型数据库（18种物品×6品质）
├── Inventory.lua     # 背包数据逻辑（增删查改/拖拽/拆分合并）
└── InventoryUI.lua   # 背包全屏 UI（网格+拖拽+品质边框）
```

## 已完成功能

### 核心循环
- [x] 玩家移动（虚拟摇杆 + WASD）
- [x] 3种敌人 AI：mob_common（追踪近战）、mob_shooter（远程射击）、mob_clash（蓄力冲锋）
- [x] 波次系统（5波，间隔出怪）
- [x] 经验系统（击杀掉落经验球→拾取→升级→3选1强化）

### 武器系统
- [x] knife：环绕飞刀，自动射击最近敌人
- [x] sword：近战剑，范围内索敌→长条矩形判定→闪白剑气特效，初始1s CD
- [x] wand：火球法杖，爆炸溅射
- [x] 升级项：攻击力/攻速/数量/范围等

### 房间推进
- [x] 通关生成门→选门→过渡→进入下一房间
- [x] depth 层数递增
- [x] 通关后经验球自动吸附

### 房间类型（最新）
- [x] **战斗房**（combat）：3门，通关后出现，第1门固定combat，其余概率随机
- [x] **恢复房**（recovery）：中心温泉♨，一次性回30%HP，进入即出2个combat门
- [x] **撤离房**（evacuation）：蓝色虚线区域，站10s倒计时完成→victory，仅1个back门
- [x] **back 门**：进入新战斗房但不增加 depth
- [x] 门图标：交叉剑⚔ / 爱心♥ / 箭头↑ / 回退弧线↶
- [x] 门类型概率：recovery 25%，evacuation 15%（depth≥5）
- [x] victory 状态：显示胜利画面，点击重开

### 宝箱系统
- [x] 房间随机生成宝箱，锁定状态摇晃提示
- [x] 通关后解锁，进入范围可开启
- [x] 宝箱背包：随机物品，可拖拽到玩家背包
- [x] 玩家背包 UI：全屏覆盖，网格布局，品质边框

## 关键设计决策

1. **"回到上一个房间" 简化为 back 门进新战斗房不加 depth**，避免保存/恢复复杂房间状态
2. **非战斗房在 Update() 顶部用 early return 隔离**，不影响原有战斗代码
3. **门数量由 ROOM_TYPES[type].doorCount 控制**，不再用全局 Config.DOOR.count
4. **撤离倒计时在 GameCanvas.Render 末尾用屏幕坐标绘制**（HUD层），不受世界变换影响

## 待开发 / 可能的下一步

- [ ] 房间类型视觉区分（背景色/氛围差异）
- [ ] 更多房间类型（商店、Boss房、事件房）
- [ ] 宝箱物品实际装备效果
- [ ] 小地图 / 房间探索路径记录
- [ ] 音效系统
- [ ] 敌人种类扩展
- [ ] 难度曲线（随 depth 增加敌人强度）
- [ ] 存档 / 持久化

## 配置速查

| 配置项 | 位置 | 说明 |
|--------|------|------|
| 房间尺寸 | `Config.ROOM_WIDTH/HEIGHT` | 500×700 虚拟像素 |
| 房间类型 | `Config.ROOM_TYPES` | combat/recovery/evacuation |
| 门样式 | `Config.DOOR_STYLES` | 4种颜色（combat红/recovery绿/evacuation蓝/back灰）|
| 门概率 | `Config.DOOR_GENERATION` | recovery 25%, evacuation 15%(depth≥5) |
| 武器参数 | `Config.WEAPONS` | knife/sword/wand 各自参数 |
| 敌人AI | `Config.ENEMY_AI` | mob_common/mob_shooter/mob_clash |
| 波次 | `Config.WAVES` | 5波配置 |

---
*最后更新：2026-05-08*
