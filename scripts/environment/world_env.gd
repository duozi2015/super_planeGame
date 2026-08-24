# res://scripts/environment/world_env.gd
## 世界环境加载器：在运行时把天空/雾等环境资源挂到 WorldEnvironment 上。
## 便于在纯代码里维护环境资源，避免手写 .tscn 的大段序列化。

extends WorldEnvironment

func _ready() -> void:
	environment = load("res://environments/sky_env.tres")