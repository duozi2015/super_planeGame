# res://scripts/core/flight_model.gd
## T5 — 飞行模型核心。纯逻辑 RefCounted，无节点依赖，可无头单测。
##
## 结构：
##  1) 气流角（α/β）→ 气动系数 → 机体力（升/阻/侧）+
##     推力 + 重力(世界) → 世界合力 → 积分平移（真实能量/失速/G）
##  2) 操纵走 rate-based 飞控增稳：杆量 → 目标角速度 → 平滑趋近 →
##     积分姿态（好调手感，抗数值发散）
##  3) 计算 G 载荷、黑视/红视、失速标志，供 HUD/特效消费
##
## 坐标约定（机体系）：+Z=机头前、+X=右翼、+Y=升力方向。
## 注：state/inputs 保持非类型化，因 FlightState/ControlInputs 为
##     class_name 但无头下类缓存未注册，类型化访问会被静态检查拒绝。

class_name FlightModel
extends RefCounted

const FS = preload("res://scripts/core/flight_state.gd")
const AERO = preload("res://scripts/core/aero.gd")
const ATM = preload("res://scripts/core/atmosphere.gd")

const GRAVITY := 9.81

var state = FS.new()

# —— 本次 step 的痕迹值（快照用） ——
var stall := false
var stall_intensity := 0.0
var blackout_intensity := 0.0
var redout_intensity := 0.0
var trim_elevator := 0.0      # 配平升降舵偏置（-1..1），杆量叠加其上

var _alpha := 0.0
var _beta := 0.0
var _speed := 0.0
var _q := 0.0
var _g_vert := 0.0


func step(inputs, dt: float) -> void:
	var p: Dictionary = AERO.PARAMS
	var st = state
	var speed: float = st.speed_ms()
	var v_body: Vector3 = st.basis.inverse() * st.velocity
	var alpha: float = atan2(-v_body.y, v_body.z)  # 抬头为正
	var beta: float = atan2(v_body.x, v_body.z)    # 右侧来流为正
	var q: float = ATM.dynamic_pressure(st.position.y, speed)

	var cl_val: float = AERO.cl(alpha)
	var cd_val: float = AERO.cd(alpha, cl_val)
	var cy_val: float = AERO.cy(beta)

	# —— 合力（机体系） ——
	var thrust: float = (p.afb_thrust if inputs.afterburner else p.max_thrust) * clampf(inputs.throttle, 0.0, 1.0)
	var s: float = p.wing_area
	var body_force := Vector3(
		q * s * cy_val,          # 侧力 +X
		q * s * cl_val,          # 升力 +Y
		thrust - q * s * cd_val  # 推力 +Z − 阻力 −Z
	)

	var world_force: Vector3 = st.basis * body_force + Vector3(0.0, -p.mass * GRAVITY, 0.0)
	var accel: Vector3 = world_force / p.mass
	st.step(dt, accel)

	# —— 操纵（舵面气动力矩） ——
	_apply_surfaces(inputs, speed, alpha, beta, q, dt, p)

	# —— 状态回写 ——
	st.throttle = clampf(inputs.throttle, 0.0, 1.0)
	st.afterburner = inputs.afterburner

	# —— 标志位与痕迹 ——
	_g_vert = (world_force.y + p.mass * GRAVITY) / (p.mass * GRAVITY)  # 非重力垂向分量 / 重力
	blackout_intensity = clampf((_g_vert - p.g_positive) / 2.0, 0.0, 1.0)
	redout_intensity = clampf((p.g_negative - _g_vert) / 2.0, 0.0, 1.0)

	var alpha_deg: float = rad_to_deg(alpha)
	var overshoot: float = maxf(alpha_deg - rad_to_deg(float(p.stall_alpha)), 0.0) / 15.0
	var low_speed: float = clampf((float(p.stall_speed) - speed) / float(p.stall_speed), 0.0, 1.0) if speed < float(p.stall_speed) else 0.0
	stall_intensity = clampf(maxf(overshoot, low_speed), 0.0, 1.0)
	stall = stall_intensity > 0.01

	_alpha = alpha
	_beta = beta
	_speed = speed
	_q = q


## 舵面气动力矩模型：杆量 → 舵面偏转 → 力矩系数(静稳定+舵面+阻尼)
## → 力矩(动压×面积×参考长) → 分轴角加速度 → 积分姿态。
## 舵效随动压自然变化（低速/失速时失效），G 与能量均由物理涌现。
func _apply_surfaces(inputs, speed: float, alpha: float, beta: float, q: float, dt: float, p: Dictionary) -> void:
	var c: float = float(p.mac)
	var b: float = float(p.span)
	var vchar := maxf(speed, 10.0)   # 阻尼分母防低速发散
	var qS := q * float(p.wing_area)

	var auth := 1.0 - float(p.stab_loss_at_stall) * stall_intensity
	var de: float = clampf(inputs.pitch, -1.0, 1.0) + trim_elevator  # 升降舵（配平偏置叠加）
	var da: float = clampf(inputs.roll, -1.0, 1.0) * auth            # 副翼
	var dr: float = clampf(inputs.yaw, -1.0, 1.0) * auth             # 方向舵

	# 俯仰：零攻角力矩 + 静稳定(α>0→低头恢复) + 升降舵(拉杆→抬头) + 阻尼
	var cm_pitch: float = float(p.cm0) + float(p.cm_alpha) * alpha * auth - float(p.cm_de) * de * auth
	# 横滚：侧滑耦合 + 副翼。roll=+1(D) → 机背朝 +X = 右滚（从机尾看右翼下沉）
	var cl_roll: float = float(p.cl_beta) * beta - float(p.cl_da) * da
	# 偏航：侧滑静稳定 + 方向舵 + 阻尼
	var cn_yaw: float = float(p.cn_beta) * beta + float(p.cn_dr) * dr

	cm_pitch -= float(p.cm_damp) * (state.angular_velocity.x * c / (2.0 * vchar))
	cl_roll -= float(p.clp_damp) * (state.angular_velocity.z * b / (2.0 * vchar))
	cn_yaw -= float(p.cnr_damp) * (state.angular_velocity.y * b / (2.0 * vchar))

	var m_x := qS * c * cm_pitch   # 俯仰力矩（绕 X）
	var m_y := qS * b * cn_yaw     # 偏航力矩（绕 Y）
	var m_z := qS * b * cl_roll    # 滚转力矩（绕 Z）
	var ang_accel := Vector3(
		m_x / float(p.i_pitch),
		m_y / float(p.i_yaw),
		m_z / float(p.i_roll)
	)
	state.angular_velocity += ang_accel * dt

	var dv: Vector3 = state.angular_velocity * dt
	if dv.length() > 1e-9:
		# 显式右乘 = 机体系积分。Basis.rotated() 在此版本是左乘(世界系)，
		# 会导致"右滚90°后拉杆仍往世界正上方爬升"的错误。
		state.basis = state.basis * Basis(dv.normalized(), dv.length())
	state.normalize_basis()


func get_debug_snapshot() -> Dictionary:
	return {
		"speed_ms": _speed,
		"ias_ms": _speed * sqrt(ATM.density(state.position.y) / ATM.RHO0),
		"altitude_m": state.position.y,
		"alpha_deg": rad_to_deg(_alpha),
		"beta_deg": rad_to_deg(_beta),
		"load_factor": _g_vert,
		"blackout_intensity": blackout_intensity,
		"redout_intensity": redout_intensity,
		"stall": stall,
		"stall_intensity": stall_intensity,
		"trim_elevator": trim_elevator,
		"dynamic_pressure": _q,
		"throttle": state.throttle,
		"afterburner": state.afterburner,
	}