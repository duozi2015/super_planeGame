# res://tests/test_weapons.gd
## M3 — 武器系统：机炮热量/弹量、锁定进程、导弹追踪/命中/脱靶、干扰弹

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const WeaponSystem = preload("res://scripts/core/weapon_system.gd")
const MissileState = preload("res://scripts/core/missile.gd")


func _target(pos: Vector3, vel := Vector3.ZERO, alive := true) -> Dictionary:
	return {"position": pos, "velocity": vel, "alive": alive}


func _advance(ws, steps: int, dt := 0.05, pos := Vector3.ZERO, fwd := Vector3(0, 0, 1), target := {}) -> void:
	for i in steps:
		ws.update(dt, pos, fwd, target)


func test_gun_fires_and_consumes() -> void:
	var ws = WeaponSystem.new()
	var ammo0: int = ws.gun_ammo
	Harness.assert_true(ws.try_fire_guns(), "首发射击成功")
	Harness.assert_eq(ws.gun_ammo, ammo0 - 1, "消耗一发弹药")
	Harness.assert_true(ws.gun_heat > 0.0, "产生热量")
	Harness.assert_true(not ws.try_fire_guns(), "射速限制：同帧不能连射")


func test_gun_overheat_blocks_and_recovers() -> void:
	var ws = WeaponSystem.new()
	for i in 80:  # 4 秒持续射击（约 60 发有效，净热量 ≈ 2.0 → 过热）
		ws.try_fire_guns()
		ws.update(0.05, Vector3.ZERO, Vector3(0, 0, 1), {})
	Harness.assert_true(ws.gun_overheated, "持续射击应过热")
	Harness.assert_true(not ws.can_fire_guns(), "过热时禁射")
	_advance(ws, 60, 0.05)  # 3 秒冷却
	Harness.assert_true(ws.can_fire_guns(), "冷却后可再射")


func test_lock_builds_and_drops() -> void:
	var ws = WeaponSystem.new()
	var t := _target(Vector3(0, 0, 1000))
	var fwd := Vector3(0, 0, 1)
	var steps := 0
	while not ws.is_locked() and steps < 60:
		ws.update(0.05, Vector3.ZERO, fwd, t)
		steps += 1
	Harness.assert_true(ws.is_locked(), "目标在正前方应建立锁定, steps=%d" % steps)
	# 目标转到身后 → 锁定丢失
	var t2 := _target(Vector3(0, 0, -1000))
	for i in 40:
		ws.update(0.05, Vector3.ZERO, fwd, t2)
	Harness.assert_true(not ws.is_locked(), "目标在身后应失去锁定")


func test_missile_hits_stationary_target() -> void:
	var m = MissileState.new()
	m.launch(Vector3.ZERO, Vector3(0, 0, 1))
	var t := _target(Vector3(0, 0, 2000))
	for i in 300:
		m.update(0.05, t)
		if m.is_done():
			break
	Harness.assert_true(m.hit, "静止目标应被命中 (expired=%s)" % str(m.expired))


func test_missile_expires_on_fleeing_target() -> void:
	var m = MissileState.new()
	m.launch(Vector3.ZERO, Vector3(0, 0, 1))
	var t := _target(Vector3(0, 0, 1500), Vector3(0, 0, 500))
	for i in 400:
		t.position = t.position + t.velocity * 0.05  # 目标实际移动
		m.update(0.05, t)
		if m.is_done():
			break
	Harness.assert_true(m.expired and not m.hit, "高速逃跑目标应脱靶(燃料耗尽)")


func test_fire_missile_requires_lock() -> void:
	var ws = WeaponSystem.new()
	Harness.assert_true(not ws.try_fire_missile(Vector3.ZERO, Vector3(0, 0, 1)), "未锁定不能发射")
	var t := _target(Vector3(0, 0, 1000))
	for i in 40:
		ws.update(0.05, Vector3.ZERO, Vector3(0, 0, 1), t)
	Harness.assert_true(ws.is_locked(), "前置条件：已锁定")
	var cnt: int = ws.missile_count
	Harness.assert_true(ws.try_fire_missile(Vector3.ZERO, Vector3(0, 0, 1)), "锁定后可发射")
	Harness.assert_eq(ws.missile_count, cnt - 1, "消耗一枚导弹")
	Harness.assert_eq(ws.missiles.size(), 1, "生成一枚在途导弹")


func test_flare_chaff_cooldown_and_caps() -> void:
	var ws = WeaponSystem.new()
	var fl0: int = ws.flare_count
	Harness.assert_true(ws.deploy_flare(), "投放热焰")
	Harness.assert_eq(ws.flare_count, fl0 - 1, "热焰-1")
	Harness.assert_true(not ws.deploy_flare(), "冷却中不能连投")
	_advance(ws, 40, 0.05)  # 2 秒
	Harness.assert_true(ws.deploy_flare(), "冷却后可再投")
	_advance(ws, 40, 0.05)  # 再等 2 秒清冷却
	var ch0: int = ws.chaff_count
	Harness.assert_true(ws.deploy_chaff(), "投放铝箔")
	Harness.assert_eq(ws.chaff_count, ch0 - 1, "铝箔-1")