# res://tests/test_aero_coeffs.gd
## T4 — 气动系数（升力/阻力/侧力 + 失速模型）

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const Aero = preload("res://scripts/core/aero.gd")
const P = Aero.PARAMS

func test_zero_alpha_no_lift_minimum_drag() -> void:
	var cl0: float = Aero.cl(0.0)
	Harness.assert_almost_eq(cl0, 0.0, 1e-6, "α=0 升力为 0")
	Harness.assert_almost_eq(Aero.cd(0.0, cl0), P.cd0, 1e-6, "α=0 阻力≈零升阻力")

func test_linear_lift_region() -> void:
	var alpha := 0.1  # ~5.7°
	var cl_val: float = Aero.cl(alpha)
	var expect := P.cl_alpha * alpha
	Harness.assert_almost_eq(cl_val, expect, 1e-4, "线性区 CL = cl_alpha*α")

func test_stall_reduces_lift() -> void:
	var cl_at_stall: float = Aero.cl(P.stall_alpha)
	var cl_beyond: float = Aero.cl(P.stall_alpha + 0.35)
	Harness.assert_true(cl_beyond < cl_at_stall, "失速后升力下降")
	Harness.assert_true(cl_at_stall >= P.cl_max * 0.5, "失速点仍有相当升力")

func test_cl_never_exceeds_max() -> void:
	for deg in [0.0, 5.0, 10.0, 20.0, 30.0, 45.0, 60.0]:
		var cl_val: float = Aero.cl(deg_to_rad(deg))
		Harness.assert_true(absf(cl_val) <= P.cl_max + 1e-6, "CL 不超过 cl_max")

func test_negative_alpha_mirror_sign() -> void:
	Harness.assert_almost_eq(Aero.cl(-0.1), -Aero.cl(0.1), 1e-4, "负攻角升力反号")

func test_side_force_from_beta() -> void:
	Harness.assert_true(Aero.cy(0.2) < 0.0, "正侧滑产生负侧力")
	Harness.assert_almost_eq(Aero.cy(0.0), 0.0, 1e-6, "无侧滑无侧力")

func test_induced_drag_grows_with_cl() -> void:
	var cl_lo := Aero.cl(0.1)
	var cl_hi := Aero.cl(0.3)
	var cd_lo := Aero.cd(0.1, cl_lo)
	var cd_hi := Aero.cd(0.3, cl_hi)
	Harness.assert_true(cd_hi > cd_lo, "高升力 → 更高诱导阻力")