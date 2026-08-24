# res://tests/test_basis_rotation.gd
## 姿态积分坐标系判别测试。
## 关键：拉杆（绕机体横轴）必须在机体系内生效——
## 右滚 90° 后拉杆应让机头水平向右转，而不是世界系里直接爬升。

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")

const FWD := Vector3(0, 0, 1)  # 机体前


func test_pull_from_level_goes_up() -> void:
	var b := Basis.IDENTITY
	b = b * Basis(Vector3(1, 0, 0), -0.3)  # 拉杆 0.3rad（绕机体横轴抬头）
	var fwd: Vector3 = b * FWD
	Harness.assert_true(fwd.y > 0.1, "平飞拉杆应爬升 fwd.y, got %.3f" % fwd.y)
	Harness.assert_almost_eq(fwd.x, 0.0, 0.001, "平飞拉杆不偏航")


func test_right_bank_then_pull_turns_not_climbs() -> void:
	var b := Basis.IDENTITY
	b = b * Basis(Vector3(0, 0, 1), -PI / 2.0)  # 右滚 90°（body up → 世界+X）
	Harness.assert_vec_almost_eq(b * Vector3(0, 1, 0), Vector3(1, 0, 0), 1e-3, "右滚后 body up 指向 +X")
	# 拉杆：绕机体横轴 +X 负向（抬头）
	b = b * Basis(Vector3(1, 0, 0), -0.3)
	var fwd: Vector3 = b * FWD
	# 正确物理：机头应水平向右转（fwd.x>0），且不直接爬升（fwd.y 应≈0）
	Harness.assert_true(fwd.x > 0.1, "右滚拉杆应向右转 fwd.x, got %.3f" % fwd.x)
	Harness.assert_true(fwd.y < 0.05, "右滚拉杆不应爬升 fwd.y, got %.3f" % fwd.y)