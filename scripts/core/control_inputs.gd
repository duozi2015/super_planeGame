# res://scripts/core/control_inputs.gd
## 操纵输入（归一化）：
##   pitch/roll/yaw  ∈ [-1, 1]
##   throttle       ∈ [0, 1]
##   afterburner    加力开关

class_name ControlInputs
extends RefCounted

var pitch := 0.0
var roll := 0.0
var yaw := 0.0
var throttle := 0.0
var afterburner := false