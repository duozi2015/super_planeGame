# res://scripts/core/missile.gd
## 导弹状态：追踪目标、燃料耗尽、命中判定。纯逻辑可测。
## 目标以 Dictionary 传入：{position: Vector3, velocity: Vector3, alive: bool}

class_name MissileState
extends RefCounted

const MAX_SPEED := 620.0     # m/s 巡航
const INIT_SPEED := 120.0    # m/s 出膛
const ACCEL_RATE := 800.0    # m/s² 加速
const TURN_RATE := 2.4       # rad/s 最大转向率
const FUEL_TIME := 9.0       # s 动力时间
const HIT_RADIUS := 9.0      # m 命中半径

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var fuel := FUEL_TIME
var hit := false             # 已命中
var expired := false         # 燃料耗尽/脱离（脱靶）
var _age := 0.0


func launch(from: Vector3, dir: Vector3) -> void:
	position = from
	velocity = dir.normalized() * INIT_SPEED


func update(delta: float, target: Dictionary) -> void:
	_age += delta
	var t_pos: Vector3 = target.position
	var t_vel: Vector3 = target.velocity
	var alive: bool = target.alive

	# —— 转向：向目标当前位置引导（纯追击，转弯受 TURN_RATE 限制） ——
	var to_target: Vector3 = t_pos - position
	var dist := to_target.length()
	if dist > 0.01 and alive:
		var desired_dir: Vector3 = to_target / dist
		var max_turn := TURN_RATE * delta
		var ang := velocity.normalized().angle_to(desired_dir) if velocity.length() > 0.01 else 0.0
		var turn := minf(ang, max_turn)
		if ang > 1e-4:
			var axis := velocity.normalized().cross(desired_dir).normalized()
			velocity = velocity.normalized().rotated(axis, turn) * velocity.length()

	# —— 加速到巡航 ——
	var spd := velocity.length()
	var target_spd := minf(MAX_SPEED, spd + ACCEL_RATE * delta)
	velocity = velocity.normalized() * target_spd if velocity.length() > 0.01 else velocity

	# —— 前进 ——
	position += velocity * delta

	# —— 燃料/命中 ——
	fuel -= delta
	if fuel <= 0.0:
		expired = true
		velocity = Vector3.ZERO
	if dist < HIT_RADIUS:
		hit = true


func is_done() -> bool:
	return hit or expired