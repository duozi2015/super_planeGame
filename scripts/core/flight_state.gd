# res://scripts/core/flight_state.gd
## T2 — 飞行状态容器 + 线性积分。
## 纯逻辑 RefCounted（无节点依赖），可被无头测试直接实例化。

class_name FlightState
extends RefCounted

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY          # 姿态
var angular_velocity: Vector3 = Vector3.ZERO  # rad/s（机体坐标系）
var throttle: float = 0.0                  # 0..1
var afterburner: bool = false

## 用世界系加速度推进一个物理步长。
func step(dt: float, accel_world: Vector3) -> void:
	velocity += accel_world * dt
	position += velocity * dt

func speed_ms() -> float:
	return velocity.length()

func normalize_basis() -> void:
	basis = basis.orthonormalized()