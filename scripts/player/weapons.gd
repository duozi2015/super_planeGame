# res://scripts/player/weapons.gd
## 玩家武器挂载：挂在 Player 下的 Node。
## 持有 WeaponSystem（纯逻辑）+ 机炮射线命中 + 导弹追踪命中 + 干扰弹视觉。

extends Node

const WeaponSystem = preload("res://scripts/core/weapon_system.gd")

var ws = WeaponSystem.new()

var _target_node: Node3D = null

const GUN_DAMAGE := 8.0
const MISSILE_DAMAGE := 80.0
const GUN_RANGE := 2600.0
const GUN_SPREAD := 0.006   # rad
const TRACER_LIFETIME := 0.08  # 曳光线持续秒数

var _shots: Array = []       # 每发导弹：{state, target, visual}
var _tracers: Array = []     # 每道曳光线：{visual, life}


func _physics_process(delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null:
		return
	_pick_target(body)
	var fwd: Vector3 = body.global_basis * Vector3(0, 0, 1)
	ws.update(delta, body.global_position, fwd, _target_data())
	_handle_input(body, fwd)
	_update_shots(delta)
	_update_tracers(delta)


func _pick_target(body: Node3D) -> void:
	var best: Node3D = null
	var best_score := INF
	var fwd: Vector3 = body.global_basis * Vector3(0, 0, 1)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var to: Vector3 = e.global_position - body.global_position
		var ang: float = rad_to_deg(fwd.normalized().angle_to(to.normalized()))
		if ang > 70.0:
			continue
		var score: float = to.length() + ang * 40.0
		if score < best_score:
			best_score = score
			best = e
	_target_node = best


func _target_data() -> Dictionary:
	if is_instance_valid(_target_node):
		var alive: bool = not ( _target_node.has_method("is_dead") and _target_node.is_dead() )
		return {"position": _target_node.global_position, "velocity": _target_node.linear_velocity, "alive": alive}
	return {"position": Vector3.ZERO, "velocity": Vector3.ZERO, "alive": false}


func _handle_input(body: Node3D, fwd: Vector3) -> void:
	if Input.is_action_pressed("fire_guns"):
		_fire_guns(body, fwd)
	if Input.is_action_just_pressed("fire_missile"):
		_fire_missile(body, fwd)
	if Input.is_action_just_pressed("deploy_flare"):
		ws.deploy_flare()
	if Input.is_action_just_pressed("deploy_chaff"):
		ws.deploy_chaff()


func _fire_guns(body: Node3D, fwd: Vector3) -> void:
	if not ws.try_fire_guns():
		return
	# 命中检测：带散布的射线（从模型机炮挂点发射，跟随真实机头）
	var spread := GUN_SPREAD
	var axis := fwd.cross(Vector3.UP)
	if axis.length() < 1e-4:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var dir := fwd.rotated(axis, randf_range(-spread, spread))
	dir = dir.rotated(fwd, randf_range(-spread, spread))
	var from := _muzzle_pos(body, fwd)
	var space := body.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * GUN_RANGE)
	var hit := space.intersect_ray(q)
	if hit and hit.collider is Node and hit.collider.is_in_group("enemies"):
		hit.collider.take_damage(GUN_DAMAGE)
	_var_tracer(from, hit.position if hit else from + dir * GUN_RANGE)


## 取机炮挂点（Model/GunMuzzleL 或 R）的全局位置；无挂点则退到机头前方
func _muzzle_pos(body: Node3D, fwd: Vector3) -> Vector3:
	var model := body.get_node_or_null("Model")
	if model != null:
		for mn in ["GunMuzzleL", "GunMuzzleR"]:
			var m3 := model.get_node_or_null(mn)
			if m3 is Marker3D:
				return (m3 as Marker3D).global_position
	return body.global_position + fwd * 4.0


## 生成一道曳光线（机头 → 终点），短暂显示后自动销毁
func _var_tracer(a: Vector3, b: Vector3) -> void:
	var line := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
	line.mesh = im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 3.0
	line.material_override = mat
	add_child(line)
	line.global_position = Vector3.ZERO  # ImmediateMesh 顶点已是世界坐标
	_tracers.append({"visual": line, "life": TRACER_LIFETIME})


func _fire_missile(body: Node3D, fwd: Vector3) -> void:
	if not is_instance_valid(_target_node):
		return
	if not ws.try_fire_missile(body.global_position, fwd):
		return
	var m = ws.missiles.pop_back()
	# 视觉：小球代表导弹
	var visual := MeshInstance3D.new()
	visual.mesh = SphereMesh.new()
	visual.mesh.radius = 0.5
	visual.mesh.height = 1.0
	visual.mesh.material = StandardMaterial3D.new()
	visual.mesh.material.albedo_color = Color(1.0, 0.9, 0.4)
	add_child(visual)
	visual.global_position = m.position
	_shots.append({"state": m, "target": _target_node, "visual": visual})
	_target_node.missile_incoming = true


func _update_shots(delta: float) -> void:
	var keep: Array = []
	for rec in _shots:
		var m = rec.state
		var tgt: Node3D = rec.target
		var done := false
		if is_instance_valid(tgt):
			var tdata := {
				"position": tgt.global_position,
				"velocity": tgt.linear_velocity,
				"alive": not ( tgt.has_method("is_dead") and tgt.is_dead() ),
			}
			m.update(delta, tdata)
			if m.hit:
				tgt.take_damage(MISSILE_DAMAGE)
				tgt.missile_incoming = false
				done = true
			elif m.expired:
				tgt.missile_incoming = false
				done = true
		else:
			done = true
		if rec.visual is Node3D and is_instance_valid(rec.visual):
			rec.visual.global_position = m.position
			if done:
				rec.visual.queue_free()
		if not done:
			keep.append(rec)
	_shots = keep


## 回收过期曳光线
func _update_tracers(delta: float) -> void:
	var keep: Array = []
	for tr in _tracers:
		tr.life -= delta
		var vis: Node3D = tr.visual
		if is_instance_valid(vis):
			if tr.life > 0.0:
				keep.append(tr)
			else:
				vis.queue_free()
	_tracers = keep


## 返回当前锁定的目标节点（可为空），供 HUD 标记 Locked。
func get_target() -> Node3D:
	return _target_node


func get_state() -> Dictionary:
	var st: Dictionary = ws.get_state()
	st["player_hp"] = get_parent().get_snapshot().player_hp if get_parent().has_method("get_snapshot") else 0.0
	return st