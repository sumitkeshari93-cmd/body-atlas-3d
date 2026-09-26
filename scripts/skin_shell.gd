extends Node3D
class_name SkinShell
## Semi-opaque stylized humanoid skin that peels/fades to reveal muscles.

var _meshes: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _base_alpha := 0.78

func build(body_aabb: AABB) -> void:
	for c in get_children():
		c.queue_free()
	_meshes.clear()
	_mats.clear()

	var c := body_aabb.get_center()
	var s := body_aabb.size
	# Slightly larger than body so it wraps outside muscles
	var pad := Vector3(s.x * 0.08, s.y * 0.02, s.z * 0.1)

	# Torso
	_capsule("SkinTorso", c + Vector3(0, s.y * 0.02, 0), Vector3(s.x * 0.55 + pad.x, s.y * 0.42, s.z * 0.5 + pad.z))
	# Head
	_sphere("SkinHead", Vector3(c.x, body_aabb.position.y + s.y * 0.92, c.z), Vector3(s.x * 0.28, s.y * 0.1, s.z * 0.28))
	# Arms
	_capsule("SkinArmL", Vector3(c.x - s.x * 0.42, c.y + s.y * 0.08, c.z), Vector3(s.x * 0.12, s.y * 0.32, s.z * 0.12))
	_capsule("SkinArmR", Vector3(c.x + s.x * 0.42, c.y + s.y * 0.08, c.z), Vector3(s.x * 0.12, s.y * 0.32, s.z * 0.12))
	# Legs
	_capsule("SkinLegL", Vector3(c.x - s.x * 0.14, c.y - s.y * 0.32, c.z), Vector3(s.x * 0.16, s.y * 0.38, s.z * 0.16))
	_capsule("SkinLegR", Vector3(c.x + s.x * 0.14, c.y - s.y * 0.32, c.z), Vector3(s.x * 0.16, s.y * 0.38, s.z * 0.16))

func set_alpha(a: float) -> void:
	for m in _mats:
		m.albedo_color.a = a
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	visible = a > 0.02

func peel_aside(amount: float) -> void:
	# Slide left/right halves apart slightly
	var i := 0
	for mi in _meshes:
		var side := -1.0 if i % 2 == 0 else 1.0
		mi.position.x = mi.get_meta("home_x", mi.position.x) + side * amount * 0.25
		i += 1

func get_pickable_meshes() -> Array[MeshInstance3D]:
	# Expose one representative for picking -> SkinShell catalog entry
	var out: Array[MeshInstance3D] = []
	if _meshes.size() > 0:
		# Rename first for catalog
		_meshes[0].name = "SkinShell"
		out.append(_meshes[0])
	return out

func _capsule(n: String, pos: Vector3, extents: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.5
	mi.mesh = mesh
	mi.position = pos
	mi.scale = extents
	mi.set_meta("home_x", pos.x)
	_apply_mat(mi)
	add_child(mi)
	_meshes.append(mi)

func _sphere(n: String, pos: Vector3, extents: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mi.mesh = mesh
	mi.position = pos
	mi.scale = extents
	mi.set_meta("home_x", pos.x)
	_apply_mat(mi)
	add_child(mi)
	_meshes.append(mi)

func _apply_mat(mi: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.72, 0.62, _base_alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.65
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mi.material_override = mat
	_mats.append(mat)
