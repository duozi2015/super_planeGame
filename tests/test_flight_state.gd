# res://tests/test_flight_state.gd
## T2 — FlightState 状态容器与线性积分

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const FlightState = preload("res://scripts/core/flight_state.gd")

func test_constant_accel_velocity() -> void:
	var s: RefCounted = FlightState.new()
	s.velocity = Vector3.ZERO
	s.step(0.5, Vector3(10, 0, 0))
	Harness.assert_vec_almost_eq(s.velocity, Vector3(5, 0, 0), 1e-5, "v = a*t 半秒")
	var s2: RefCounted = FlightState.new()
	s2.step(2.0, Vector3(0, 9.81, 0))
	Harness.assert_vec_almost_eq(s2.velocity, Vector3(0, 19.62, 0), 1e-4, "v = a*t 两秒")

func test_constant_accel_position() -> void:
	var s: RefCounted = FlightState.new()
	var dt := 1.0 / 60.0
	for i in 120:
		s.step(dt, Vector3(0, 9.81, 0))
	# 2 秒 = 120 个小步，半隐式欧拉收敛于解析解 0.5*a*t^2
	Harness.assert_vec_almost_eq(s.position, Vector3(0, 19.62, 0), 0.3, "p ≈ 0.5*a*t^2（小步长收敛）")
	Harness.assert_vec_almost_eq(s.velocity, Vector3(0, 19.62, 0), 1e-4, "v = a*t 精确")

func test_speed_and_defaults() -> void:
	var s: RefCounted = FlightState.new()
	Harness.assert_eq(s.throttle, 0.0, "默认油门 0")
	Harness.assert_eq(s.afterburner, false, "默认无加力")
	s.velocity = Vector3(3, 4, 0)
	Harness.assert_almost_eq(s.speed_ms(), 5.0, 1e-6, "勾股速度")