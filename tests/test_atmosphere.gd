# res://tests/test_atmosphere.gd
## T3 — ISA 简化大气模型（指数律密度）

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const Atmosphere = preload("res://scripts/core/atmosphere.gd")

func test_sea_level_density() -> void:
	Harness.assert_almost_eq(Atmosphere.density(0.0), 1.225, 1e-3, "海平面密度 1.225")

func test_density_at_scale_height() -> void:
	var alt := 8500.0
	var expect := 1.225 * exp(-alt / 8500.0)
	Harness.assert_almost_eq(Atmosphere.density(alt), expect, 1e-3, "标高 8500m 处按指数律")

func test_density_decreases_with_altitude() -> void:
	Harness.assert_true(Atmosphere.density(10000.0) < Atmosphere.density(0.0), "高空密度更低")

func test_dynamic_pressure_scales_v2() -> void:
	var q100 := Atmosphere.dynamic_pressure(0.0, 100.0)
	var q200 := Atmosphere.dynamic_pressure(0.0, 200.0)
	Harness.assert_almost_eq(q100 / q200, 0.25, 1e-4, "动压随 v^2 增长")