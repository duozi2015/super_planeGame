# res://scripts/core/aero.gd
## T4 — 气动系数曲线与飞机常量表（集中一处，平衡改这里）。
## 纯静态函数，输入角度均为弧度。

class_name Aero
extends RefCounted

## 主战机参数表（v1 单机）——平衡/手感调整唯一入口
const PARAMS := {
	"mass": 12000.0,          # kg
	"wing_area": 27.5,        # m²
	"max_thrust": 70000.0,    # N 军用推力
	"afb_thrust": 110000.0,   # N 加力燃烧室
	"cd0": 0.02,              # 零升阻力系数
	"oswald_e": 0.8,          # 奥斯瓦尔德效率
	"aspect_ratio": 3.0,      # 展弦比
	"cl_max": 1.4,            # 最大升力系数
	"stall_alpha": 1.047,     # 失速迎角 60°（弧度）——几乎任意拉杆都不触发失速
	"alpha_lin": 0.785,       # 线性区上界 45°（弧度）
	"cl_alpha": 4.5,          # 线性区升力斜率 1/rad
	"cy_beta": 0.8,           # 侧滑侧力斜率 1/rad
	# —— 几何 / 惯量 ——
	"mac": 3.2,            # 平均气动弦长 m
	"span": 9.1,           # 翼展 m
	"i_roll": 18000.0,     # 滚转惯量 kg·m²（降低→急转弯更敏捷）
	"i_pitch": 90000.0,    # 俯仰惯量 kg·m²（降低→突然拉起响应更快）
	"i_yaw": 75000.0,      # 偏航惯量 kg·m²（降低→机头跟随更快）
	# —— 力矩系数：静稳定 / 舵面 / 阻尼 ——
	"cm0": 0.02,           # 零攻角俯仰力矩
	"cm_alpha": 0.5,       # 俯仰静稳定 1/rad（α>0 → 恢复低头）
	"cm_de": 0.4,          # 升降舵效力（单位杆量）
	"cm_damp": 40.0,       # 俯仰阻尼
	"cl_beta": 0.1,        # 横滚-侧滑耦合 1/rad
	"cl_da": 1.2,          # 副翼效力（单位杆量）
	"clp_damp": 12.0,      # 滚转阻尼
	"cn_beta": 0.15,       # 偏航静稳定 1/rad
	"cn_dr": 0.3,          # 方向舵效力（单位杆量）
	"cnr_damp": 30.0,      # 偏航阻尼
	"stab_loss_at_stall": 0.3,  # 失速时舵效/稳定性衰减比例（降低→失速仍可操控，不失控瘫掉）
	# —— 限制 ——
	"g_positive": 12.0,    # 正向过载上限 → 黑视（提高→允许更急的机动）
	"g_negative": -4.0,    # 负向过载下限 → 红视
	"stall_speed": 55.0,   # 低速失速参考 m/s（降低→低速机动不易骤失速）
}

## 升力系数曲线：线性区 → 失速后高斯衰减到下限。
static func cl(alpha: float, p: Dictionary = PARAMS) -> float:
	var av: float = absf(alpha)
	var a_lin: float = p.alpha_lin
	var a_stall: float = p.stall_alpha
	var cl_max: float = p.cl_max
	if av <= a_lin:
		return clampf(p.cl_alpha * alpha, -cl_max, cl_max)
	var overshoot: float = av - a_lin
	var k: float = 0.6 / pow(a_stall - a_lin, 2.0)
	var decayed: float = cl_max * exp(-k * overshoot * overshoot)
	var floor_val: float = 0.25 * cl_max
	var mag: float = maxf(decayed, floor_val)
	return clampf(signf(alpha) * mag, -cl_max, cl_max)

## 阻力系数：零升阻力 + 诱导阻力（与升力平方成正比）。
static func cd(alpha: float, cl_val: float, p: Dictionary = PARAMS) -> float:
	var k: float = 1.0 / (PI * float(p.oswald_e) * float(p.aspect_ratio))
	var induced: float = k * cl_val * cl_val
	# 失速/大攻角额外寄生阻力
	var extra: float = 0.0
	var av: float = absf(alpha)
	if av > float(p.alpha_lin):
		extra = 0.05 * pow(av - float(p.alpha_lin), 2.0)
	return p.cd0 + induced + extra

## 侧滑侧力系数（β>0 → 侧力向左为负）。
static func cy(beta: float, p: Dictionary = PARAMS) -> float:
	return -p.cy_beta * beta