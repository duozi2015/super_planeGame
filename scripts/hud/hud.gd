# res://scripts/hud/hud.gd
## HUD 科技感（冷蓝霓虹・机械）：
##   姿态仪（中下方现代 ADI）+ 敌机红三角/锁定追踪框 + 两侧空速/高度滚动刻条 + 四角装饰框。
## 姿态从玩家 global_basis 实时计算；敌机用相机 unproject 投影；告警连 stall/G。
extends Control

# —— 科技感配色（冷蓝霓虹・机械） ——
const C_UI := Color(0.55, 0.85, 1.0)             # 主 HUD 蓝
const C_UI_BRIGHT := Color(0.88, 0.96, 1.0, 0.95)
const C_UI_DIM := Color(0.4, 0.65, 0.9, 0.4)
const C_FILL := Color(0.45, 0.85, 1.0, 0.5)      # 条填充
const C_ENEMY := Color(0.95, 0.2, 0.15)          # 敌机红
const C_LOCK := Color(1.0, 0.55, 0.15)           # 锁定橙红

const SPD_MAX := 380.0    # 空速满量程 m/s
const ALT_MAX := 5000.0   # 高度满量程 m
const TAPE_SPAN := 0.22   # 滚动条视窗 = 满量程比例
const ATT_SIZE := 220.0   # 姿态仪边长 px

@onready var _attitude: Control = $Attitude


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	_update_attitude_layout()
	queue_redraw()


func _update_attitude_layout() -> void:
	var s := size
	_attitude.size = Vector2(ATT_SIZE, ATT_SIZE)
	_attitude.position = Vector2((s.x - ATT_SIZE) * 0.5, s.y * 0.72 - ATT_SIZE * 0.5)


func _draw() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var snap: Dictionary = p.get_snapshot()

	# 姿态仪驱动 + 告警
	var att: Vector2 = _pitch_roll(p)
	_attitude.set_attitude(att.x, att.y)
	var stall: bool = bool(snap.get("stall", false))
	var high_g: bool = float(snap.get("load_factor", 0.0)) > 8.0
	_attitude.set_alarm(stall, high_g)

	_draw_corner_frame()
	_draw_enemy_markers(cam, p)
	_draw_speed_tape(snap)
	_draw_alt_tape(snap)


## 从玩家 global_basis 提取 (pitch, roll) 度。机头 +Z。
func _pitch_roll(p) -> Vector2:
	var b: Basis = p.global_basis
	var fwd: Vector3 = b * Vector3(0, 0, 1)
	var up: Vector3 = b * Vector3(0, 1, 0)
	var pitch: float = rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))
	var roll: float = rad_to_deg(atan2(up.x, up.y))
	return Vector2(pitch, roll)


## 四角机械装饰框：淡蓝 L 形角框 + 内缩斜切短线（驾驶舱边框观感）
func _draw_corner_frame() -> void:
	var m := 16.0
	var l := 40.0
	var s := size
	var corners := [
		[Vector2(m, m), Vector2(1, 1)],
		[Vector2(s.x - m, m), Vector2(-1, 1)],
		[Vector2(m, s.y - m), Vector2(1, -1)],
		[Vector2(s.x - m, s.y - m), Vector2(-1, -1)],
	]
	for c in corners:
		var base: Vector2 = c[0]
		var d: Vector2 = c[1]
		draw_line(base, base + Vector2(d.x * l, 0.0), C_UI, 2.0)
		draw_line(base, base + Vector2(0.0, d.y * l), C_UI, 2.0)
		var inset := Vector2(d.x * 10.0, d.y * 10.0)
		draw_line(base + inset, base + inset + Vector2(d.x * 6.0, 0.0), C_UI_BRIGHT, 1.5)
		draw_line(base + inset, base + inset + Vector2(0.0, d.y * 6.0), C_UI_BRIGHT, 1.5)


## 敌机标记：红三角投影；锁定目标加橙红追踪框(SR)
func _draw_enemy_markers(cam, p) -> void:
	var wp: Node = p.get_node_or_null("Weapons")
	var target: Node3D = wp.get_target() if wp != null and wp.has_method("get_target") else null
	var locked: bool = wp != null and wp.has_method("is_locked") and wp.is_locked()
	var font := ThemeDB.fallback_font

	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var s: Vector2 = cam.unproject_position(e.global_position)
		var on_screen := s.x >= 0.0 and s.x <= size.x and s.y >= 0.0 and s.y <= size.y
		var mark: Vector2 = s
		if not on_screen:
			mark = _clamp_to_edge(s)
		_draw_triangle(mark, C_ENEMY)
		if locked and target != null and e == target:
			_draw_lock_box(mark)
			draw_string(font, mark + Vector2(-40.0, -30.0), "Locked", HORIZONTAL_ALIGNMENT_CENTER, 80, 16, C_LOCK)


func _clamp_to_edge(s: Vector2) -> Vector2:
	var m := 30.0
	return Vector2(clampf(s.x, m, size.x - m), clampf(s.y, m, size.y - m))


func _draw_triangle(pos: Vector2, col: Color) -> void:
	var r := 13.0
	var tri := PackedVector2Array([
		pos + Vector2(0, -r),
		pos + Vector2(r, r * 0.6),
		pos + Vector2(-r, r * 0.6),
	])
	draw_colored_polygon(tri, col)


## 锁定追踪框：围绕敌机的橙红四角矩形（SR 框）
func _draw_lock_box(pos: Vector2) -> void:
	var w := 46.0
	var h := 30.0
	var bl := pos - Vector2(w * 0.5, h * 0.5) + Vector2(0, 12.0)
	var c := 7.0
	var pts := [bl, bl + Vector2(w, 0), bl + Vector2(w, h), bl + Vector2(0, h)]
	var corners_tl := [pts[0], Vector2(pts[0].x + c, pts[0].y), Vector2(pts[0].x, pts[0].y + c)]
	var corners_tr := [pts[1], Vector2(pts[1].x - c, pts[1].y), Vector2(pts[1].x, pts[1].y + c)]
	var corners_br := [pts[2], Vector2(pts[2].x - c, pts[2].y), Vector2(pts[2].x, pts[2].y - c)]
	var corners_bl := [pts[3], Vector2(pts[3].x + c, pts[3].y), Vector2(pts[3].x, pts[3].y - c)]
	for tri_pts in [corners_tl, corners_tr, corners_br, corners_bl]:
		draw_polyline(tri_pts, C_LOCK, 2.0, true)


func _draw_speed_tape(snap: Dictionary) -> void:
	var x := 38.0
	var top := 150.0
	var bot := size.y - 150.0
	var spd: float = float(snap.get("speed_ms", 0.0))
	_draw_tape(x, top, bot, spd, SPD_MAX, 10.0, "%d", "SPD")


func _draw_alt_tape(snap: Dictionary) -> void:
	var w := 26.0
	var x := size.x - 38.0 - w
	var top := 150.0
	var bot := size.y - 150.0
	var alt: float = float(snap.get("altitude_m", 0.0))
	_draw_tape(x, top, bot, alt, ALT_MAX, 150.0, "%d", "ALT")


## 两侧图形滚动刻条：轨道 + 滚动刻度 + 数字 + 中心游标
func _draw_tape(x: float, top: float, bot: float, value: float, vmax: float, step: float, fmt: String, _tag: String) -> void:
	var span := vmax * TAPE_SPAN
	var px_per_unit := (bot - top) / span
	var cy := (top + bot) * 0.5
	var font := ThemeDB.fallback_font
	var w := 24.0

	# 轨道（细线）
	draw_line(Vector2(x + w * 0.5, top - 8.0), Vector2(x + w * 0.5, bot + 8.0), C_UI_DIM, 1.5)

	# 滚动刻度：以 value 为中心的视窗
	var lo := int(floor((value - span) / step)) * int(step)
	var hi := int(ceil((value + span) / step)) * int(step)
	var unit := float(lo)
	while unit <= float(hi):
		var off: float = (unit - value) * px_per_unit
		var yy := cy + off
		if yy < top - 12.0 or yy > bot + 12.0:
			unit += step
			continue
		var major := absf(fmod(unit, step * 2.0)) < 0.01
		var len: float = 9.0 if major else 5.0
		var wdt: float = 1.5 if major else 1.0
		var lcol := C_UI if major else C_UI_DIM
		draw_line(Vector2(x + w, yy), Vector2(x + w + len, yy), lcol, wdt)
		draw_line(Vector2(x, yy), Vector2(x - len, yy), lcol, wdt)
		if major:
			draw_string(font, Vector2(x - len - 40.0, yy + 4.0), fmt % int(unit), HORIZONTAL_ALIGNMENT_RIGHT, 40, 11, C_UI)
			draw_string(font, Vector2(x + w + len + 3.0, yy + 4.0), fmt % int(unit), HORIZONTAL_ALIGNMENT_LEFT, 40, 11, C_UI)
		unit += step

	# 中心游标三角（左右各一，指向刻度带中心）
	for sx in [x, x + w]:
		var dir: float = -1.0 if sx == x else 1.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(sx, cy), Vector2(sx + dir * 7.0, cy - 5.0), Vector2(sx + dir * 7.0, cy + 5.0),
		]), C_UI_BRIGHT)

	# 底部淡化填充：指示当前值相对满量程
	var frac := clampf(value / vmax, 0.0, 1.0)
	var cy_fill := lerpf(bot, top, frac)
	if cy_fill <= cy:
		draw_rect(Rect2(x, cy_fill, w, cy - cy_fill), C_FILL, true)

	# 顶/底标签
	draw_string(font, Vector2(x, top - 16.0), _tag, HORIZONTAL_ALIGNMENT_CENTER, w, 11, C_UI_DIM)
