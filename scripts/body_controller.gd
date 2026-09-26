extends Node3D
class_name BodyController
## Loads body.glb, classifies muscle/bone meshes, drives layer peel + picking.

signal loaded(mesh_count: int, muscle_count: int, bone_count: int)
signal part_selected(info: Dictionary, mesh: MeshInstance3D)
signal heart_ready(pos: Vector3)

const BODY_PATH := "res://assets/models/body.glb"

enum Layer { SKIN = 0, MUSCLE = 1, ORGANS = 2, SKELETON = 3 }

var catalog: AnatomyCatalog
var layer: int = Layer.SKIN
var body_aabb := AABB()
var heart_pos := Vector3(0, 1.1, 0.1)

var _body_root: Node3D
var _muscles: Array[MeshInstance3D] = []
var _bones: Array[MeshInstance3D] = []
var _connective: Array[MeshInstance3D] = []
var _all_meshes: Array[MeshInstance3D] = []
var _mat_cache: Dictionary = {} # mesh -> StandardMaterial3D (override)
var _orig_albedo: Dictionary = {}
var _highlight: MeshInstance3D
var _highlight_mat: StandardMaterial3D
var _layer_tween: Tween

@onready var skin: SkinShell = $SkinShell
@onready var organs: ProceduralOrgans = $Organs
@onready var model_host: Node3D = $ModelHost

func setup(cat: Node) -> void:
	catalog = cat
	await _load_body()
	_classify()
	_compute_aabb()
	if skin.has_method("build"):
		skin.build(body_aabb)
	if organs.has_method("build"):
		organs.build(body_aabb)
		if organs.has_method("heart_position"):
			heart_pos = organs.heart_position()
	heart_ready.emit(heart_pos)
	_apply_layer(layer, true)
	loaded.emit(_all_meshes.size(), _muscles.size(), _bones.size())

func set_layer(new_layer: int, animate: bool = true) -> void:
	layer = clampi(new_layer, 0, 3)
	_apply_layer(layer, not animate)

func peel_deeper() -> void:
	set_layer(mini(layer + 1, 3))

func peel_shallower() -> void:
	set_layer(maxi(layer - 1, 0))

func toggle_heart_cutaway() -> bool:
	if organs.has_method("is_cutaway"):
		var next: bool = not organs.is_cutaway()
		organs.set_cutaway(next)
		return next
	return false

func clear_highlight() -> void:
	if _highlight and _mat_cache.has(_highlight):
		var m: StandardMaterial3D = _mat_cache[_highlight]
		if _orig_albedo.has(_highlight):
			m.albedo_color = _orig_albedo[_highlight]
			m.emission_enabled = false
	_highlight = null

func pick_at(camera: Camera3D, screen_pos: Vector2) -> void:
	var candidates := _visible_pick_meshes()
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var best: MeshInstance3D = null
	var best_d := INF
	for mi in candidates:
		if mi == null or not is_instance_valid(mi) or not mi.is_visible_in_tree():
			continue
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		var hit: float = _ray_aabb(from, dir, aabb)
		if hit < 0.0:
			continue
		# Prefer triangle hit when mesh is small enough
		var tri_d: float = _ray_mesh(from, dir, mi)
		var d: float = tri_d if tri_d >= 0.0 else hit
		if d < best_d:
			best_d = d
			best = mi
	if best:
		_select(best)

func _select(mi: MeshInstance3D) -> void:
	clear_highlight()
	_highlight = mi
	var mat: StandardMaterial3D = _ensure_mat(mi)
	_orig_albedo[mi] = mat.albedo_color
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.25)
	mat.emission_energy_multiplier = 0.85
	var info: Dictionary = catalog.lookup(mi.name) if catalog else {}
	if info.is_empty():
		info = {"common": mi.name, "anatomical": mi.name, "layer": "unknown", "note": "", "wiki": ""}
	part_selected.emit(info, mi)

func _visible_pick_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	match layer:
		Layer.SKIN:
			if skin.has_method("get_pickable_meshes"):
				out.append_array(skin.get_pickable_meshes())
			out.append_array(_muscles) # allow pick-through faint muscles if any visible
		Layer.MUSCLE:
			out.append_array(_muscles)
			out.append_array(_connective)
		Layer.ORGANS:
			if organs.has_method("get_pickable_meshes"):
				out.append_array(organs.get_pickable_meshes())
			out.append_array(_muscles)
		Layer.SKELETON:
			out.append_array(_bones)
			if organs.has_method("get_pickable_meshes"):
				out.append_array(organs.get_pickable_meshes())
	return out

func _load_body() -> void:
	var scene: PackedScene = load(BODY_PATH)
	if scene == null:
		push_error("Failed to load body.glb")
		return
	_body_root = scene.instantiate()
	_body_root.name = "BodyModel"
	model_host.add_child(_body_root)
	# Normalize orientation / scale if needed
	await get_tree().process_frame

func _classify() -> void:
	_muscles.clear()
	_bones.clear()
	_connective.clear()
	_all_meshes.clear()
	_walk(_body_root)

func _walk(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		_all_meshes.append(mi)
		_ensure_mat(mi)
		var info: Dictionary = catalog.lookup(mi.name) if catalog else {}
		var layer_name := str(info.get("layer", ""))
		var low := mi.name.to_lower()
		if layer_name == "muscle" or "muscle" in low or "musculus" in low:
			_muscles.append(mi)
			_tint(mi, Color(0.78, 0.28, 0.28))
		elif layer_name == "bone" or _looks_bone(low):
			_bones.append(mi)
			_tint(mi, Color(0.92, 0.9, 0.82))
		else:
			_connective.append(mi)
			_tint(mi, Color(0.75, 0.7, 0.65))
	for c in n.get_children():
		_walk(c)

func _looks_bone(low: String) -> bool:
	for k in ["bone", "vertebra", "femur", "tibia", "fibula", "ulna", "radius", "humer", "scapula", "pelvis", "sternum", "clavicle", "cranium", "skull", "mandib", "patella", "talus", "calcane", "metacar", "metatar", "phalanx", "carpal", "tarsal", "ilium", "ischium", "pubis", "sacrum", "coccyx", "atlas", "hyoid", "cartilage", "tooth", "incisor", "molar", "rib", "costal", "xiphoid", "maxilla", "occipital", "parietal", "frontal", "temporal", "sphenoid"]:
		if k in low:
			return true
	return false

func _ensure_mat(mi: MeshInstance3D) -> StandardMaterial3D:
	if _mat_cache.has(mi):
		return _mat_cache[mi]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.55
	mat.metallic = 0.0
	# Try preserve existing albedo if any
	var existing := mi.get_active_material(0)
	if existing is StandardMaterial3D:
		mat.albedo_color = (existing as StandardMaterial3D).albedo_color
	elif existing is BaseMaterial3D:
		mat.albedo_color = (existing as BaseMaterial3D).albedo_color
	else:
		mat.albedo_color = Color(0.8, 0.5, 0.45)
	mi.material_override = mat
	_mat_cache[mi] = mat
	_orig_albedo[mi] = mat.albedo_color
	return mat

func _tint(mi: MeshInstance3D, color: Color) -> void:
	var mat := _ensure_mat(mi)
	mat.albedo_color = color
	_orig_albedo[mi] = color

func _compute_aabb() -> void:
	var first := true
	var acc := AABB()
	for mi in _all_meshes:
		var a: AABB = mi.global_transform * mi.get_aabb()
		if first:
			acc = a
			first = false
		else:
			acc = acc.merge(a)
	if first:
		acc = AABB(Vector3(-0.4, 0, -0.2), Vector3(0.8, 1.8, 0.4))
	body_aabb = acc

func _apply_layer(l: int, instant: bool) -> void:
	# Target alphas
	var skin_a := 0.0
	var muscle_a := 0.0
	var organ_vis := false
	var bone_a := 0.0
	var peel := 0.0
	match l:
		Layer.SKIN:
			skin_a = 0.82
			muscle_a = 0.0
			organ_vis = false
			bone_a = 0.0
		Layer.MUSCLE:
			skin_a = 0.0
			muscle_a = 1.0
			organ_vis = false
			bone_a = 0.0
			peel = 0.0
		Layer.ORGANS:
			skin_a = 0.0
			muscle_a = 0.22
			organ_vis = true
			bone_a = 0.0
			peel = 0.55
		Layer.SKELETON:
			skin_a = 0.0
			muscle_a = 0.0
			organ_vis = true
			bone_a = 1.0
			peel = 1.0
	_set_group_alpha(_muscles, muscle_a, instant)
	_set_group_alpha(_connective, muscle_a * 0.8, instant)
	_set_group_alpha(_bones, bone_a, instant)
	if skin.has_method("set_alpha"):
		skin.set_alpha(skin_a)
	if skin.has_method("peel_aside"):
		skin.peel_aside(peel)
	if organs:
		organs.visible = organ_vis
	# Peel muscles aside on deeper layers (Dare-MSA style)
	_peel_meshes(_muscles, peel if l >= Layer.ORGANS else 0.0, instant)

func _set_group_alpha(arr: Array[MeshInstance3D], a: float, instant: bool) -> void:
	for mi in arr:
		var mat := _ensure_mat(mi)
		var col: Color = _orig_albedo.get(mi, mat.albedo_color)
		col.a = a
		if a <= 0.01:
			mi.visible = false
		else:
			mi.visible = true
			if a < 0.99:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if instant:
				mat.albedo_color = col
			else:
				mat.albedo_color = col

func _peel_meshes(arr: Array[MeshInstance3D], amount: float, _instant: bool) -> void:
	# Move outer muscle meshes outward from body center
	var center := body_aabb.get_center()
	for mi in arr:
		if not mi.has_meta("home_origin"):
			mi.set_meta("home_origin", mi.global_position)
		var home: Vector3 = mi.get_meta("home_origin")
		var outward := home - center
		outward.y *= 0.15
		if outward.length_squared() < 1e-6:
			outward = Vector3(1, 0, 0)
		var dest := home + outward.normalized() * (amount * 0.35)
		mi.global_position = dest if amount > 0.01 else home

func _ray_aabb(origin: Vector3, dir: Vector3, aabb: AABB) -> float:
	# Kay–Kajiya slab method; returns distance or -1
	var inv := Vector3(
		1.0 / dir.x if absf(dir.x) > 1e-8 else 1e8,
		1.0 / dir.y if absf(dir.y) > 1e-8 else 1e8,
		1.0 / dir.z if absf(dir.z) > 1e-8 else 1e8
	)
	var t0 := (aabb.position - origin) * inv
	var t1 := (aabb.position + aabb.size - origin) * inv
	var tmin := Vector3(minf(t0.x, t1.x), minf(t0.y, t1.y), minf(t0.z, t1.z))
	var tmax := Vector3(maxf(t0.x, t1.x), maxf(t0.y, t1.y), maxf(t0.z, t1.z))
	var t_enter := maxf(tmin.x, maxf(tmin.y, tmin.z))
	var t_exit := minf(tmax.x, minf(tmax.y, tmax.z))
	if t_exit < t_enter or t_exit < 0.0:
		return -1.0
	return maxf(t_enter, 0.0)

func _ray_mesh(origin: Vector3, dir: Vector3, mi: MeshInstance3D) -> float:
	if mi.mesh == null:
		return -1.0
	var best := -1.0
	# Limit faces for perf on dense meshes
	for s in range(mi.mesh.get_surface_count()):
		var arrays := mi.mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var xform := mi.global_transform
		if indices:
			var n: int = mini(indices.size(), 12000)
			var i := 0
			while i + 2 < n:
				var a: Vector3 = xform * verts[indices[i]]
				var b: Vector3 = xform * verts[indices[i + 1]]
				var c: Vector3 = xform * verts[indices[i + 2]]
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, dir, a, b, c)
				if hit != null:
					var d: float = origin.distance_to(hit)
					if best < 0.0 or d < best:
						best = d
				i += 3
		else:
			var n2: int = mini(verts.size(), 12000)
			var j := 0
			while j + 2 < n2:
				var a2: Vector3 = xform * verts[j]
				var b2: Vector3 = xform * verts[j + 1]
				var c2: Vector3 = xform * verts[j + 2]
				var hit2: Variant = Geometry3D.ray_intersects_triangle(origin, dir, a2, b2, c2)
				if hit2 != null:
					var d2: float = origin.distance_to(hit2)
					if best < 0.0 or d2 < best:
						best = d2
				j += 3
	return best
