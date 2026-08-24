# 3D 空战 · super_plane (Godot 4)

一款基于 **Godot 4（Forward+ / Jolt Physics）** 开发的 **3D 硬核飞行空战**游戏原型。核心卖点是**真实飞行气动**（失速、过载、能量管理）+ **游戏化作战系统**（机炮/导弹/干扰弹、敌机 AI、任务关卡制）。

> 当前状态：**MVP 开发中（里程碑 M1 完成，M2+ 进行中）** — 版本 `v0.0.1-MVPmaking`

---

## 特性

- **硬核飞行模型**：俯仰/横滚/偏航阻尼、推力与加力燃烧室（AFB）、简化升力模型、低速/高攻角**失速**、**G 力限制**、能量管理（高度 ↔ 速度互换）。
- **沉浸式 HUD**：高度、速度（IAS）、航向、G 值、攻角 α、节流阀——全部以仪表数字呈现。
- **武器系统**：机炮（射速/弹药/过热）+ 导弹（锁定 → 发射 → 追击，含脱锁判定）+ 干扰弹（热焰/铝箔，限容量）。
- **敌机 AI**：有限状态机（巡逻 → 接战 → 规避 → 脱离），支持不同难度参数。
- **TDD 化开发**：核心气动/武器逻辑为纯函数（`RefCounted`），无头测试锁死行为。
- **低耦合架构**：气动系数、大气模型、武器等均为独立可测模块；物理层用 `RigidBody3D` + Jolt。

## 技术栈

| 项 | 值 |
|---|---|
| 引擎 | Godot 4.7.1（Forward+） |
| 物理 | Jolt Physics |
| 脚本 | GDScript |
| 素材 | CC0 模型包（Quaternius 等）＋占位几何体 |
| 开发闭环 | Godot MCP（编辑器↔AI 协同） |

## 项目结构

```
├── design.md               设计文档（已签字：硬核气动 + 游戏化作战）
├── plan.md                 实施计划（里程碑 M1–M6，TDD 任务拆分）
├── project.godot           项目配置（输入映射、渲染、物理、MCP 自动加载）
├── scenes/                 场景：main / player / enemy / hud
│   ├── main.tscn           主场景根
│   ├── player.tscn         玩家飞机（RigidBody3D）
│   ├── enemy.tscn          敌机场景
│   └── hud.tscn            HUD（CanvasLayer）
├── scripts/
│   ├── core/               飞行核心（纯逻辑、可无头测试）
│   │   ├── flight_model.gd     力/力矩组装：合力→积分（关键可测对象）
│   │   ├── flight_state.gd     模型状态与基本积分
│   │   ├── aero.gd             气动系数（升/阻/侧向 + 失速）+ 集中参数表
│   │   ├── atmosphere.gd       ISA 简化大气（密度/声速/动压）
│   │   ├── control_inputs.gd   输入归一化结构
│   │   ├── weapon_system.gd    武器子系统（机炮/导弹/干扰弹）
│   │   ├── missile.gd          导弹制导/脱锁
│   │   ├── enemy_ai.gd         FSM 敌机 AI
│   │   └── damage.gd           损伤模型
│   ├── player/             飞行控制器 + 武器接入
│   ├── enemy/              敌机控制器
│   ├── camera/             追尾相机（lerp 平滑、按速度缩放 FOV）
│   ├── hud/                HUD 读数 + 姿态仪表
│   └── environment/        地形构建 / WorldEnvironment
├── tests/                  无头 GDScript 测试（TDD）
└── assets/models/          CC0 模型（player / enemy / props）
```

## 运行

### 测试（无头，TDD 基线）

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --script res://tests/run_tests.gd ++ --no-mcp
```

退出码 `0` = 全绿。`. /tests/test_*.gd` 中所有 `func test_*()` 会被自动收集执行。

当前覆盖：气动系数、大气模型、力/力矩与稳定性、飞行状态积分、攻角/操纵、导弹/干扰弹、敌机 AI、损伤模型、输入映射等（**51 项测试全绿**）。

### 运行游戏

- 编辑器：打开项目按 **F5**。
- 命令行：`Godot --path . --scene res://scenes/main.tscn`

## 默认键位（可在 项目设置 → 输入映射 中重绑）

| 动作 | 键 |
|---|---|
| 俯仰（机头上下） | **W / S** |
| 横滚（左右翻滚） | **A / D** |
| 偏航（左右转向） | **Q / E** |
| 油门加减 | **PageUp / PageDown** |
| 加力燃烧室 | （手柄扳机预留） |

## 里程碑

| 里程碑 | 状态 | 内容 |
|---|---|---|
| **M1** 工程骨架 + 飞行核心 | ✅ 完成 | 测试基建、飞行模型可飞（无头 TDD 全绿）、HUD 数字、追尾相机、输入映射 |
| M2 可视化 | 🚧 进行中 | 占位模型 → CC0 战机模型、相机打磨、环境天空/雾 |
| M3 战斗 | — | 机炮/导弹/干扰弹、敌机 AI、损伤（部分核心已先行） |
| M4 关卡 | — | 简报/目标/结算、主菜单、3 关任务流程 |
| M5 打磨 | — | 粒子、音效、画质档、难度平衡 |
| M6 发布 | — | 导出 macOS/Windows、手感 QA |

详细任务拆解见 [plan.md](plan.md)，设计规格见 [design.md](design.md)。

## 设计要点（节选）

- **架构 `RigidBody3D` + `_integrate_forces()`**：逐帧施加力，飞行核心（`flight_model.gd`）为纯逻辑、可无头测试。
- **气动模型**：按攻角 α 的升力系数曲线（线性区 → 失速后急剧衰减）+ 寄生/诱导阻力 + 阻尼力矩；参数集中在 `aero.PARAMS` 一处，便于调参平衡。
- **能量管理**：俯冲换速、机动掉速，逼玩家管理油门——这是本作"硬核手感"的核心。
- **开发方式**：核心逻辑用无头测试锁死，场景层（相机/UI/手感）用编辑器 + Godot MCP 调试验证。

## License

- 游戏代码：本项目私有/按仓库协议使用。
- 素材：CC0（来源见 `assets/models` 中各模型源包）。



欢迎指导！希望能给颗星！
