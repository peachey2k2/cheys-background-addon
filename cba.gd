@tool
extends EditorPlugin

var base:Control

const TOOL = preload("res://addons/cba/tool.tscn")
var settings:Dictionary = {}
var bg:TextureRect
var tool:Window
var theme:Theme

func _exit_tree():
	bg.queue_free()
	remove_tool_menu_item("Backgrounds")

func _enter_tree():
	if not Engine.is_editor_hint(): return
	base = EditorInterface.get_base_control()
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
	base.theme = theme
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

func change_setting(value:Variant, setting:String, update_ui:bool = false, update_setting:bool = true):
	var is_prev_ready := is_instance_valid(tool)
	#print("[SET] ", setting, " = ", value)
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
		"ui_alpha":
			if is_prev_ready:
				value = tool.get_node("HBoxContainer/VBoxContainer2/ui_alpha").value
				if update_ui:
					tool.get_node("HBoxContainer/VBoxContainer2/ui_alpha").set_value_no_signal(value)
			else:
				value = settings["ui_alpha"]
			if update_setting:
				override_all(Color(0, 0, 0, value))
				change_theme_color(Color(0, 0, 0, value))
		"bg_alpha":
			if update_setting: bg.modulate.a = value
			if is_prev_ready:
				tool.preview.modulate.a = value
				if update_ui:
					tool.get_node("HBoxContainer/VBoxContainer2/bg_alpha").set_value_no_signal(value)
	settings[setting] = value

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
			assert(file != null, "Error loading the file.")
			settings = {}
		else:
			settings = JSON.parse_string(file.get_as_text())
			file.close()
			for s in settings.keys():
				change_setting(settings[s], s, true)

func save_settings():
	var file := FileAccess.open("res://addons/cba/config.json", FileAccess.WRITE)
	var str = settings
	file.store_string(JSON.stringify(settings, "\t"))

# for optimization purposes. turns out godot doesn't like it when you check around 8k nodes
# which is how many there are in the engine tree. comments show how many of each there were when i checked
var theme_blacklist := [
	"Button", # 1297
	"Label", # 1068
	#"VBoxContainer", # 822
	#"HBoxContainer", # 739
	#"LineEdit", # 370
	#"MarginContainer", # 334
	#"ConfirmationDialog", # 239
	#"Control", # 213
	#"ItemList", # 210
	#"OptionButton" #185
]

signal reallow_notify

# in godot, not even a single node uses a theme. they all rely on overrides
# so we have to manually edit each and every override every single time
func override_all(col:Color):
	var count := 0
	benchmark("set all overrides")
	for node:Control in get_children_recursive(base):
		var class_str = node.get_class() 
		#if not theme_blacklist.has(class_str):
		match class_str:
			"EditorRunBar":       replace_color(node, "panel", col)
			"EditorBottomPanel":  replace_color(node, "panel", col)
			"ImportDock":         replace_color(node, "normal", col)
			"EditorInspector":    replace_color(node, "panel", Color.TRANSPARENT)
			#"EditorDebuggerNode": replace_color(node.get_child(0), "panel", Color.TRANSPARENT)
			"PanelContainer":     replace_color(node, "panel", col)
			"Panel":              replace_color(node, "panel", col)
			_: continue
		print(class_str)
	reallow_notify.emit()
	benchmark_end.emit("set all overrides")

func replace_color(node:Control, boxname:String, col:Color):
	node.begin_bulk_theme_override()
	var sbox := node.get_theme_stylebox(boxname)
	if (sbox as StyleBoxFlat) == null:
		sbox = StyleBoxFlat.new()
	sbox.bg_color = col
	node.add_theme_stylebox_override(boxname, sbox)
	await reallow_notify
	node.end_bulk_theme_override()

func get_children_recursive(node:Node) -> Array[Control]:
	var list:Array[Control]
	if not node is Control: return []
	if not theme_blacklist.has(node.get_class()): list.append(node)
	for child:Node in node.get_children():
		list.append_array(get_children_recursive(child))
	return list

# rule 1 of optimization: ALWAYS benchmark your shit.
signal benchmark_end(label:String)
func benchmark(label:String):
	var start = Time.get_ticks_usec()
	while true:
		if label == await benchmark_end:
			break
	var end = Time.get_ticks_usec()
	print("[BENCHMARK] \"", label, "\" took ", (end-start)/1000000.0, " seconds.")

func change_theme_color(col:Color):
	replace_stylebox_color("TabContainer", "panel", col)
	replace_stylebox_color("TabBar", "tab_selected", col)
	replace_stylebox_color("TabBar", "tab_unselected", col)

func replace_stylebox_color(box_type:String, box_name:String, col:Color):
	var sbox := theme.get_stylebox("panel", "TabContainer")
	sbox.bg_color = col
