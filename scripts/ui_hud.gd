extends CanvasLayer
## Layer chips, info panel, hotspots, heart controls, credits.

signal layer_chosen(layer: int)
signal focus_heart
signal go_inside
signal body_overview
signal hotspot(name: String)
signal show_credits
signal close_info

@onready var layer_bar: HBoxContainer = $Root/TopBar/VBox/LayerBar
@onready var info_panel: PanelContainer = $Root/InfoPanel
@onready var info_common: Label = $Root/InfoPanel/Margin/VBox/CommonName
@onready var info_anat: Label = $Root/InfoPanel/Margin/VBox/AnatName
@onready var info_note: Label = $Root/InfoPanel/Margin/VBox/Note
@onready var status: Label = $Root/Status
@onready var credits: PanelContainer = $Root/Credits
@onready var loading: ColorRect = $Root/Loading

var _layer_btns: Array[Button] = []
var _layer_names := ["Skin", "Muscle", "Organs", "Skeleton"]

func _ready() -> void:
	info_panel.visible = false
	credits.visible = false
	var root := $Root
	root.get_node("TopBar/VBox/TitleRow/CreditsBtn").pressed.connect(_on_credits)
	root.get_node("BottomBar/VBox/Actions/FocusHeart").pressed.connect(_on_focus_heart)
	root.get_node("BottomBar/VBox/Actions/GoInside").pressed.connect(_on_go_inside)
	root.get_node("BottomBar/VBox/Actions/Overview").pressed.connect(_on_overview)
	for hs in ["Brain","Lungs","Heart","Digestion","Kidney"]:
		root.get_node("BottomBar/VBox/Hotspots/%s" % hs).pressed.connect(_on_hotspot.bind(hs))
	root.get_node("InfoPanel/Margin/VBox/CloseInfo").pressed.connect(_on_close_info)
	root.get_node("Credits/Margin/VBox/CloseCredits").pressed.connect(_on_close_credits)
	for i in _layer_names.size():
		var b := Button.new()
		b.text = _layer_names[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_layer.bind(i))
		layer_bar.add_child(b)
		_layer_btns.append(b)
	_highlight_layer(0)

func set_loading(v: bool, msg: String = "Loading 3D anatomy…") -> void:
	loading.visible = v
	status.text = msg if v else ""

func set_status(msg: String) -> void:
	status.text = msg

func highlight_layer(i: int) -> void:
	_highlight_layer(i)

func show_part(info: Dictionary) -> void:
	info_panel.visible = true
	info_common.text = str(info.get("common", "Structure"))
	info_anat.text = str(info.get("anatomical", ""))
	var note := str(info.get("note", ""))
	var layer := str(info.get("layer", ""))
	if layer != "":
		note = "[%s] %s" % [layer.capitalize(), note]
	info_note.text = note

func hide_part() -> void:
	info_panel.visible = false

func _highlight_layer(i: int) -> void:
	for idx in _layer_btns.size():
		_layer_btns[idx].button_pressed = (idx == i)

func _on_layer(i: int) -> void:
	_highlight_layer(i)
	layer_chosen.emit(i)

func _on_focus_heart() -> void:
	focus_heart.emit()

func _on_go_inside() -> void:
	go_inside.emit()

func _on_overview() -> void:
	body_overview.emit()

func _on_hotspot(n: String) -> void:
	hotspot.emit(n)

func _on_credits() -> void:
	credits.visible = not credits.visible
	show_credits.emit()

func _on_close_info() -> void:
	hide_part()
	close_info.emit()

func _on_close_credits() -> void:
	credits.visible = false
