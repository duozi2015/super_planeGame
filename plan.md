# 实施计划 (plan.md) — 3.super_plane

> 承接 `design.md`（已签字：硬核气动 + 游戏化作战）
> 方法论：Superpowers 7 阶段；本文件即 V3 Implementation Planning 产物
> 原则：TDD（先写失败测试）、YAGNI、DRY；任务粒度 2–5 分钟
>
> **路径修订（2026-08-17）**：已与本地另一 Godot 项目合并，**项目根 = `3.super_plane/` 根目录本身**（非 `project/` 子目录）。下述所有 `project/` 前缀路径一律按根目录相对解读（`res://...` 已相对根）。编辑器+MCP 均连根目录项目。

---

## 0. 测试与运行基线（先建立，所有任务依赖它）

- **项目根**：`3.super_plane/`（根目录即 Godot 项目；含 `project.godot`、`addons/godot_mcp`、`scenes/`、`scripts/`）
- **本地 Godot**：`/Applications/Godot.app`（4.7.1，GUI 编辑器）+ CLI：`/Applications/Godot.app/Contents/MacOS/Godot`
- **无头测试**（不进编辑器就能跑 TDD）：
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd
  ```
  退出码 0=全绿。所有 `tests/test_*.gd` 里的 `func test_xxx()` 都会被收集执行。
- **运行游戏**：编辑器 F5；或 `Godot --path . --scene res://scenes/main.tscn`
- **MCP 接管后**：场景编辑走 `mcp__godot__*` 工具（live-tree + undo)，`project.godot` 由编辑器维护，不手改。

---

## 1. 里程碑总览

| 里程碑 | 内容 | 条件（DoD） |
|---|---|---|
| **M1（本轮冲刺）** | 测试基建 + 飞行模型-核心可飞（无画面/占位+HUD数字） | 无头测试全绿；编辑器里能飞、不炸、有 HUD 读数 |
| M2 | 可视化：占位模型+追尾相机+HUD 完整 | 视觉可玩、相机顺滑 |
| M3 | 战斗：机炮/导弹/干扰弹 + 敌机 AI + 损伤 | 能锁定击落敌机 |
| M4 | 任务流程：简报/目标/结算 + 菜单 | 3 关可完整通关 |
| M5 | 真实模型替换、粒子、音效、画质档、平衡 | 有"成品质感" |
| M6 | 导出与手感 QA | 可分发产物 |

**本轮范围：M1。** 任务 T1–T10 如下。

---

## 2. M1 任务清单（TDD 粒度）

### T1 — 无头测试基建
- **文件**：`project/tests/run_tests.gd`（SceneTree）、`project/tests/test_harness.gd`（断言工具，RefCounted）
- **代码**（test_harness.gd 核心）：
  ```gdscript
  class_name TestHarness
  static func assert_true(cond: bool, msg: String) -> void:
      if not cond: printerr("FAIL: " + msg); push_error("assert: " + msg)
  static func assert_almost_eq(a: float, b: float, eps: float, msg: String) -> void:
      if absf(a - b) > eps: printerr("FAIL: %s (got %.4f, want %.4f±%.4f)" % [msg, a, b, eps])
  ```
- **run_tests.gd 骨架**：`extends SceneTree`，`_initialize()` 里扫 `res://tests/` 下 `*.gd` 文件的类并逐个调用 `test_*()`（用 `ClassDB`/`load`），计数 PASS/FAIL，exit(0/1)。
- **验证**：跑无头命令，期望"0 测试通过"（红→先有可跑框架）；加一个必过 smokes 测试变绿。

### T2 — 模型状态与基本积分（Red→Green）
- **文件**：`project/tests/test_flight_state.gd`、`project/scripts/core/flight_state.gd`
- **flight_state.gd**（RefCounted，纯逻辑无节点依赖）：
  ```gdscript
  class_name FlightState extends RefCounted
  var position: Vector3
  var velocity: Vector3
  var basis: Basis          # 姿态（俯仰基准）
  var angular_velocity: Vector3
  var throttle: float = 0.0 # 0..1
  var afterburner: bool = false
  func step(dt: float, accel_world: Vector3) -> void:
      velocity += accel_world * dt
      position += velocity * dt
  ```
- **先写测试**：给恒定加速度 100ms、1s，断言 `velocity`/`position` 按解析解变化（误差 < 1e-3）。
- **验证**：无头测试全绿。

### T3 — 大气模型（ISA 简化）
- **文件**：`project/tests/test_atmosphere.gd`、`project/scripts/core/atmosphere.gd`
- **实现**：`static func density(alt_m: float) -> float` 用指数律 `ρ = 1.225 * exp(-alt/8500.0)`；`sound_speed()`、`q(alt,v)`（动压 `0.5*ρ*v²`）一并给出。
- **测试**：海平面≈1.225；height=8500 时 ≈0.4506；q 随 v² 增长。
- **验证**：全绿。

### T4 — 气动系数（升/阻/侧向 + 失速）
- **文件**：`project/tests/test_aero_coeffs.gd`、`project/scripts/core/aero.gd`
- **实现**（`Aero` 静态/纯函数）：
  - `static func cl(alpha: float, cl_max, alpha_lin, stall) -> float`：线性区 `2π·alpha`（截到 cl_max）→ 失速后按高斯衰减到 0.25·cl_max。
  - `static func cd(alpha, cl, cd0, k) -> float`：`cd0 + k*cl^2`（k=1/(π·e·AR)）。
  - `static func cy(beta: float) -> float`：线性 `-0.8*beta`（β 弧度）。
  - 提供 `const PARAMS`（质量/翼面积/推力/限制等，常量表集中一处 → 后续平衡就改这一处）。
- **测试**：alpha=0 → CL≈0 且 CD≈cd0；alpha 增大 CL 增；beta 符号正确；失速后 CL 显著下降。
- **验证**：全绿。

### T5 — 力与力矩组装（核心：每步算合力→积分）
- **文件**：`project/tests/test_forces.gd`、`project/scripts/core/flight_model.gd`
- **flight_model.gd**（RefCounted，持有 FlightState，包装 T3/T4）：
  ```gdscript
  func step(inputs: ControlInputs, dt: float) -> void:
      # 气流角：从 body 速度算 α、β
      # 气动力（body 系）+ 推力 + 重力（世界系）→ 世界合力
      # 力矩（body 系）+ 阻尼 → 角加速度 → 积分姿态
      # 更新 state；更新 load_factor / stall / blackout 标志
  ```
  - 姿态积分用 `basis.rotated(...)` 或四元数，办理归一化；转动惯量取近似对角（Ix<Iy<Iz 数量级合理）。
  - 钩子：`get_debug_snapshot() -> Dictionary`（α/β/G/迎角/动压）供 HUD 与调试用。
- **先写测试**：① 零输入+水平姿态，10s 内位置速度不发散（稳定性冒烟）。② 推力=重力、水平巡航条件接近平衡（升力≈重力，误差<10%）。③ 松开油门自由落体：加速度≈g。
- **验证**：全绿。这是本里程碑的**关键可测对象**。

### T6 — 飞控输入映射（input actions）
- **文件**：`project/project.godot` `[input]` 段（用 `--headless --script` 生成或编辑可用 `mcp` 后由编辑器写；**手改前先备份**）
- **动作清单**（玩家默认键，可重绑）：
  | action | 键 | 手柄轴 |
  |---|---|---|
  | `pitch_up` / `pitch_down` | ↑ / ↓ | 左摇杆 Y |
  | `roll_left` / `roll_right` | ← / → 或 A / D | 左摇杆 X |
  | `yaw_left` / `yaw_right` | Q / E | 右摇杆 X |
  | `throttle_up` / `throttle_down` | W / S 或 F / R | 扳机 |
  | `afterburner` | Shift | — |
  - 手柄与键位并存；GDScript 端用 `Input.get_axis()` 归一成 `ControlInputs`（pitch/roll/yaw ±1，throttle 0..1）。
- **验证**：`InputMap` 存在且 axis 返回期望范围。

### T7 — 玩家场景 + 飞行控制器
- **文件**：`project/scenes/player/player.tscn`、`project/scripts/player/flight_controller.gd`
- **player.tscn**：`RigidBody3D` + CapsuleCollisionShape3D（占位碰撞）+ MeshInstance3D（BoxMesh 占位）+ 远端`player.gd`。
- **flight_controller.gd**：`_integrate_forces(state: PhysicsDirectBodyState3D)` 内：读 inputs → `flight_model.step(inputs, state.get_step())` → 把 state 的 velocity/orientation 直接写回刚体，或把合力写入施加。**二选一策略**：先采用"每次 tick 直接把模型状态拷回刚体"（Kinematic 手感更可控），物理层只做碰撞。
- **验证**：编辑器 F5 起飞能推油门爬升；数值与 HUD 读数一致。

### T8 — 追尾相机
- **文件**：`project/scripts/camera/chase_cam.gd`、`project/scenes/camera/chase_cam.tscn`
- **实现**：跟随目标 RigidBody3D；`global_position` 用 lerp 平滑，`look_at(target)`；按速度缩放 FOV（慢 60° → 快 90°）；机首前方 look-ahead +2s 锚点。
- **验证**：编辑器里机动时机身不甩出屏幕；FOV 随速平滑变化。

### T9 — HUD（数字版）
- **文件**：`project/scenes/hud/hud.tscn`、`project/scripts/hud/hud.gd`
- **实现**：CanvasLayer + 字号标签组：IAS、高度、航向、G、α、速度矢量（X Y 十字）、节流阀。数据源：`flight_model.get_debug_snapshot()`（信号总线或直接引用）。
- **验证**：编辑器 F5 读数实时、随机动变化正确。

### T10 — 手感初调 + 防炸护栏
- **文件**：`project/scripts/debug/cheat_overlay.gd`（开发开关，显示 α/β/G/能量）、常量表参数微调
- **动作**：把稳定性参数（Cmα、阻尼、惯性）调到"爬升不掉速、急转不过度失速"；验证无头测试仍全绿。
- **验证**：跑 `run_tests.gd` 全绿 + 编辑器试飞 60s 未炸。

---

## 3. 后续里程碑任务（M2–M6 概览，进入前再细化）

### M2 可视化
- 占位网格替换为 CC0 战机模型（下载脚本入 `tools/fetch_assets.sh`，锁定直接下载 URL）
- 追尾相机打磨、机身阴影、环境天空/雾、`WorldEnvironment`

### M3 战斗
- 机炮（射线判定 + 曳光）+ 导弹（锁定框/追踪/脱锁）+ 干扰弹，均走**对象池**
- 敌机 AI：FSM（巡逻→接战→规避→脱离），BOSS 多阶段
- 损伤模型（结构→操控降级）→ HUD 血条/告警

### M4 任务流程
- `scenes/briefing/`、`scenes/debrief/`、任务目标系统（雷达标记+文本）、3 个任务场景、主菜单

### M5 打磨
- 粒子（GPUParticles3D：引擎尾焰/爆炸/弹道）、音量混音、画质档位（高/中/低）、难度参数表

### M6 发布
- 导出为 macOS/Windows(`--export-preset`)，手感 QA 清单（按设计 §4 验收项）

---

## 4. 每任务的验收口径（DoD 模板）

- [ ] 相关 `tests/test_*.gd` 已先写且**先红**（可证明测试有效）
- [ ] 实现后 `run_tests.gd` **全绿**（exit 0）
- [ ] 无新增全局状态/单点耦合（YAGNI：不提前做 M2+ 需求）
- [ ] 常量都集中到一处（`aero.PARAMS` / 配置类），无魔法数字散落
- [ ] 提交信息遵循 `m1/tN: <一句话>`（仅在被要求提交时执行）

---

## 5. 风险与应对

| 风险 | 应对 |
|---|---|
| 手敲 `.tscn`/`.godot` 易错 | 能用编辑器/MCP 的尽量用 MCP 生成；`project.godot.bak` 保留回滚 |
| 硬核飞行参数难调 | T10 专职调参+cheat overlay；参数集中 hot-reload |
| 无头测试覆盖不到场景层 | 场景层用"MCP + 编辑器 F5 人工验证"过审，核心逻辑用无头测试锁死 |
| 模型素材下载源失效 | 计划锁 2 个备用源，`tools/fetch_assets.sh` 做重试 |