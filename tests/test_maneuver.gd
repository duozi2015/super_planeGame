# res://tests/test_maneuver.gd
## M3+ 手感调优 — 机动性冒烟：验证"突然拉起/急转弯"可用且不失速失控。
## 相对断言（引用 Aero.PARAMS），不绑定魔法数字之外的手感尺度。

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const FlightModel = preload("res://scripts/core/flight_model.gd")
const ControlInputs = preload("res://scripts/core/control_inputs.gd")
const Aero = preload("res://scripts/core/aero.gd")
const P = Aero.PARAMS

const DT := 1.0 / 60.0


func _cruise_model() -> RefCounted:
	var m = FlightModel.new()
	m.state.position = Vector3(0, 1000, 0)
	m.state.velocity = Vector3(0, 0, 260)
	m.state.basis = Basis.IDENTITY
	m.trim_elevator = 0.082   # 近似配平（与巡航平衡接近）
	return m


## ① 突然拉起：满拉杆应能拉出显著过载(高 G)，说明"急拉"有效
func test_hard_pull_reaches_high_g() -> void:
	var m = _cruise_model()
	var ci = ControlInputs.new()
	ci.throttle = 0.5
	ci.pitch = 1.0
	var peak_g := 0.0
	for i in 90:   # 1.5s
		m.step(ci, DT)
		var s: Dictionary = m.get_debug_snapshot()
		peak_g = maxf(peak_g, float(s.load_factor))
	Harness.assert_true(peak_g > 3.0, "突然拉起应拉出 >3G, got %.1f" % peak_g)


## ② 抗失速：满拉杆（即使迎角升到 30°+ 高值）也不触发失速
## 锁死"提高失速迎角"之后——不再动不动就失速(用户：失速仰角提到60°)
func test_hard_pull_no_early_stall() -> void:
	var m = _cruise_model()
	var ci = ControlInputs.new()
	ci.throttle = 0.5
	ci.pitch = 1.0
	var any_stall := false
	var max_alpha := 0.0
	for i in 150:  # 2.5s
		m.step(ci, DT)
		var s: Dictionary = m.get_debug_snapshot()
		if bool(s.stall):
			any_stall = true
		max_alpha = maxf(max_alpha, float(s.alpha_deg))
	Harness.assert_true(max_alpha > 30.0, "满拉杆应能拉到高迎角 >30°, got %.1f" % max_alpha)
	Harness.assert_true(not any_stall, "高速满拉杆不应触发失速(失速迎角已放宽至 %.0f°)" % rad_to_deg(float(P.stall_alpha)))


## ③ 压坡急转：右滚+拉杆应快速滚转（机背 up 明显偏 +X）→ 急转弯基础
func test_banked_turn_rolls_quickly() -> void:
	var m = _cruise_model()
	var ci = ControlInputs.new()
	ci.throttle = 0.5
	ci.roll = 1.0
	ci.pitch = 1.0
	var best_up_x := 0.0
	for i in 90:   # 1.5s
		m.step(ci, DT)
		var up: Vector3 = m.state.basis * Vector3(0, 1, 0)
		best_up_x = maxf(best_up_x, up.x)
	Harness.assert_true(best_up_x > 0.5, "压坡后机体 up 应明显偏向 +X(有效滚转), got %.2f" % best_up_x)


## ④ 可控性：即使持续高攻角(失速强度高)，升降舵仍应保有舵效（称重损失不该让飞机僵死）
## 验证 stab_loss_at_stall 降低后不至于完全失控——用满拉杆后机身朝向仍持续变化表示有舵效
func test_surfaces_remain_effective_near_stall() -> void:
	var m = _cruise_model()
	var ci = ControlInputs.new()
	ci.throttle = 0.5
	ci.pitch = 1.0
	var dirs: Array[Vector3] = []
	for i in 90:
		m.step(ci, DT)
		dirs.append(m.state.basis * Vector3(0, 0, 1))
	# 机头方向持续转动 → 舵面未因失速僵死
	var rot_sum := 0.0
	for i in range(1, dirs.size()):
		rot_sum += dirs[i].angle_to(dirs[i - 1])
	Harness.assert_true(rot_sum > 0.5, "失速边缘舵面应持续转动机头(仍可控), rot %.2f rad" % rot_sum)
