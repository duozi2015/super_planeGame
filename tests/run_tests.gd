# res://tests/run_tests.gd
## 无头测试运行器：扫描 res://tests/ 下 test_*.gd，逐类实例化，
## 调用所有 test_* 方法，汇总断言失败并退出(0 全绿 / 1 有失败)。
## 运行：
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd ++ --no-mcp
## 说明：测试逻辑放在 _process 首帧执行，此时 quit() 可靠生效。

extends SceneTree

var _ran := false
var _passed := 0
var _failed := 0

func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true

	var harness_script: GDScript = load("res://tests/test_harness.gd")
	if harness_script == null:
		printerr("TESTS: cannot load test_harness.gd")
		quit(1)
		return true
	harness_script.clear()

	var dir := DirAccess.open("res://tests")
	if dir != null:
		var files: Array[String] = []
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.begins_with("test_") and f.ends_with(".gd") \
					and f != "test_harness.gd" and f != "run_tests.gd":
				files.append(f)
			f = dir.get_next()
		dir.list_dir_end()
		files.sort()

		for file in files:
			var script: GDScript = load("res://tests/" + file)
			if script == null or not script.can_instantiate():
				printerr("TESTS: cannot instantiate " + file)
				_failed += 1
				continue
			var inst: RefCounted = script.new()
			if inst == null:
				_failed += 1
				continue
			for method in inst.get_method_list():
				if str(method.name).begins_with("test_"):
					var before: int = harness_script.failures().size()
					inst.call(method.name)
					if harness_script.failures().size() > before:
						_failed += 1
					else:
						_passed += 1

	var fails: Array[String] = harness_script.failures()
	print("TESTS: %d passed, %d failed (%d assertion failures)" % [_passed, _failed, fails.size()])
	if _failed > 0 or fails.size() > 0:
		printerr("TESTS: FAILED (exit 1)")
		quit(1)
	else:
		print("TESTS: ALL GREEN (exit 0)")
		quit(0)
	return true