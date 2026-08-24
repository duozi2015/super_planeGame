# res://scripts/core/atmosphere.gd
## T3 — 简化 ISA 大气（指数律密度），输出动压等。

class_name Atmosphere
extends RefCounted

const RHO0 := 1.225          # kg/m³ 海平面标准密度
const SCALE_HEIGHT := 8500.0 # 指数标高 m

static func density(alt_m: float) -> float:
	return RHO0 * exp(-alt_m / SCALE_HEIGHT)

static func dynamic_pressure(alt_m: float, speed_ms: float) -> float:
	return 0.5 * density(alt_m) * speed_ms * speed_ms