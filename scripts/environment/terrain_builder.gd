# res://scripts/environment/terrain_builder.gd
## 地景构建器：运行时空地创建大地平面（可见地表/地平线参考）+ 火箭发射塔目标。
## 挂在主场景的一个 Node3D（"Terrain"）上。

extends Node3D

const TERRAIN_SIZE := 20000.0      # 地平面边长（米），保证高空可见地平线
const GRID_STEP := 1000.0          # 参考网格间距（辅助判断距离/速度）
const TOWER_MODELS := [
	"res://assets/models/props/rocket_baseA.glb",
	"res://assets/models/props/rocket_baseB.glb",
]


func _ready() -> void:
	_build_groud_plane()
	_spawn_towers()


func _build_groud_plane() -> void:
	# 主体地平面
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TERRAIN_SIZE, TERRAIN_SIZE)
	# 地表材质
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.50, 0.42, 1.0)   # 低饱和绿（地形）
	mat.roughness = 1.0
	pm.material = mat
	plane.mesh = pm
	plane.position = Vector3(0, -2, 0)
	plane.rotation = Vector3(-PI / 2, 0, 0)  # 平放在 XZ 平面
	add_child(plane)

	# 参考网格线（深色细线，帮助感知高度/速度）
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var half := TERRAIN_SIZE / 2.0
	var g := 0.0
	while g <= TERRAIN_SIZE:
		var x := -half + g
		im.surface_add_vertex(Vector3(x, 0, -half))
		im.surface_add_vertex(Vector3(x, 0, half))
		im.surface_add_vertex(Vector3(-half, 0, x))
		im.surface_add_vertex(Vector3(half, 0, x))
		g += GRID_STEP
	im.surface_end()
	grid.mesh = im
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.albedo_color = Color(0.15, 0.17, 0.14, 1.0)
	grid.material_override = gmat
	grid.position = Vector3(0, -1.8, 0)
	add_child(grid)


func _spawn_towers() -> void:
	# 沿地图散布火箭发射塔（地面目标/参考物）
	var spots := [
		Vector3(-3000, 0, 2500), Vector3(2800, 0, -2200),
		Vector3(0, 0, 4500), Vector3(-3800, 0, -3500),
		Vector3(4200, 0, 1500),
	]
	var i := 0
	for s in spots:
		var scn: PackedScene = load(TOWER_MODELS[i % TOWER_MODELS.size()])
		if scn == null:
			i += 1
			continue
		var t: Node3D = scn.instantiate()
		t.name = "Tower%d" % i
		t.position = s
		t.scale = Vector3(2, 2, 2)
		add_child(t)
		i += 1