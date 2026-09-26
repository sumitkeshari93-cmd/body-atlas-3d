extends Node
class_name AnatomyCatalog
## Loads assets/catalog.json and resolves mesh names to student-friendly info.

var _entries: Dictionary = {}

func _ready() -> void:
	_load()

func _load() -> void:
	var path := "res://assets/catalog.json"
	if not FileAccess.file_exists(path):
		push_warning("catalog.json missing")
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_entries = parsed

func lookup(mesh_name: String) -> Dictionary:
	if _entries.has(mesh_name):
		return _entries[mesh_name]
	# Strip Godot / Blender suffixes
	var key := mesh_name
	for suffix in [".001", ".002", ".003", ".004", ".l", ".r", "_l", "_r"]:
		if key.ends_with(suffix):
			key = key.substr(0, key.length() - suffix.length())
			if _entries.has(key):
				return _entries[key]
			if _entries.has(key + ".001"):
				return _entries[key + ".001"]
	# Fuzzy: find entry whose key is contained / contains
	var low := mesh_name.to_lower()
	for k in _entries.keys():
		if str(k).to_lower() == low:
			return _entries[k]
	return _fallback(mesh_name)

func _fallback(mesh_name: String) -> Dictionary:
	var cleaned := mesh_name.replace(".", " ").replace("_", " ").strip_edges()
	cleaned = cleaned.replace(" 001", "").replace(" 002", "")
	var layer := "unknown"
	var low := cleaned.to_lower()
	if "muscle" in low or "musculus" in low:
		layer = "muscle"
	elif "bone" in low or "vertebra" in low or "cartilage" in low:
		layer = "bone"
	elif low.begins_with("heart") or low.begins_with("lung") or low in ["liver", "stomach", "brain"]:
		layer = "organ"
	elif "skin" in low:
		layer = "skin"
	var system := {
		"muscle": "Muscular system — contracts to produce movement and posture.",
		"bone": "Skeletal system — support, protection, and mineral storage.",
		"organ": "Visceral organ — specialized tissue performing vital functions.",
		"skin": "Integumentary system — barrier, sensation, and temperature control.",
		"connective": "Connective / accessory tissue supporting nearby structures.",
		"unknown": "Anatomical structure from the Z-Anatomy body model."
	}
	return {
		"common": cleaned.capitalize(),
		"anatomical": cleaned,
		"layer": layer,
		"note": system.get(layer, system["unknown"]),
		"wiki": ""
	}

func count() -> int:
	return _entries.size()
