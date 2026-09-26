extends SceneTree
func _initialize() -> void:
	print("VALIDATE_START")
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		printerr("FAIL: main.tscn null")
		quit(1)
		return
	var root = packed.instantiate()
	get_root().add_child(root)
	print("VALIDATE_INSTANCED")
	# wait frames for async setup
	for i in 120:
		await process_frame
	print("VALIDATE_DONE frames")
	quit(0)
