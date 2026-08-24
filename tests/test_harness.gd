# res://tests/test_harness.gd
## TDD 断言工具（纯静态，无节点依赖，可被无头测试直接加载）
## 用法：每个测试文件顶部 `const Harness = preload("res://tests/test_harness.gd")`，
##       断言失败会记录到 fail 数组并打印，运行结束后由 run_tests.gd 汇总。

class_name TestHarness
extends RefCounted

static var _failures: Array[String] = []

static func clear() -> void:
	_failures.clear()

static func failures() -> Array[String]:
	return _failures.duplicate()

## 返回 true 表示通过；失败时记录一条失败消息。
static func assert_true(cond: bool, msg: String) -> bool:
	if not cond:
		_failures.append(msg)
		printerr("  ✗ FAIL: " + msg)
	return cond

static func assert_almost_eq(a: float, b: float, eps: float, msg: String) -> bool:
	if absf(a - b) > eps:
		return assert_true(false, "%s (got %.4f, want %.4f ± %.4f)" % [msg, a, b, eps])
	return true

static func assert_eq(a: Variant, b: Variant, msg: String) -> bool:
	if a != b:
		return assert_true(false, "%s (got %s, want %s)" % [msg, str(a), str(b)])
	return true

static func assert_vec_almost_eq(a: Vector3, b: Vector3, eps: float, msg: String) -> bool:
	if (a - b).length() > eps:
		return assert_true(false, "%s (got %s, want %s ± %.4f)" % [msg, a, b, eps])
	return true