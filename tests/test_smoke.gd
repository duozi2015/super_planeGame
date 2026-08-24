# res://tests/test_smoke.gd
## 冒烟测试：验证测试基建本身可用（T1 的绿基线）。

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")

func test_harness_records_true() -> void:
	Harness.assert_true(true, "恒真断言应通过")

func test_harness_almost_eq() -> void:
	Harness.assert_almost_eq(1.0, 1.00005, 0.001, "1.00005 在 ±0.001 内")