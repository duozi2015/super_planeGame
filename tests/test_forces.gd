# res://tests/test_forces.gd
## T5 — FlightModel：气流角→合力→积分→控制→标志位 组装正确性

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const FlightModel = preload("res://scripts/core/flight_model.gd")
const ControlInputs = preload("res://scripts/core/control_inputs.gd")

## ① 零输入稳定性冒烟：10 秒内无 NaN、速度有界、重力主导（不发散）
func test_zero_input_no_divergence() -> void:
	var m = FlightModel.new()
	m.state.position = Vector3(0, 1000, 0)
	m.state.velocity = Vector3(0, 0, 150)
	var ci = ControlInputs.new()
	for i in 600:  # 600×1/60 = 10s
		m.step(ci, 1.0 / 60.0)
	Harness.assert_true(m.state.velocity.is_finite(), "速度有限(无 NaN)")
	Harness.assert_true(m.state.position.is_finite(), "位置有限(无 NaN)")
	var spd: float = m.state.velocity.length()
	Harness.assert_true(spd < 400.0, "速度有界(不发散), got %.1f" % spd)

## ② 配平巡航：T=D、L=W，4 秒内速度/高度/过载保持（配平舵抵消静稳定低头力矩）
func test_trim_cruise_holds() -> void:
	var m = FlightModel.new()
	var alt := 500.0
	m.state.position = Vector3(0, alt, 0)
	var alpha_trim := 0.02485   # = W/(qS·cl_alpha)，离线算得 1.42°
	m.state.basis = Basis(Vector3.RIGHT, -alpha_trim)  # 抬头
	m.state.velocity = Vector3(0, 0, 250)
	m.trim_elevator = 0.081      # δe_trim = (cm0+cm_alpha·α)/cm_de，离线算得
	var ci = ControlInputs.new()
	ci.throttle = 0.326         # T=D：巡航油门(离线算得)
	for i in 240:               # 4s
		m.step(ci, 1.0 / 60.0)
	var sp: float = m.state.velocity.length()
	Harness.assert_true(sp > 225.0 and sp < 275.0, "巡航速度保持(±10%), got %.1f" % sp)
	var alt_drift: float = absf(m.state.position.y - alt)
	Harness.assert_true(alt_drift < 60.0, "高度保持, drift %.1f" % alt_drift)
	Harness.assert_almost_eq(m.get_debug_snapshot().load_factor, 1.0, 0.3, "平飞过载≈1G")
	var vy: float = m.state.velocity.y
	Harness.assert_true(absf(vy) < 6.0, "基本水平飞行, vy=%.2f" % vy)

## ③ 零油门自由落体：短窗垂直加速度≈g
func test_freefall_accel_approx_g() -> void:
	var m = FlightModel.new()
	m.state.position = Vector3(0, 500, 0)
	m.state.velocity = Vector3(0, 0, 30)
	var ci = ControlInputs.new()
	var steps := 30             # 0.5s
	var dt := 1.0 / 60.0
	var vy0: float = m.state.velocity.y
	for i in steps:
		m.step(ci, dt)
	var accel: float = (m.state.velocity.y - vy0) / (steps * dt)
	var g_abs := absf(accel)
	Harness.assert_true(g_abs > 8.5 and g_abs < 10.5, "垂直加速度大小≈g, got %.2f" % g_abs)

## ④ 操纵符号：拉杆(positive pitch) → 抬头(角速度 X 为负)
func test_pitch_input_pulls_nose_up() -> void:
	var m = FlightModel.new()
	m.state.velocity = Vector3(0, 0, 100)
	var ci = ControlInputs.new()
	ci.pitch = 0.5
	m.step(ci, 1.0 / 60.0)
	var wx: float = m.state.angular_velocity.x
	Harness.assert_true(wx < 0.0, "拉杆→抬头(ωx<0), got %.3f" % wx)

## ⑤ 模型级回归：右滚 90° 后拉杆 → 应水平右转，而不是世界系爬升
## 锁死姿态积分必须在机体系内生效（body-frame）。
func test_model_banked_pull_turns_not_climbs() -> void:
	var m = FlightModel.new()
	m.state.basis = Basis.IDENTITY * Basis(Vector3(0, 0, 1), -PI / 2.0)  # 右滚 90°
	m.state.velocity = Vector3(0, 0, 250)
	m.state.angular_velocity = Vector3.ZERO
	m.trim_elevator = 0.0
	var ci = ControlInputs.new()
	ci.pitch = 1.0            # 满拉杆
	for i in 30:              # 0.5s
		m.step(ci, 1.0 / 60.0)
	var fwd: Vector3 = m.state.basis * Vector3(0, 0, 1)
	Harness.assert_true(fwd.x > 0.1, "右滚拉杆应水平右转 fwd.x, got %.3f" % fwd.x)
	Harness.assert_true(fwd.y < 0.3, "不应直接爬升 fwd.y, got %.3f" % fwd.y)

## ⑥ 控制方向锁定：roll=+1(D) 应右滚（body up→世界+X）；yaw=+1(E) 应右偏航（机头→+X）
func test_roll_input_banks_right() -> void:
	var m = FlightModel.new()
	m.state.velocity = Vector3(0, 0, 200)
	var ci = ControlInputs.new()
	ci.roll = 1.0
	for i in 30:
		m.step(ci, 1.0 / 60.0)
	var up: Vector3 = m.state.basis * Vector3(0, 1, 0)
	Harness.assert_true(up.x > 0.1, "roll=+1 应右滚(up→+X), got %.3f" % up.x)

func test_yaw_input_yaws_right() -> void:
	var m = FlightModel.new()
	m.state.velocity = Vector3(0, 0, 200)
	var ci = ControlInputs.new()
	ci.yaw = 1.0
	for i in 30:
		m.step(ci, 1.0 / 60.0)
	var fwd: Vector3 = m.state.basis * Vector3(0, 0, 1)
	Harness.assert_true(fwd.x > 0.1, "yaw=+1 应右偏航(机头→+X), got %.3f" % fwd.x)