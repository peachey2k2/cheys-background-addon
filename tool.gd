@tool
extends Window

var preview:TextureRect

var main:EditorPlugin

func start():
	if not Engine.is_editor_hint(): queue_free(); return
	$"HBoxContainer/VBoxContainer/image picker".pressed.connect(_image_picker)
	$"HBoxContainer/VBoxContainer/stretch mode".item_selected.connect(main.change_setting.bind("stretch"))
	$"HBoxContainer/VBoxContainer/filter mode".item_selected.connect(main.change_setting.bind("filter"))
	#$HBoxContainer/VBoxContainer2/ui_alpha.value_changed.connect(main.change_setting.bind("ui_alpha")) # too laggy
	$HBoxContainer/VBoxContainer2/ui_alpha.drag_ended.connect(main.change_setting.bind("ui_alpha"))
	$HBoxContainer/VBoxContainer2/bg_alpha.value_changed.connect(main.change_setting.bind("bg_alpha"))
	close_requested.connect(func():
		main.save_settings()
		queue_free()
	)
	preview = $PanelContainer/TextureRect # thank you onready
	main.load_settings()

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
