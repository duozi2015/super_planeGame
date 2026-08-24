# res://scripts/core/damage.gd
## 损伤模型：血量 + 结构损伤度（影响操控/外观）。

class_name DamageModel
extends RefCounted

var max_hp := 100.0
var hp := 100.0


func take_damage(amount: float) -> void:
	hp = maxf(hp - amount, 0.0)


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)


func is_dead() -> bool:
	return hp <= 0.0


## 0=完好, 1=彻底损毁（供操控降级/外观）
func degradation() -> float:
	return 1.0 - hp / max_hp