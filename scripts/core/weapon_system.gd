# res://scripts/core/weapon_system.gd
## 玩家武器系统（纯逻辑可测）：机炮热量/弹量、导弹锁定进程、
## 导弹发射与追踪、热焰/铝箔。命中判定在场景层做射线/命中体。
## 目标以 Dictionary 传入：{position: Vector3, velocity: Vector3, alive: bool}

class_name WeaponSystem
extends RefCounted

const MissileState = preload("res://scripts/core/missile.gd")

enum LockPhase { NONE, SEARCHING, LOCKED }

const GUN_RATE := 15.0        # 发/秒
const GUN_HEAT_PER_SHOT := 0.05
const GUN_HEAT_COOL := 0.25   # 冷却速率 /s
const GUN_OVERHEAT := 1.0     # 过热阈值
const GUN_RESET := 0.6        # 过热后冷却到此值才可再射
const LOCK_FOV_DEG := 45.0    # 锁定视野半角
const LOCK_RANGE := 7000.0    # 最大锁定距离 m
const LOCK_TIME := 0.9        # 建立锁定所需时间 s
const LOCK_DROP := 0.35       # 保持锁定所需的最低质量
const MISSILE_MAX := 4
const CM_COOLDOWN := 1.5      # 干扰弹共用冷却 s

var gun_ammo := 300
var gun_heat := 0.0
var gun_overheated := false
var gun_shot_timer := 0.0

var missile_count := MISSILE_MAX
var lock_phase := LockPhase.NONE
var lock_progress := 0.0
var missiles: Array = []

var flare_count := 30
var chaff_count := 20
var cm_cooldown := 0.0


func update(delta: float, launcher_pos: Vector3, launcher_fwd: Vector3, target: Dictionary) -> void:
	gun_shot_timer = maxf(gun_shot_timer - delta, 0.0)
	if gun_heat > 0.0:
		gun_heat = maxf(gun_heat - GUN_HEAT_COOL * delta, 0.0)
		if gun_overheated and gun_heat <= GUN_RESET:
			gun_overheated = false
	cm_cooldown = maxf(cm_cooldown - delta, 0.0)

	_update_lock(delta, launcher_pos, launcher_fwd, target)

	var still: Array = []
	for m in missiles:
		m.update(delta, target)
		if not m.is_done():
			still.append(m)
	missiles = still


func _update_lock(delta: float, pos: Vector3, fwd: Vector3, target: Dictionary) -> void:
	var t_pos: Vector3 = target.position
	var alive: bool = target.alive
	var to_t: Vector3 = t_pos - pos
	var dist := to_t.length()
	var q := 0.0
	if alive and dist > 10.0 and dist < LOCK_RANGE:
		var angle_deg := rad_to_deg(fwd.normalized().angle_to(to_t / dist))
		if angle_deg <= LOCK_FOV_DEG:
			q = (1.0 - angle_deg / LOCK_FOV_DEG) * (1.0 - dist / LOCK_RANGE)

	if lock_phase == LockPhase.LOCKED:
		lock_progress = clampf(lock_progress + (1.0 if q > LOCK_DROP else -0.8) * delta / LOCK_TIME, 0.0, 1.0)
		if lock_progress <= 0.0:
			lock_phase = LockPhase.NONE
	else:
		lock_progress = clampf(lock_progress + (q - 0.15) * delta / LOCK_TIME, 0.0, 1.0)
		if lock_progress >= 1.0:
			lock_phase = LockPhase.LOCKED


func can_fire_guns() -> bool:
	return not gun_overheated and gun_ammo > 0 and gun_shot_timer <= 0.0


func try_fire_guns() -> bool:
	if not can_fire_guns():
		return false
	gun_ammo -= 1
	gun_heat += GUN_HEAT_PER_SHOT
	if gun_heat >= GUN_OVERHEAT:
		gun_heat = GUN_OVERHEAT
		gun_overheated = true
	gun_shot_timer = 1.0 / GUN_RATE
	return true


func is_locked() -> bool:
	return lock_phase == LockPhase.LOCKED


func try_fire_missile(from: Vector3, dir: Vector3) -> bool:
	if missile_count <= 0 or not is_locked():
		return false
	missile_count -= 1
	var m = MissileState.new()
	m.launch(from, dir)
	missiles.append(m)
	return true


func deploy_flare() -> bool:
	if flare_count <= 0 or cm_cooldown > 0.0:
		return false
	flare_count -= 1
	cm_cooldown = CM_COOLDOWN
	return true


func deploy_chaff() -> bool:
	if chaff_count <= 0 or cm_cooldown > 0.0:
		return false
	chaff_count -= 1
	cm_cooldown = CM_COOLDOWN
	return true


func get_state() -> Dictionary:
	return {
		"gun_ammo": gun_ammo,
		"gun_heat": gun_heat,
		"gun_overheated": gun_overheated,
		"missiles": missile_count,
		"lock_phase": lock_phase,
		"lock_progress": lock_progress,
		"flares": flare_count,
		"chaff": chaff_count,
		"missiles_in_flight": missiles.size(),
	}