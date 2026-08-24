# res://tests/test_enemy_ai.gd
## M3 — 敌机 AI：FSM 状态转移 + 自动驾驶输出 + 开火/干扰弹请求

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const EnemyAI = preload("res://scripts/core/enemy_ai.gd")


func _ctx(pos: Vector3, target_pos: Vector3, health := 1.0, inbound := false, target_vel := Vector3.ZERO) -> Dictionary:
	return {
		"self_pos": pos,
		"self_basis": Basis.IDENTITY,
		"target_pos": target_pos,
		"target_vel": target_vel,
		"health_frac": health,
		"missile_inbound": inbound,
	}


func test_engages_and_fires_when_aligned_and_close() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, 1000)))
	Harness.assert_eq(ai.state, EnemyAI.State.ENGAGE, "目标在射程内应进入接战")
	Harness.assert_true(ai.fire_wanted, "对准且近距应请求开火")
	Harness.assert_almost_eq(ai.control.pitch, 0.0, 0.02, "目标正前飞控基本平直")
	Harness.assert_almost_eq(ai.control.yaw, 0.0, 0.02, "不偏航")


func test_no_fire_when_too_far() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, 3000)))
	Harness.assert_true(not ai.fire_wanted, "远距不请求开火")


func test_evade_on_missile_inbound_then_recover() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, 1000), 1.0, true))
	Harness.assert_eq(ai.state, EnemyAI.State.EVADE, "导弹来袭进入规避")
	Harness.assert_true(ai.countermeasure_wanted, "规避时投放干扰弹")
	# 规避时间过后回到接战
	for i in 60:
		ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, 1000)))
	Harness.assert_eq(ai.state, EnemyAI.State.ENGAGE, "规避后恢复接战")


func test_disengage_when_low_health() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, 1000), 0.1))
	Harness.assert_eq(ai.state, EnemyAI.State.DISENGAGE, "低血量脱离")
	Harness.assert_true(not ai.fire_wanted, "脱离时不交火")


func test_turn_around_when_target_behind() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 0, -2000)))
	Harness.assert_eq(ai.control.pitch, 1.0, "目标在正后方→拉杆爬升调头")


func test_steer_toward_target() -> void:
	var ai = EnemyAI.new()
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(0, 200, 1000)))
	# 目标偏上 → 期望抬头（pitch>0）
	Harness.assert_true(ai.control.pitch > 0.0, "目标在上方应抬头 pitch, got %.2f" % ai.control.pitch)
	ai.update(0.05, _ctx(Vector3.ZERO, Vector3(200, 0, 1000)))
	# 目标偏右 → 期望偏航（yaw>0）
	Harness.assert_true(ai.control.yaw > 0.0, "目标在右侧应右偏航 yaw, got %.2f" % ai.control.yaw)