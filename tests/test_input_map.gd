# res://tests/test_input_map.gd
## 输入映射回归测试：锁死"device=-1 + 双键码"绑定能被真实键盘事件命中。
## 背景：MCP 写入的旧事件带 device=16/keycode=0，真实键盘(device 0)永远匹配不上。

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")

const DEFS := {
	"pitch_up": KEY_W, "pitch_down": KEY_S,
	"roll_left": KEY_A, "roll_right": KEY_D,
	"yaw_left": KEY_Q, "yaw_right": KEY_E,
	"throttle_up": KEY_UP, "throttle_down": KEY_DOWN,
	"fire_guns": KEY_SPACE, "lock_target": KEY_L, "fire_missile": KEY_M,
	"deploy_flare": KEY_C, "deploy_chaff": KEY_X,
}


func _install(action: String, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.device = -1              # 匹配任意设备（关键修复）
	ev.keycode = key
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _press(key: int, device: int) -> void:
	Input.use_accumulated_input = false
	var ev := InputEventKey.new()
	ev.device = device
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)


func _release_all() -> void:
	for action in DEFS:
		if InputMap.has_action(action):
			Input.action_release(action)


func test_os_style_w_matches_pitch_up() -> void:
	_release_all()
	_install("pitch_up", DEFS.pitch_up)
	_press(DEFS.pitch_up, 0)
	Harness.assert_true(Input.is_action_pressed("pitch_up"), "device0 的 W 事件应命中 pitch_up")
	Input.action_release("pitch_up")

func test_axis_sign_for_pitch() -> void:
	_release_all()
	for action in DEFS:
		_install(action, DEFS[action])
	_press(DEFS.pitch_up, 0)
	var axis: float = Input.get_axis("pitch_down", "pitch_up")
	Harness.assert_almost_eq(axis, 1.0, 1e-3, "W 按下 → pitch 轴 +1（拉杆）")
	_press(DEFS.pitch_down, 0)
	axis = Input.get_axis("pitch_down", "pitch_up")
	Harness.assert_almost_eq(axis, 0.0, 1e-3, "同时按 S 抵消")
	Input.action_release("pitch_up")
	Input.action_release("pitch_down")

func test_throttle_axis_sign() -> void:
	_release_all()
	for action in DEFS:
		_install(action, DEFS[action])
	_press(DEFS.throttle_up, 0)
	var axis: float = Input.get_axis("throttle_down", "throttle_up")
	Harness.assert_almost_eq(axis, 1.0, 1e-3, "↑ 按下 → throttle 轴 +1")
	Input.action_release("throttle_up")

func test_old_broken_binding_is_repaired() -> void:
	# 模拟旧的坏绑定：device=16 且只填 physical_keycode
	if not InputMap.has_action("pitch_up"):
		InputMap.add_action("pitch_up")
	InputMap.action_erase_events("pitch_up")
	var broken := InputEventKey.new()
	broken.device = 16
	broken.keycode = 0
	broken.physical_keycode = DEFS.pitch_up
	InputMap.action_add_event("pitch_up", broken)
	# 修复路径：与 _ensure_input_actions 相同
	_install("pitch_up", DEFS.pitch_up)
	_press(DEFS.pitch_up, 0)
	Harness.assert_true(Input.is_action_pressed("pitch_up"), "修复后 device0 W 应命中 pitch_up")
	Input.action_release("pitch_up")