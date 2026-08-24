# res://scripts/hud/attitude.gd
## 姿态仪（现代 ADI 人工地平线）：半透明天地(蓝上/橙下) + 网格地平线，
## 现代机身符号、两侧滚动俯仰刻度条+游标、顶部滚转指针、失速/高G红边告警。
## 挂方形 Control 且 clip_contents=true。由 hud.gd 每帧 set_attitude/set_alarm 驱动。
extends Control

# —— 科技感配色（冷蓝霓虹・机械） ——
const C_SKY := Color(0.13, 0.42, 0.85, 0.5)      # 天 半透明
const C_GROUND := Color(0.92, 0.55, 0.12, 0.42)  # 地 半透明
const C_GRID := Color(0.7, 0.9, 1.0, 0.35)       # 网格地平线
const C_UI := Color(0.5, 0.83, 1.0)              # HUD 主蓝（漓光）
const C_UI_BRIGHT := Color(0.8, 0.94, 1.0, 0.95)
const C_UI_DIM := Color(0.4, 0.65, 0.9, 0.5)
const C_ALARM := Color(1.0, 0.25, 0.2)           # 告警红

const PX_PER_DEG := 3.0       # 每度俯仰像素
const PITCH_SPAN_DEG := 30.0  # 俯仰标尺显示范围（±）

var _pitch := 0.0    # 度，抬头为正
var _roll := 0.0     # 度，右滚为正
var _alarm := false  # 失速或高G告警
var _t := 0.0


func set_attitude(pitch_deg: float, roll_deg: float) -> void:
	_pitch = pitch_deg
	_roll = roll_deg
	queue_redraw()


func set_alarm(stall: bool, high_g: bool) -> void:
	_alarm = stall or high_g
	if _alarm:
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _alarm:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var cy := h * 0.5
	var dy := -_pitch * PX_PER_DEG
	var roll_r := deg_to_rad(_roll)
	var xw := w * 0.5

	# —— 半透明天地（绕中心旋转 roll，俯仰平移分界线） ——
	draw_set_transform(Vector2(cx, cy), -roll_r, Vector2.ONE)
	var sky := Rect2(-xw, -h, 2.0 * xw, h + dy)
	var ground := Rect2(-xw, dy, 2.0 * xw, h)
	draw_rect(sky, C_SKY, true)
	draw_rect(ground, C_GROUND, true)
	# 网格地平线：每 10° 一条，随 roll 一起旋转
	for deg_val in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		var yy: float = dy + deg_val * PX_PER_DEG
		draw_line(Vector2(-xw, yy), Vector2(xw, yy), C_GRID, 1.0)
	# 分界线（亮线）
	draw_line(Vector2(-xw, dy), Vector2(xw, dy), C_UI_BRIGHT, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# —— 现代机身符号（机翼 + 前向中心线 + 中心点亮，固定） ——
	var sy := cy + 12.0
	draw_line(Vector2(cx, sy - 22.0), Vector2(cx, sy - 6.0), C_UI_BRIGHT, 2.0)
	draw_line(Vector2(cx, sy + 4.0), Vector2(cx, sy + 20.0), C_UI_BRIGHT, 2.0)
	var wing := 40.0
	draw_line(Vector2(cx - wing, sy), Vector2(cx + wing, sy), C_UI_BRIGHT, 2.5)
	draw_line(Vector2(cx - wing, sy), Vector2(cx - wing - 8.0, sy - 8.0), C_UI_BRIGHT, 2.0)
	draw_line(Vector2(cx + wing, sy), Vector2(cx + wing + 8.0, sy - 8.0), C_UI_BRIGHT, 2.0)
	draw_circle(Vector2(cx, sy), 2.5, C_UI_BRIGHT)

	# —— 两侧滚动俯仰刻度条（不随 roll）；游标三角固定在中心指示当前俯仰 ——
	var bar_l := 14.0
	var bar_r := w - 14.0
	for deg_val in range(-PITCH_SPAN_DEG, PITCH_SPAN_DEG + 1, 5):
		var off: float = (float(deg_val) - _pitch) * PX_PER_DEG
		if absf(off) > 90.0:
			continue
		var major := int(deg_val) % 10 == 0
		var len: float = 12.0 if major else 6.0
		var width: float = 1.5 if major else 1.0
		draw_line(Vector2(bar_l - len, cy + off), Vector2(bar_l, cy + off), C_UI, width)
		draw_line(Vector2(bar_r, cy + off), Vector2(bar_r + len, cy + off), C_UI, width)
	_draw_cursor_tri(Vector2(bar_l, cy), true)
	_draw_cursor_tri(Vector2(bar_r, cy), false)

	# —— 顶部滚转指针弧 ——
	_draw_roll_indicator(cx)

	# —— 表盘边框（亮蓝 + 外圈漓光） ——
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), C_UI, false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), C_UI_DIM, false, 4.0)

	# —— 失速/高G 告警：红边闪烁 ——
	if _alarm:
		var blink := 0.5 + 0.5 * sin(_t * 12.0)
		var col := Color(C_ALARM.r, C_ALARM.g, C_ALARM.b, 0.35 + 0.65 * blink)
		draw_rect(Rect2(3.0, 3.0, w - 6.0, h - 6.0), col, false, 4.0)


## 俯仰标尺游标三角：固定中心，left=true 指向右
func _draw_cursor_tri(pos: Vector2, left: bool) -> void:
	var sgn: float = -1.0 if left else 1.0
	var tri := PackedVector2Array([
		pos,
		pos + Vector2(sgn * 8.0, -5.0),
		pos + Vector2(sgn * 8.0, 5.0),
	])
	draw_colored_polygon(tri, C_UI_BRIGHT)


## 顶部滚转指示：半圆弧刻度（±45°）+ 随滚转摆动的三角指针 + 中央基准线
func _draw_roll_indicator(cx: float) -> void:
	var top_y := 24.0
	var r := 34.0
	var center := Vector2(cx, top_y)
	# 刻度弧
	for deg_val in [-45, -30, -15, 0, 15, 30, 45]:
		var a := deg_to_rad(float(deg_val))
		draw_line(center + Vector2(sin(a), -cos(a)) * (r - 6.0), center + Vector2(sin(a), -cos(a)) * r, C_UI, 1.5)
	# 滚转指针：尖端朝上指向 -roll
	var ra := -deg_to_rad(_roll)
	var tip := center + Vector2(sin(ra), -cos(ra)) * (r + 3.0)
	var base1 := center + Vector2(sin(ra + 0.5), -cos(ra + 0.5)) * (r - 16.0)
	var base2 := center + Vector2(sin(ra - 0.5), -cos(ra - 0.5)) * (r - 16.0)
	draw_colored_polygon(PackedVector2Array([tip, base1, base2]), C_UI_BRIGHT)
	# 中央基准线
	draw_line(center + Vector2(0, r + 6.0), center + Vector2(0, r + 16.0), C_UI_BRIGHT, 2.0)
