# res://scripts/core/enemy_ai.gd
## 敌机 AI（有限状态机）：PATROL → ENGAGE → EVADE → DISENGAGE。
## 纯逻辑可测：输入上下文 ctx，输出飞控指令 + 开火/干扰弹请求。
## ctx: {self_pos, self_basis, target_pos, target_vel, health_frac, missile_inbound}

class_name EnemyAI
extends RefCounted

const ControlInputs = preload("res://scripts/core/control_inputs.gd")

enum State { PATROL, ENGAGE, EVADE, DISENGAGE }

const ENGAGE_RANGE := 6000.0
const FIRE_RANGE := 1600.0
const FIRE_FOV_DEG := 14.0
const DISENGAGE_HP := 0.25
const EVADE_TIME := 2.5

var state := State.PATROL
var _state_time := 0.0
var control: RefCounted = ControlInputs.new()
var fire_wanted := false
var countermeasure_wanted := false


func update(delta: float, ctx: Dictionary) -> void:
	_state_time += delta
	var target_pos: Vector3 = ctx.target_pos
	var self_pos: Vector3 = ctx.self_pos
	var self_basis: Basis = ctx.self_basis
	var health_frac: float = ctx.health_frac
	var missile_inbound: bool = ctx.missile_inbound

	var to_t: Vector3 = target_pos - self_pos
	var dist := to_t.length()

	# 探测到目标 → 接战
	if state == State.PATROL and dist <= ENGAGE_RANGE:
		state = State.ENGAGE
	# 威胁优先级最高：来袭导弹 → 规避
	if missile_inbound and state != State.EVADE:
		state = State.EVADE
		_state_time = 0.0
	if state == State.EVADE and _state_time > EVADE_TIME:
		state = State.ENGAGE
		_state_time = 0.0
	# 低血量 → 脱离
	if health_frac < DISENGAGE_HP and state != State.EVADE:
		state = State.DISENGAGE

	fire_wanted = false
	countermeasure_wanted = false
	var desired: Vector3 = self_basis * Vector3(0, 0, 1)  # 默认维持航向

	match state:
		State.ENGAGE:
			desired = _lead_point(to_t, ctx).normalized()
			var fwd: Vector3 = self_basis * Vector3(0, 0, 1)
			var angle_deg := rad_to_deg(fwd.normalized().angle_to(to_t / dist))
			fire_wanted = dist < FIRE_RANGE and angle_deg < FIRE_FOV_DEG
		State.EVADE:
			countermeasure_wanted = true
			# 垂直转向威胁，做急转规避
			var axis := to_t.cross(Vector3.UP)
			if axis.length() < 1e-4:
				axis = Vector3.RIGHT
			desired = (axis.normalized() + Vector3.UP * 0.4).normalized()
		State.DISENGAGE:
			desired = (-to_t).normalized()
		State.PATROL:
			pass  # 维持航向

	control = _autopilot(self_basis, desired)
	control.throttle = 0.9


## 纯追击引导：瞄向目标当前位置（可加前置量）
func _lead_point(to_target: Vector3, ctx: Dictionary) -> Vector3:
	var target_vel: Vector3 = ctx.target_vel
	var dist := to_target.length()
	if dist > 1.0:
		var lead_time := dist / 900.0
		return to_target + target_vel * lead_time
	return to_target


## 自动驾驶仪：把世界系期望方向转成机体控制量
func _autopilot(self_basis: Basis, desired_dir: Vector3) -> RefCounted:
	var ci = ControlInputs.new()
	var local := self_basis.inverse() * desired_dir.normalized()
	if local.z < 0.0:
		# 目标/期望在正后方：pitch/yaw 表达不了"掉头"，拉杆爬升调头
		ci.pitch = 1.0
		ci.roll = 0.0
		return ci
	ci.pitch = clampf(local.y, -1.0, 1.0)
	ci.yaw = clampf(local.x, -1.0, 1.0)
	ci.roll = clampf(-local.x, -1.0, 1.0)  # 压坡度帮助转向
	return ci