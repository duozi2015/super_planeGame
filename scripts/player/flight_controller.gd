# res://scripts/player/flight_controller.gd
## T7 — 玩家飞行控制器：读输入 → FlightModel → 写回刚体。
## 挂在 Player 场景根节点（RigidBody3D）上。
## 控制（可在项目设置重绑）：
##   W/S 俯仰 · A/D 横滚 · Q/E 偏航 · ↑/↓ 油门
## 出生即处于配平巡航（低头升重、推力=阻力），手放开能稳高度。

extends RigidBody3D

const FM = preload("res://scripts/core/flight_model.gd")
const CI = preload("res://scripts/core/control_inputs.gd")
const DamageModel = preload("res://scripts/core/damage.gd")

# 配平巡航初始条件（与 T5 测试一致：V=250、α_trim=1.42°、油门 0.326、配平舵 δe=0.081）
const SPAWN_ALT := 2000.0
const SPAWN_ALPHA := 0.02485
const SPAWN_SPEED := 250.0
const SPAWN_THROTTLE := 0.326
const CRUISE_TRIM_DE := 0.081
const RESPAWN_ALT := 2000.0

var model = FM.new()
var damage = DamageModel.new()
var _throttle := SPAWN_THROTTLE
var _snapshot: Dictionary = {}
var _respawn_timer := -1.0

const RESPAWN_DELAY := 2.0

## 玩家视觉模型（GLB），机头需与机体 +Z 对齐；若模型朝 -Z 可在此旋转
const PLAYER_MODEL := "res://assets/models/player/craft_racer.glb"

## 横滚方向开关：true=按下 D 时横滚反向（若手感/D键方向不符可在此翻转）
@export var invert_roll := true

## 模型横向微调（修正横滚观感偏心）：正=向右(+X)，负=向左(-X)
@export var model_x_offset := 0


func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	_build_visual()
	_setup_spawn()


## 加载真实模型替换占位盒（若场景里已手动放模型则跳过）
## 模型默认假设机头朝 -Z（Blender 导出习惯）；机体约定机头 +Z，故绕 Y 转 180°
func _build_visual() -> void:
	if has_node("Model"):
		return
	var scn: PackedScene = load(PLAYER_MODEL)
	if scn == null:
		push_warning("玩家模型加载失败: " + PLAYER_MODEL)
		return
	# 隐藏占位盒，换真实模型
	if has_node("Body"):
		get_node("Body").visible = false
	var inst: Node3D = scn.instantiate()
	inst.name = "Model"
	# 模型 local +Z 已朝向正确方向，无需 180° 翻转（实测翻转后模型几何前向跑到 -Z，
	# 与物理纵轴 +Z 相反，导致横滚时机身沿 Z 反向偏移）
	inst.scale = Vector3(6.0, 6.0, 6.0)          # 放大到更接近战斗机的观感（×3）
	add_child(inst)
	# 几何中心 Y 对齐刚体原点（模型 pivot 偏低）；X 手动微调修正横滚观感偏心
	inst.position = Vector3(model_x_offset, -0.375 * inst.scale.y, 0.0)
	# 机炮挂点：机头两侧 Marker3D，武器脚本从这取真实开火位（跟随模型坐标）
	for side in [-0.55, 0.55]:
		var m3 := Marker3D.new()
		m3.name = "GunMuzzle%s" % ("L" if side < 0 else "R")
		m3.position = Vector3(side, 0.15, 1.9)  # 模型局部系（放大后机头前 2m）
		inst.add_child(m3)


## 运行时加固输入绑定：MCP 写入 project.godot 的按键事件带有 device=16/keycode=0，## 导致动作永远无法与真实键盘（device 0）匹配。这里重建为：
##   device=-1（匹配任意设备）+ keycode 与 physical_keycode 双填。
func _ensure_input_actions() -> void:
	var defs := {
		"pitch_up": KEY_W, "pitch_down": KEY_S,
		"roll_left": KEY_A, "roll_right": KEY_D,
		"yaw_left": KEY_Q, "yaw_right": KEY_E,
		"throttle_up": KEY_UP, "throttle_down": KEY_DOWN,
		# 战斗按键（M3 起用）
		"fire_guns": KEY_SPACE, "lock_target": KEY_L, "fire_missile": KEY_M,
		"deploy_flare": KEY_C, "deploy_chaff": KEY_X,
	}
	for action in defs:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.device = -1
		ev.keycode = defs[action]
		ev.physical_keycode = defs[action]
		InputMap.action_add_event(action, ev)


func _setup_spawn() -> void:
	model.state.position = Vector3(0, SPAWN_ALT, 0)
	model.state.basis = Basis(Vector3.RIGHT, -SPAWN_ALPHA)  # 抬头 1.42°
	model.state.velocity = Vector3(0, 0, SPAWN_SPEED)
	model.state.angular_velocity = Vector3.ZERO
	model.trim_elevator = CRUISE_TRIM_DE  # 配平舵：手放开能稳高度
	global_transform = Transform3D(model.state.basis, model.state.position)
	linear_velocity = model.state.velocity


func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	# 死亡：冻结动作，倒计时重生
	if damage.is_dead():
		_respawn_timer -= s.step
		if _respawn_timer <= 0.0:
			_setup_spawn()
			damage.heal(999.0)
			_respawn_timer = -1.0
		s.linear_velocity = Vector3.ZERO
		s.angular_velocity = Vector3.ZERO
		return
	# 坠地重生护栏（地面暂无碰撞，防止穿进虚空）
	if model.state.position.y < 1.0:
		_setup_spawn()

	var dt: float = s.step
	var ci = _read_inputs(dt)
	model.step(ci, dt)
	# 把模型物理状态写回刚体：姿态/位置/速度由模型驱动，物理引擎只做碰撞
	s.transform = Transform3D(model.state.basis, model.state.position)
	s.linear_velocity = model.state.velocity
	s.angular_velocity = Vector3.ZERO
	var snap: Dictionary = model.get_debug_snapshot()
	snap["player_hp"] = damage.hp
	_snapshot = snap


func take_damage(amount: float) -> void:
	var was: float = damage.hp
	damage.take_damage(amount)
	if damage.is_dead() and was > 0.0:
		_respawn_timer = RESPAWN_DELAY


func is_dead() -> bool:
	return damage.is_dead()


func _read_inputs(dt: float) -> RefCounted:
	var ci = CI.new()
	# 方向契约（务必测试锁定）：W 抬头、D 右滚、E 右偏航 —— get_axis 已约定方向
	var roll: float = Input.get_axis("roll_left", "roll_right")
	if invert_roll:
		roll = -roll
	ci.pitch = Input.get_axis("pitch_down", "pitch_up")
	ci.roll = roll
	ci.yaw = Input.get_axis("yaw_left", "yaw_right")
	# 油门增量式调节：↑↓ 以 0.5/s 增减
	_throttle = clampf(_throttle + Input.get_axis("throttle_down", "throttle_up") * 0.5 * dt, 0.0, 1.0)
	ci.throttle = _throttle
	return ci


func get_snapshot() -> Dictionary:
	return _snapshot
