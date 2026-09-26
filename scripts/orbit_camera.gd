extends Node3D
class_name OrbitCamera
## Smooth orbit / pinch-zoom / two-finger pan for touch + mouse.

@export var target: Vector3 = Vector3(0, 1.0, 0)
@export var distance: float = 2.4
@export var min_distance: float = 0.25
@export var max_distance: float = 6.0
@export var yaw: float = 25.0
@export var pitch: float = 12.0
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0
@export var rotate_sens: float = 0.18
@export var zoom_sens: float = 0.004
@export var pan_sens: float = 0.0018
@export var smooth: float = 12.0

var _yaw: float
var _pitch: float
var _dist: float
var _target: Vector3
var _dragging := false
var _last_pos: Vector2
var _pinch_dist := -1.0
var _touches: Dictionary = {} # index -> position
var _enabled := true
var _focus_tween: Tween

@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	_yaw = yaw
	_pitch = pitch
	_dist = distance
	_target = target
	_apply(1.0)

func set_enabled(v: bool) -> void:
	_enabled = v

func focus_on(world_pos: Vector3, new_dist: float = 0.55, dur: float = 0.7) -> void:
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.tween_property(self, "_target", world_pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "_dist", clampf(new_dist, min_distance, max_distance), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func reset_view(body_center: Vector3, body_height: float) -> void:
	focus_on(body_center, clampf(body_height * 1.35, 1.6, 4.5), 0.6)
	_yaw = 25.0
	_pitch = 10.0

func _process(delta: float) -> void:
	_apply(clampf(smooth * delta, 0.0, 1.0))

func _apply(alpha: float) -> void:
	var rad_y := deg_to_rad(_yaw)
	var rad_p := deg_to_rad(_pitch)
	var offset := Vector3(
		_dist * cos(rad_p) * sin(rad_y),
		_dist * sin(rad_p),
		_dist * cos(rad_p) * cos(rad_y)
	)
	var desired := _target + offset
	global_position = global_position.lerp(desired, alpha)
	look_at(_target, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_dragging = true
				_last_pos = st.position
			elif _touches.size() >= 2:
				_dragging = false
				_pinch_dist = _touch_distance()
		else:
			_touches.erase(st.index)
			if _touches.size() < 2:
				_pinch_dist = -1.0
			if _touches.is_empty():
				_dragging = false
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			_handle_pinch_pan()
		elif _dragging:
			var d: Vector2 = sd.relative
			_yaw -= d.x * rotate_sens
			_pitch = clampf(_pitch + d.y * rotate_sens, min_pitch, max_pitch)
		return

	# Mouse fallback (desktop testing)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_last_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = clampf(_dist * 0.9, min_distance, max_distance)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = clampf(_dist * 1.1, min_distance, max_distance)
	elif event is InputEventMouseMotion and _dragging and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * rotate_sens
		_pitch = clampf(_pitch + mm.relative.y * rotate_sens, min_pitch, max_pitch)

func _touch_distance() -> float:
	var pts: Array = _touches.values()
	if pts.size() < 2:
		return 0.0
	return pts[0].distance_to(pts[1])

func _touch_mid() -> Vector2:
	var pts: Array = _touches.values()
	return (pts[0] + pts[1]) * 0.5

func _handle_pinch_pan() -> void:
	var d := _touch_distance()
	if _pinch_dist > 0.0:
		var ratio := d / maxf(_pinch_dist, 1.0)
		# pinch out -> zoom in
		_dist = clampf(_dist / ratio, min_distance, max_distance)
		# pan via mid-point delta approximated from relative
		var mid := _touch_mid()
		# use average relative of both fingers if available via last
		var pan := (mid - _last_pos) if _last_pos != Vector2.ZERO else Vector2.ZERO
		_last_pos = mid
		var right := camera.global_transform.basis.x
		var up := camera.global_transform.basis.y
		_target -= right * pan.x * pan_sens * _dist
		_target += up * pan.y * pan_sens * _dist
	else:
		_last_pos = _touch_mid()
	_pinch_dist = d
