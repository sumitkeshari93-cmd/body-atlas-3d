extends Node3D
class_name ProceduralOrgans
## Procedural organs layer: heart (cutaway chambers) + stylized lungs/liver/stomach/kidneys/brain.

signal part_ready(heart_pos: Vector3)

var heart_root: Node3D
var _cutaway := false
var _shell_mats: Array[BaseMaterial3D] = []
var _chamber_labels: Array[Label3D] = []
var _parts: Dictionary = {} # name -> MeshInstance3D

func build(body_aabb: AABB) -> void:
	# Clear previous
	for c in get_children():
		c.queue_free()
	_parts.clear()
	_shell_mats.clear()
	_chamber_labels.clear()

	var center := body_aabb.get_center()
	var size := body_aabb.size
	# Approximate anatomical positions relative to body AABB (Y-up, model may vary)
	var chest := Vector3(center.x - size.x * 0.02, center.y + size.y * 0.18, center.z + size.z * 0.05)
	var head := Vector3(center.x, body_aabb.position.y + size.y * 0.92, center.z)
	var abdomen := Vector3(center.x, center.y - size.y * 0.05, center.z + size.z * 0.02)

	heart_root = _build_heart(chest, size.y * 0.055)
	add_child(heart_root)

	_add_organ("Brain", head, Vector3(size.x * 0.22, size.y * 0.08, size.z * 0.22), Color(0.95, 0.75, 0.78))
	_add_organ("LungLeft", chest + Vector3(-size.x * 0.12, size.y * 0.02, 0), Vector3(size.x * 0.14, size.y * 0.16, size.z * 0.12), Color(0.85, 0.55, 0.6))
	_add_organ("LungRight", chest + Vector3(size.x * 0.14, size.y * 0.02, 0), Vector3(size.x * 0.15, size.y * 0.17, size.z * 0.12), Color(0.85, 0.55, 0.6))
	_add_organ("Liver", abdomen + Vector3(size.x * 0.08, -size.y * 0.02, 0), Vector3(size.x * 0.22, size.y * 0.08, size.z * 0.14), Color(0.55, 0.2, 0.18))
	_add_organ("Stomach", abdomen + Vector3(-size.x * 0.06, -size.y * 0.04, size.z * 0.02), Vector3(size.x * 0.12, size.y * 0.07, size.z * 0.1), Color(0.85, 0.55, 0.4))
	_add_organ("KidneyLeft", abdomen + Vector3(-size.x * 0.12, -size.y * 0.08, -size.z * 0.05), Vector3(size.x * 0.06, size.y * 0.07, size.z * 0.05), Color(0.7, 0.35, 0.35))
	_add_organ("KidneyRight", abdomen + Vector3(size.x * 0.12, -size.y * 0.08, -size.z * 0.05), Vector3(size.x * 0.06, size.y * 0.07, size.z * 0.05), Color(0.7, 0.35, 0.35))

	part_ready.emit(heart_root.global_position if heart_root.is_inside_tree() else chest)

func heart_position() -> Vector3:
	if heart_root:
		return heart_root.global_position
	return global_position

func set_cutaway(enabled: bool) -> void:
	_cutaway = enabled
	for m in _shell_mats:
		if m:
			m.albedo_color.a = 0.18 if enabled else 0.92
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if enabled else BaseMaterial3D.TRANSPARENCY_DISABLED
	for lab in _chamber_labels:
		lab.visible = enabled
	# Hide/show chamber meshes always visible when cutaway
	for key in ["HeartRA", "HeartLA", "HeartRV", "HeartLV", "HeartTricuspid", "HeartMitral", "HeartAortic", "HeartPulmonary"]:
		if _parts.has(key):
			_parts[key].visible = true

func is_cutaway() -> bool:
	return _cutaway

func get_pickable_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for v in _parts.values():
		out.append(v)
	return out

func _add_organ(part_name: String, pos: Vector3, extents: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.scale = extents
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.05
	mi.material_override = mat
	add_child(mi)
	_parts[part_name] = mi
	return mi

func _build_heart(pos: Vector3, scale_ref: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Heart"
	root.position = pos
	root.scale = Vector3.ONE * maxf(scale_ref, 0.04)

	# Outer myocardium (slightly tilted heart-like ellipsoid)
	var shell := MeshInstance3D.new()
	shell.name = "HeartShell"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.2
	sm.radial_segments = 24
	sm.rings = 12
	shell.mesh = sm
	shell.scale = Vector3(0.85, 1.0, 0.7)
	shell.rotation_degrees = Vector3(0, 0, -15)
	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.75, 0.15, 0.2, 0.92)
	shell_mat.roughness = 0.4
	shell.material_override = shell_mat
	_shell_mats.append(shell_mat)
	root.add_child(shell)
	_parts["HeartShell"] = shell

	# Four chambers inside
	_add_chamber(root, "HeartRA", Vector3(0.35, 0.35, 0.15), 0.38, Color(0.55, 0.75, 0.95), "RA")
	_add_chamber(root, "HeartLA", Vector3(-0.35, 0.35, 0.15), 0.36, Color(0.95, 0.55, 0.55), "LA")
	_add_chamber(root, "HeartRV", Vector3(0.32, -0.35, 0.1), 0.42, Color(0.4, 0.65, 0.95), "RV")
	_add_chamber(root, "HeartLV", Vector3(-0.28, -0.4, 0.05), 0.48, Color(0.9, 0.3, 0.35), "LV")

	# Valves as thin discs
	_add_valve(root, "HeartTricuspid", Vector3(0.32, 0.05, 0.12), Color(0.9, 0.85, 0.5), "Tri")
	_add_valve(root, "HeartMitral", Vector3(-0.3, 0.02, 0.1), Color(0.9, 0.85, 0.5), "Mit")
	_add_valve(root, "HeartAortic", Vector3(-0.15, 0.55, -0.05), Color(0.95, 0.7, 0.3), "Ao")
	_add_valve(root, "HeartPulmonary", Vector3(0.15, 0.55, -0.05), Color(0.7, 0.85, 0.95), "Pul")

	# Great vessels stubs
	_add_vessel_stub(root, Vector3(0, 1.1, -0.1), Vector3(0.18, 0.55, 0.18), Color(0.8, 0.2, 0.25))
	_add_vessel_stub(root, Vector3(0.25, 1.0, -0.15), Vector3(0.14, 0.45, 0.14), Color(0.45, 0.55, 0.85))

	return root

func _add_chamber(parent: Node3D, part_name: String, pos: Vector3, radius: float, color: Color, label: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mi.material_override = mat
	parent.add_child(mi)
	_parts[part_name] = mi
	var lab := Label3D.new()
	lab.text = label
	lab.font_size = 48
	lab.pixel_size = 0.004
	lab.position = pos + Vector3(0, 0, radius + 0.05)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = Color(1, 1, 1, 0.95)
	lab.visible = false
	parent.add_child(lab)
	_chamber_labels.append(lab)

func _add_valve(parent: Node3D, part_name: String, pos: Vector3, color: Color, label: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.05
	mesh.radial_segments = 12
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	_parts[part_name] = mi
	var lab := Label3D.new()
	lab.text = label
	lab.font_size = 36
	lab.pixel_size = 0.0035
	lab.position = pos + Vector3(0, 0.15, 0.15)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.visible = false
	parent.add_child(lab)
	_chamber_labels.append(lab)

func _add_vessel_stub(parent: Node3D, pos: Vector3, scl: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
