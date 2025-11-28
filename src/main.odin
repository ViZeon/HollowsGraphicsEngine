package main

import "core/imports/imports_vendor"
import "core/imports/imports_local"


import window "core/modules/window"
import render "core/modules/render"


WINDOW_WIDTH_PERCENT :: 0.7
WINDOW_HEIGHT_PERCENT :: 0.8
SCALE_FACTOR :: 100.0

main :: proc() {
	APPWINDOW := window.window_create(WINDOW_WIDTH_PERCENT,WINDOW_HEIGHT_PERCENT)
	render.render()
}