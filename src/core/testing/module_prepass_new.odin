package testing

import vault "../_vault"
import data  "../modules/data"
import math  "core:math/linalg/glsl"

prepass_run :: proc(scene : vault.Metadata) {
	scene_datapoint:= (^vault.DataPoint)(data.edit(scene))
	scene_field:= (^vault.Field)(data.edit(scene_datapoint.metadata))

	//debug_print(scene_datapoint)
	debug_print(scene_field)
} 