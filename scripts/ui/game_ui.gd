class_name GameUi
extends CanvasLayer

const TEXT := Color("e8f0f4")
const MUTED := Color("a9bbc4")
const ACCENT := Color("57d9f5")
const PANEL := Color("0b151e")
const PANEL_LIGHT := Color("132631")

@export var input_router_path: NodePath = NodePath("../InputRouter")

@onready var input_router: InputRouter = get_node_or_null(input_router_path) as InputRouter

var loading_screen: Control
var loading_status: Label
var game_view: Control
var hint_row: HBoxContainer
var controls_button: Button
var controls_overlay: Control
var controls_tabs: TabContainer
var return_button: Button

func _ready() -> void:
	layer = 10
	_build_loading_screen()
	_build_game_view()
	_build_controls_overlay()
	if input_router == null:
		_show_loading_error("Ошибка: InputRouter не найден")
		return
	input_router.set_enabled(false)
	input_router.modal_cancel_requested.connect(close_controls)
	call_deferred("_complete_loading_when_ready")

func _complete_loading_when_ready() -> void:
	# Wait for the first tree frame so the loading state can be presented while initialization completes.
	await get_tree().process_frame
	if input_router == null:
		_show_loading_error("Ошибка: система ввода недоступна")
		return
	loading_status.text = "Готово"
	game_view.show()
	loading_screen.hide()
	input_router.set_enabled(true)

func open_controls() -> void:
	if input_router == null or loading_screen.visible:
		return
	controls_overlay.show()
	input_router.set_modal_ui_active(true)
	return_button.grab_focus()

func close_controls() -> void:
	if not is_instance_valid(controls_overlay) or not controls_overlay.visible:
		return
	if input_router != null:
		input_router.set_modal_ui_active(false)
	controls_overlay.hide()
	controls_button.grab_focus()

func is_controls_open() -> bool:
	return is_instance_valid(controls_overlay) and controls_overlay.visible

func _show_loading_error(message: String) -> void:
	loading_status.text = message
	loading_status.add_theme_color_override("font_color", Color("ff9d9d"))

func _build_loading_screen() -> void:
	loading_screen = _full_screen_control("LoadingScreen", Control.MOUSE_FILTER_STOP)
	add_child(loading_screen)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.01, 0.03, 0.05, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(dimmer)
	loading_screen.add_child(dimmer)

	var center := CenterContainer.new()
	_fill(center)
	center.offset_left = 28.0
	center.offset_top = 28.0
	center.offset_right = -28.0
	center.offset_bottom = -28.0
	loading_screen.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440.0, 250.0)
	card.add_theme_stylebox_override("panel", _style(PANEL, 12, Color("2b4554"), 1))
	center.add_child(card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.add_theme_constant_override("margin_left", 32)
	content.add_theme_constant_override("margin_right", 32)
	content.add_theme_constant_override("margin_top", 30)
	content.add_theme_constant_override("margin_bottom", 30)
	card.add_child(content)

	var logo_row := CenterContainer.new()
	content.add_child(logo_row)
	var logo := Label.new()
	logo.text = "E"
	logo.custom_minimum_size = Vector2(76.0, 76.0)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 54)
	logo.add_theme_color_override("font_color", ACCENT)
	logo.add_theme_stylebox_override("normal", _style(PANEL_LIGHT, 6, ACCENT, 1))
	logo_row.add_child(logo)
	var title := _label("EXAFORGE 3D", 28, TEXT)
	content.add_child(title)
	loading_status = _label("Инициализация игрового пространства", 16, MUTED)
	content.add_child(loading_status)
	var progress := ProgressBar.new()
	progress.indeterminate = true
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0.0, 14.0)
	content.add_child(progress)

func _build_game_view() -> void:
	game_view = _full_screen_control("GameView", Control.MOUSE_FILTER_IGNORE)
	game_view.hide()
	add_child(game_view)

	controls_button = Button.new()
	controls_button.name = "ControlsButton"
	controls_button.text = "Управление"
	controls_button.tooltip_text = "Открыть справку по управлению"
	controls_button.focus_mode = Control.FOCUS_ALL
	controls_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	controls_button.position = Vector2(-188.0, 24.0)
	controls_button.size = Vector2(164.0, 42.0)
	controls_button.add_theme_font_size_override("font_size", 16)
	controls_button.add_theme_stylebox_override("normal", _style(PANEL, 7, Color("4a6a78"), 1))
	controls_button.add_theme_stylebox_override("hover", _style(PANEL_LIGHT, 7, ACCENT, 1))
	controls_button.add_theme_stylebox_override("pressed", _style(Color("1c3947"), 7, ACCENT, 1))
	controls_button.pressed.connect(open_controls)
	game_view.add_child(controls_button)

	var hints_region := CenterContainer.new()
	hints_region.name = "HudHintsRegion"
	hints_region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hints_region.anchor_left = 0.5
	hints_region.anchor_top = 0.74
	hints_region.anchor_right = 0.5
	hints_region.anchor_bottom = 0.88
	hints_region.offset_left = -440.0
	hints_region.offset_right = 440.0
	game_view.add_child(hints_region)

	hint_row = HBoxContainer.new()
	hint_row.name = "HudHints"
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.modulate = Color(1.0, 1.0, 1.0, 0.5)
	hint_row.add_theme_constant_override("separation", 22)
	hints_region.add_child(hint_row)
	hint_row.add_child(_wasd_hint())
	hint_row.add_child(_simple_hint("ЛКМ", "Орбита по курсору"))
	hint_row.add_child(_wheel_hint())

func _build_controls_overlay() -> void:
	controls_overlay = _full_screen_control("ControlsPanel", Control.MOUSE_FILTER_STOP)
	controls_overlay.hide()
	add_child(controls_overlay)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.01, 0.02, 0.72)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(dimmer)
	controls_overlay.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "ControlsCenter"
	_fill(center)
	center.offset_left = 28.0
	center.offset_top = 22.0
	center.offset_right = -28.0
	center.offset_bottom = -22.0
	controls_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "ControlsModal"
	panel.custom_minimum_size = Vector2(760.0, 510.0)
	panel.add_theme_stylebox_override("panel", _style(PANEL, 12, Color("355767"), 1))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.add_theme_constant_override("margin_left", 30)
	content.add_theme_constant_override("margin_right", 30)
	content.add_theme_constant_override("margin_top", 26)
	content.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(content)
	content.add_child(_label("EXAFORGE 3D", 25, ACCENT))
	content.add_child(_label("Управление", 21, TEXT))

	controls_tabs = TabContainer.new()
	controls_tabs.name = "ControlsTabs"
	controls_tabs.custom_minimum_size = Vector2(700.0, 300.0)
	controls_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(controls_tabs)
	controls_tabs.add_child(_camera_tab())
	controls_tabs.add_child(_game_space_tab())
	controls_tabs.add_child(_settings_tab())
	controls_tabs.set_tab_disabled(2, true)
	controls_tabs.current_tab = 0

	return_button = Button.new()
	return_button.name = "ReturnToGameButton"
	return_button.text = "Вернуться в игру"
	return_button.custom_minimum_size = Vector2(0.0, 42.0)
	return_button.focus_mode = Control.FOCUS_ALL
	return_button.add_theme_font_size_override("font_size", 17)
	return_button.add_theme_stylebox_override("normal", _style(Color("173845"), 7, ACCENT, 1))
	return_button.add_theme_stylebox_override("hover", _style(Color("205268"), 7, Color("b9f5ff"), 1))
	return_button.pressed.connect(close_controls)
	content.add_child(return_button)

func _camera_tab() -> Control:
	return _tab("Камера", [
		"W A S D  —  смещение камеры относительно экрана",
		"ЛКМ + мышь  —  вращение вокруг точки под курсором",
		"Колесо  —  приблизить или отдалить",
		"Камера не опускается ниже Y=0; минимальная высота над землей Y=2, над модулем высотой 1 — Y=3."
	])

func _game_space_tab() -> Control:
	return _tab("Игровое пространство", [
		"Строительная территория: 64 × 64 клетки.",
		"Базовая плоскость находится на Y=0.",
		"Логический объем модуля: 1 × 1 × 1.",
		"В прототипе доступны тестовые объекты ленты и трубы для проверки камеры."
	])

func _settings_tab() -> Control:
	return _tab("Настройки", ["Настройки появятся, когда в прототипе будут доступны работающие параметры."])

func _tab(title: String, lines: Array[String]) -> Control:
	var tab := MarginContainer.new()
	tab.name = title
	tab.add_theme_constant_override("margin_left", 16)
	tab.add_theme_constant_override("margin_right", 16)
	tab.add_theme_constant_override("margin_top", 18)
	tab.add_theme_constant_override("margin_bottom", 18)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	tab.add_child(content)
	for line in lines:
		var label := _label(line, 17, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
	return tab

func _wasd_hint() -> Control:
	var group := _hint_group()
	var keys := _label("W  A S D", 18, TEXT)
	keys.add_theme_stylebox_override("normal", _style(PANEL, 5, Color("63808c"), 1))
	group.add_child(keys)
	group.add_child(_label("Передвижение", 14, TEXT))
	return group

func _simple_hint(key: String, description: String) -> Control:
	var group := _hint_group()
	var key_label := _label(key, 18, TEXT)
	key_label.add_theme_stylebox_override("normal", _style(PANEL, 5, Color("63808c"), 1))
	group.add_child(key_label)
	group.add_child(_label(description, 14, TEXT))
	return group

func _wheel_hint() -> Control:
	var group := _hint_group()
	var icon := MouseWheelIcon.new()
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.add_child(icon)
	group.add_child(_label("Колесо: масштаб", 14, TEXT))
	return group

func _hint_group() -> VBoxContainer:
	var group := VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.custom_minimum_size = Vector2(180.0, 0.0)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 6)
	return group

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _full_screen_control(node_name: String, filter: Control.MouseFilter) -> Control:
	var control := Control.new()
	control.name = node_name
	control.mouse_filter = filter
	_fill(control)
	return control

func _fill(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.set_offsets_preset(Control.PRESET_FULL_RECT)

func _style(background: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style
