# res://scripts/camera/chase_cam.gd
## T8-mini — 追尾相机：平滑跟随目标机身，FOV 随速度张开。
## 场景里把 target_node 指向玩家刚体即可。

extends Camera3D

@export var target_node: Node3D
@export var follow_stiffness := 6.0
@export var look_ahead := 12.0

var _fov_base := 60.0
var _fov_fast := 92.0


func _ready() -> void:
	fov = _fov_base
	if is_instance_valid(target_node):
		global_position = target_node.global_position


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target_node):
		return
	var body := target_node as RigidBody3D
	var body_basis: Basis = body.global_basis
	# 机体 +Z=前 → 相机放机后上方（体轴偏移），收近增强沉浸
	# 真实模型 scale6 机长约 12m（半长 6），相机收到机尾外 2.5m、上方俯看 → 飞机占屏明显更大
	var offset := Vector3(0.0, 3.5, -8.5)
	var desired_pos: Vector3 = body.global_position + body_basis * offset
	var k := 1.0 - exp(-follow_stiffness * delta)
	global_position = global_position.lerp(desired_pos, k)
	# 看向机头前方一点，机动时更有动感
	var look_target: Vector3 = body.global_position + body_basis * Vector3(0, 0, look_ahead)
	look_at(look_target, Vector3.UP)
	# FOV 随速张开（加速时视野更宽）
	var spd: float = body.linear_velocity.length()
	fov = lerpf(_fov_base, _fov_fast, clampf(spd / 320.0, 0.0, 1.0))
