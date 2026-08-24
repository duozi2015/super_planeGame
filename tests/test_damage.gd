# res://tests/test_damage.gd
## M3 — 损伤模型

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const DamageModel = preload("res://scripts/core/damage.gd")


func test_take_damage_reduces_hp() -> void:
	var d = DamageModel.new()
	d.take_damage(30.0)
	Harness.assert_almost_eq(d.hp, 70.0, 1e-4, "扣血 30")
	Harness.assert_true(not d.is_dead(), "未死亡")
	Harness.assert_almost_eq(d.degradation(), 0.3, 1e-4, "损伤度 30%")


func test_overkill_dies_at_zero() -> void:
	var d = DamageModel.new()
	d.take_damage(500.0)
	Harness.assert_almost_eq(d.hp, 0.0, 1e-4, "血量为 0")
	Harness.assert_true(d.is_dead(), "被击杀")
	Harness.assert_almost_eq(d.degradation(), 1.0, 1e-4, "完全损毁")


func test_heal_clamps() -> void:
	var d = DamageModel.new()
	d.take_damage(40.0)
	d.heal(100.0)
	Harness.assert_almost_eq(d.hp, 100.0, 1e-4, "治疗封顶到满血")