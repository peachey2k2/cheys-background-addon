@tool
extends EditorPlugin

var base:Control
var editor_settings:EditorSettings

const TOOL = preload("res://addons/cba/tool.tscn")
var settings:Dictionary = {}
var bg:TextureRect
var tool:Window
var theme:Theme

var accent_color:Color

func _disable_plugin():
	bg.queue_free()
	editor_settings.set("interface/theme/custom_theme", "")
	editor_settings.set("interface/theme/preset", "Default")
	remove_tool_menu_item("Backgrounds")

func _enter_tree():
	#Benchmark.start("init")
	if not Engine.is_editor_hint(): return
	
	base = EditorInterface.get_base_control()
	editor_settings = EditorInterface.get_editor_settings()
	editor_settings.settings_changed.connect(func():
		for setting in editor_settings.get_changed_settings():
			_setting_changed(setting)
	)
	bg = TextureRect.new()
	bg.name = "Editor Background"
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_child.call_deferred(bg)
	# move it to the top of the tree so it's behind all the UI
	base.move_child.call_deferred(bg, 0)
	await bg.ready
	
	theme = preload("res://addons/cba/theme.tres")
	if editor_settings.get("interface/theme/custom_theme") != "res://addons/cba/theme.tres":
		editor_settings.set("interface/theme/custom_theme", "res://addons/cba/theme.tres")
	if editor_settings.get("interface/theme/preset") != "Custom":
		editor_settings.set("interface/theme/preset", "Custom")
	
	await base.get_tree().physics_frame
	load_settings()
	
	add_tool_menu_item("Backgrounds", func():
		if is_instance_valid(tool): printerr("There is already a background picker window open."); return
		tool = TOOL.instantiate()
		tool.main = self
		base.add_child(tool)
		tool.start()
		tool.popup_centered()
	)
	#Benchmark.end("init")

func change_setting(value:Variant, setting:String, update_ui:bool = false, update_setting:bool = true):
	var is_prev_ready := is_instance_valid(tool)
	match setting:
		"image":
			var img := load_image(value)
			if is_prev_ready: tool.preview.texture = img
			if update_setting: bg.texture = img
		"stretch":
			if update_setting: bg.stretch_mode = value
			if is_prev_ready:
				tool.preview.stretch_mode = value
				if update_ui:
					tool.get_node("HBoxContainer/VBoxContainer/stretch mode").select(value)
		"filter":
			if update_setting: bg.texture_filter = value
			if is_prev_ready:
				tool.preview.texture_filter = value
				if update_ui:
					tool.get_node("HBoxContainer/VBoxContainer/filter mode").select(value)
		"ui_color":
			if is_prev_ready:
				if update_ui:
					value = Color(settings["ui_color"])
					tool.get_node("HBoxContainer/VBoxContainer2/ui_color").color = value
				else:
					value = tool.get_node("HBoxContainer/VBoxContainer2/ui_color").color
			if not update_ui && update_setting:
				if value == Color(settings["ui_color"]): return
				change_theme_color(value)
				settings["ui_color"] = value.to_html()
			value = null
		"bg_modulate":
			if value is String: value = Color(value)
			if update_setting: bg.modulate = value
			if is_prev_ready:
				tool.preview.modulate = value
				if update_ui:
					tool.get_node("HBoxContainer/VBoxContainer2/bg_modulate").color = value
			value = value.to_html()
	if value != null: settings[setting] = value

func load_image(path:String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: printerr("file not found: ", path); return
	var image = Image.load_from_file(path)
	var out = ImageTexture.create_from_image(image)
	return out

func load_settings():
	if FileAccess.file_exists("res://addons/cba/config.json"):
		var file := FileAccess.open("res://addons/cba/config.json", FileAccess.READ)
		if file == null:
			file = FileAccess.open("res://addons/cba/config.json", FileAccess.WRITE_READ)
			assert(file != null, "Error opening file.")
			return
		else:
			settings = JSON.parse_string(file.get_as_text())
			file.close()
	else:
		var file := FileAccess.open("res://addons/cba/config.json", FileAccess.WRITE)
		var defaults := {
			"filter": 0.0,
			"image": ProjectSettings.globalize_path("res://addons/cba/images/default.png"),
			"stretch": 1,
			"ui_color": "00000088",
			"bg_modulate": "ffffffb0",
		}
		file.store_string(JSON.stringify(defaults, "\t"))
		settings = defaults
		file.close()
	for s in settings.keys():
		change_setting(settings[s], s, true)

func save_settings():
	var file := FileAccess.open("res://addons/cba/config.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "\t"))

func _setting_changed(setting:String):
	match setting:
		"interface/theme/accent_color":
			change_theme_color(Color(settings["ui_color"]))

func change_theme_color(col:Color):
	#Benchmark.start("change theme color")
	
	accent_color = editor_settings.get_setting("interface/theme/accent_color")
	
	var controls_list = get_all_controls([base])

	var col2 := Color(col, col.a/2.0)
	var col3 := Color(col, min(col.a/col.v, col.a/4.0))
	change_color("EditorStyles", "Background", col)
	change_color("EditorStyles", "BottomPanel", col)
	change_color("EditorStyles", "BottomPanelDebuggerOverride", col)
	change_color("EditorStyles", "Content", col)
	change_color("EditorStyles", "LaunchPadNormal", col)
	
	change_color("TabContainer", "panel", col)
	change_color("TabContainer", "tab_selected", col, accent_color)
	change_color("TabContainer", "tab_unselected", col2)
	change_color("TabContainer", "tab_hovered", col2)
	
	change_color("TabBar", "tab_selected", col, accent_color)
	change_color("TabBar", "tab_unselected", col2)
	change_color("TabBar", "tab_hovered", col2)
	
	change_color("TabContainerOdd", "tab_selected", col, accent_color)
	change_color("TabContainerOdd", "panel", col2)
	
	# bordered
	change_color("Button", "normal", col3)
	change_color("MenuButton", "normal", col3)
	change_color("OptionButton", "normal", col3)
	change_color("RichTextLabel", "normal", col3)
	change_color("LineEdit", "normal", col3)
	change_color("LineEdit", "read_only", col3)
	change_color("EditorProperty", "child_bg", col3)
	
	change_color("EditorInspectorCategory", "bg", col2)
	
	# fix to old values showing up in transparent preview
	change_color("LineEdit", "focus", Color.BLACK)
	
	# trigger an update
	theme.get_stylebox("Background", "EditorStyles").emit_changed()
	
	#Benchmark.end("change theme color")

func get_all_controls(nodes:Array[Node]) -> Array[Node]:
	var out:Array[Node] = []
	for node in nodes:
		if node is Control: out.append(node)
		var children := node.get_children() as Array[Node]
		out += get_all_controls(children)
	return out

func change_color(type:String, name:String, col:Color, border = null):
	var box:StyleBoxFlat = theme.get_stylebox(name, type)
	box.set_block_signals(true)
	box.bg_color = col
	if border != null: 
		box.border_color = border
	box.set_block_signals(false)
