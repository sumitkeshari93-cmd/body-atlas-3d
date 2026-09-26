extends Node3D
## Body Atlas 3D — main wiring.

@onready var orbit: OrbitCamera = $OrbitRig
@onready var camera: Camera3D = $OrbitRig/Camera3D
@onready var body: BodyController = $Body
@onready var catalog: AnatomyCatalog = $Catalog
@onready var ui: CanvasLayer = $UI
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _tap_pos := Vector2.ZERO
var _tap_time := 0.0
var _moved := false
var _heart_focused := false
var _ready_ok := false

func _ready() -> void:
	ui.set_loading(true, "Loading Z-Anatomy body.glb…")
	ui.layer_chosen.connect(_on_layer)
	ui.focus_heart.connect(_on_focus_heart)
	ui.go_inside.connect(_on_go_inside)
	ui.body_overview.connect(_on_overview)
	ui.hotspot.connect(_on_hotspot)
	ui.close_info.connect(func(): body.clear_highlight())
	body.catalog = catalog
	body.loaded.connect(_on_loaded)
	body.part_selected.connect(_on_part)
	body.heart_ready.connect(func(p): body.heart_pos = p)
	await body.setup(catalog)

func _on_loaded(total: int, muscles: int, bones: int) -> void:
	_ready_ok = true
	ui.set_loading(false)
	ui.set_status("Meshes %d · Muscles %d · Bones %d · Drag to orbit · Pinch zoom" % [total, muscles, bones])
	var c: Vector3 = body.body_aabb.get_center()
	var h: float = body.body_aabb.size.y
	if orbit.has_method("reset_view"):
		orbit.reset_view(c, h)
	# Start on Skin layer
	body.set_layer(0, true)
	ui.highlight_layer(0)

func _on_part(info: Dictionary, _mesh: MeshInstance3D) -> void:
	ui.show_part(info)

func _on_layer(i: int) -> void:
	body.set_layer(i, false)
	ui.set_status("Layer: %s" % ["Skin", "Muscle", "Organs", "Skeleton"][i])

func _on_focus_heart() -> void:
	_heart_focused = true
	body.set_layer(2, false) # organs
	ui.highlight_layer(2)
	if orbit.has_method("focus_on"):
		orbit.focus_on(body.heart_pos, 0.55, 0.75)
	ui.set_status("Heart focus — tap chambers or Go Inside")

func _on_go_inside() -> void:
	if not _heart_focused:
		_on_focus_heart()
	var on: bool = body.toggle_heart_cutaway()
	if orbit.has_method("focus_on"):
		orbit.focus_on(body.heart_pos, 0.35 if on else 0.55, 0.5)
	ui.set_status("Heart cutaway ON — RA/LA/RV/LV" if on else "Heart exterior")

func _on_overview() -> void:
	_heart_focused = false
	if body.organs.has_method("set_cutaway"):
		body.organs.set_cutaway(false)
	body.set_layer(0, false)
	ui.highlight_layer(0)
	var c: Vector3 = body.body_aabb.get_center()
	var h: float = body.body_aabb.size.y
	if orbit.has_method("reset_view"):
		orbit.reset_view(c, h)
	ui.set_status("Body overview")

func _on_hotspot(name: String) -> void:
	var aabb: AABB = body.body_aabb
	var c: Vector3 = aabb.get_center()
	var s: Vector3 = aabb.size
	var targets := {
		"Brain": Vector3(c.x, aabb.position.y + s.y * 0.92, c.z),
		"Lungs": Vector3(c.x, c.y + s.y * 0.18, c.z),
		"Heart": body.heart_pos,
		"Digestion": Vector3(c.x, c.y - s.y * 0.05, c.z),
		"Kidney": Vector3(c.x, c.y - s.y * 0.1, c.z - s.z * 0.05),
	}
	body.set_layer(2, false)
	ui.highlight_layer(2)
	var p: Vector3 = targets.get(name, c)
	if name == "Heart":
		_heart_focused = true
	if orbit.has_method("focus_on"):
		orbit.focus_on(p, 0.7 if name != "Heart" else 0.55, 0.7)
	ui.set_status("Focus: %s" % name)

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_ok:
		return
	# Tap detection: short touch without much drag
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_tap_pos = st.position
			_tap_time = Time.get_ticks_msec() / 1000.0
			_moved = false
		else:
			var dt := Time.get_ticks_msec() / 1000.0 - _tap_time
			if not _moved and dt < 0.35 and st.position.distance_to(_tap_pos) < 18.0:
				_do_pick(st.position)
	elif event is InputEventScreenDrag:
		if (event as InputEventScreenDrag).relative.length() > 10.0:
			_moved = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if not _moved:
				_do_pick(mb.position)
			_moved = false
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_tap_pos = mb.position
			_moved = false
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if (event as InputEventMouseMotion).relative.length() > 8.0:
			_moved = true

func _do_pick(screen_pos: Vector2) -> void:
	# Ignore taps on UI rects roughly (top/bottom bars)
	var vp := get_viewport().get_visible_rect().size
	if screen_pos.y < 110.0 or screen_pos.y > vp.y - 120.0:
		return
	body.pick_at(camera, screen_pos)
