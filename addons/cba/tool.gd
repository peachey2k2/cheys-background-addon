@tool
extends Window

var preview:TextureRect

var main:EditorPlugin

func start():
	if not Engine.is_editor_hint(): queue_free(); return
	$"VBoxContainer/HBoxContainer/VBoxContainer/image picker".pressed.connect(_image_picker)
	$"VBoxContainer/HBoxContainer/VBoxContainer/stretch mode".item_selected.connect(main.change_setting.bind("stretch"))
	$"VBoxContainer/HBoxContainer/VBoxContainer/filter mode".item_selected.connect(main.change_setting.bind("filter"))
	#$HBoxContainer/VBoxContainer2/ui_alpha.value_changed.connect(main.change_setting.bind("ui_alpha")) # too laggy
	$VBoxContainer/HBoxContainer/VBoxContainer2/ui_color.popup_closed.connect(main.change_setting.bind(null, "ui_color"))
	$VBoxContainer/HBoxContainer/VBoxContainer2/bg_modulate.color_changed.connect(main.change_setting.bind("bg_modulate"))
	$VBoxContainer/edit_transparency.toggled.connect(main.change_setting.bind("edit_transparency"))
	close_requested.connect(close)
	preview = $VBoxContainer/PanelContainer/TextureRect # thank you onready
	main.load_settings()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		close()

func close():
	main.save_settings()
	queue_free()

func _image_picker():
	var picker := EditorFileDialog.new()
	picker.close_requested.connect(queue_free)
	picker.file_selected.connect(main.change_setting.bind("image"))
	picker.size = Vector2(700, 500)
	picker.access = EditorFileDialog.ACCESS_FILESYSTEM
	picker.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	picker.filters = ["*.bmp, *.dds, *.exr, *.hdr, *.jpg, *.jpeg, *.png, *.tga, *.svg, *.svgz, *.webp; Supported Images"]
	add_child(picker)
	picker.popup_centered()
