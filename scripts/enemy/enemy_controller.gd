# res://scripts/enemy/enemy_controller.gd
## 敌机控制器：FlightModel（真物理）+ EnemyAI（FSM 驾驶）+ DamageModel。
## 挂在 RigidBody3D 根节点。编组 "enemies"。
## 收到导弹来袭标记（missile_incoming）时 AI 规避+投放干扰弹。

extends RigidBody3D

const FM = preload("res://scripts/core/flight_model.gd")
const CI = preload("res://scripts/core/control_inputs.gd")
const EnemyAI = preload("res://scripts/core/enemy_ai.gd")
const DamageModel = preload("res://scripts/core/damage.gd")

const CRUISE_SPEED := 220.0
const SPAWN_ALPHA := 0.018

## 敌机视觉模型（GLB）。可用 exported 覆盖为不同型号。
const ENEMY_MODEL := "res://assets/models/enemy/craft_speederB.glb"

## 可导出覆盖：在场景里给不同敌机指定不同型号
@export var model_path := ENEMY_MODEL

var model = FM.new()
var ai = EnemyAI.new()
var damage = DamageModel.new()
var missile_incoming := false

var _throttle := 0.8
var _fire_cd := 0.0
var _player: Node3D = null


func _ready() -> void:
	add_to_group("enemies")
	model.trim_elevator = 0.081
	model.state.basis = Basis(Vector3.RIGHT, -SPAWN_ALPHA)
	model.state.velocity = Vector3(0, 0, CRUISE_SPEED)
	_build_visual()


## 加载真实模型替换占位盒，机头对齐 +Z
func _build_visual() -> void:
	if has_node("Model") or model_path == "":
		return
	var scn: PackedScene = load(model_path)
	if scn == null:
		return
	if has_node("Body"):
		get_node("Body").visible = false
	var inst: Node3D = scn.instantiate()
	inst.name = "Model"
	# 模型 local +Z 已对齐物理 +Z（无需 180° 翻转）
	inst.scale = Vector3(6.0, 6.0, 6.0)          # 放大到与玩家匹配（×3）
	add_child(inst)


func is_dead() -> bool:
	return damage.is_dead()


func take_damage(amount: float) -> void:
	damage.take_damage(amount)


func _integrate_forces(s: PhysicsDirectBodyState3D) -> void:
	if damage.is_dead():
		s.linear_velocity = Vector3.ZERO
		s.angular_velocity = Vector3.ZERO
		visible = false
		return

	_fire_cd = maxf(_fire_cd - s.step, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var target_pos := Vector3.ZERO
	var target_vel := Vector3.ZERO
	if is_instance_valid(_player):
		target_pos = _player.global_position
		target_vel = _player.linear_velocity

	var ctx := {
		"self_pos": model.state.position,
		"self_basis": model.state.basis,
		"target_pos": target_pos,
		"target_vel": target_vel,
		"health_frac": damage.hp / damage.max_hp,
		"missile_inbound": missile_incoming,
	}
	ai.update(s.step, ctx)
	var ci = ai.control
	ci.throttle = _throttle
	model.step(ci, s.step)

	s.transform = Transform3D(model.state.basis, model.state.position)
	s.linear_velocity = model.state.velocity
	s.angular_velocity = Vector3.ZERO

	# 机炮开火
	if ai.fire_wanted and _fire_cd <= 0.0:
		_fire_guns()
		_fire_cd = 0.6


## 机炮：对玩家方向射线（简化伤害模型）
func _fire_guns() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var fwd: Vector3 = model.state.basis * Vector3(0, 0, 1)
	var to_p: Vector3 = _player.global_position - model.state.position
	if to_p.length() > 1600.0:
		return
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(model.state.position + fwd * 2.0, _player.global_position)
	var hit := space.intersect_ray(q)
	if hit and hit.collider == _player:
		_player.take_damage(10.0)
