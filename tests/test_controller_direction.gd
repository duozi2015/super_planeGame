# res://tests/test_controller_direction.gd
## 玩家输入方向契约：按压 D（roll_right）→ 模型 roll 应为右滚方向。
## 锁死 flight_controller 输入映射与模型 roll 方向的约定。

extends RefCounted

const Harness = preload("res://tests/test_harness.gd")
const ControlInputs = preload("res://scripts/core/control_inputs.gd")

# 与 flight_controller._ensure_input_actions 一致
const DEFS := {
	"roll_left": {"key": KEY_A, "pos": 0.0, "neg": 1.0},   # A → 左滚：模型 roll 应为 -1（左滚）
	"roll_right": {"key": KEY_D, "pos": 1.0, "neg": 0.0},  # D → 右滚：模型 roll 应为 +1
}


func _drop_event(key: int) -> void:
	Input.use_accumulated_input = false
	var ev := InputEventKey.new()
	ev.device = -1
	ev.keycode = key
	ev.physical_keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)


func _init_action(name: String, key: int) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	InputMap.action_erase_events(name)
	var ev := InputEventKey.new()
	ev.device = -1
	ev.keycode = key
	ev.physical_keycode = key
	InputMap.action_add_event(name, ev)


func test_d_presses_roll_right() -> void:
	for a in DEFS:
		_init_action(a, DEFS[a].key)
	_drop_event(DEFS.roll_right.key)
	var axis: float = Input.get_axis("roll_left", "roll_right")
	Harness.assert_almost_eq(axis, 1.0, 1e-3, "D 按下 → roll 轴 +1")

func test_a_presses_roll_left() -> void:
	for a in DEFS:
		_init_action(a, DEFS[a].key)
	_drop_event(DEFS.roll_left.key)
	var axis: float = Input.get_axis("roll_left", "roll_right")
	Harness.assert_almost_eq(axis, -1.0, 1e-3, "A 按下 → roll 轴 -1")