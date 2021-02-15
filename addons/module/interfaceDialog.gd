tool
extends WindowDialog

signal interface_changed(p_text)
signal method_changed(p_text)
signal interface_menu_popup(p_popup)
signal method_menu_popup(p_popup)

var okFunc:FuncRef

func get_ok_btn():
	return $vbox/btnsHbox/okBtn

func get_interface_edit():
	return $vbox/interfaceHbox/interfaceEdit

func get_lv_edit():
	return $vbox/lvHbox/lvEdit

func get_method_edit():
	return $vbox/methodHbox/methodEdit

func get_priority_edit():
	return $vbox/priorityHbox/priorityEdit

func get_interface_btn():
	return $vbox/interfaceHbox/interfaceBtn

func get_interface_popup():
	return $vbox/interfaceHbox/interfaceBtn.get_popup()

func get_method_btn():
	return $vbox/methodHbox/methodBtn

func get_method_popup():
	return $vbox/methodHbox/methodBtn.get_popup()


func _notification(p_what):
	if p_what == NOTIFICATION_READY || p_what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED:
		get_interface_btn().icon = get_icon("GuiDropdown", "EditorIcons")
		get_method_btn().icon = get_icon("GuiDropdown", "EditorIcons")
		if !get_interface_popup().is_connected("index_pressed", self, "_on_interfacePopup_index_pressed"):
			get_interface_popup().connect("index_pressed", self, "_on_interfacePopup_index_pressed")
		if !get_method_popup().is_connected("index_pressed", self, "_on_methodPopup_index_pressed"):
			get_method_popup().connect("index_pressed", self, "_on_methodPopup_index_pressed")

func set_interface(p_interface:String):
	get_interface_edit().text = p_interface

func get_interface():
	return get_interface_edit().text

func set_level(p_lv:int):
	get_lv_edit().value = p_lv

func get_level() -> int:
	return get_lv_edit().value

func set_method(p_method:String):
	get_method_edit().text = p_method

func get_method():
	return get_method_edit().text

func set_priority(p_priority:int):
	get_priority_edit().value = p_priority

func get_priority() -> int:
	return get_priority_edit().value

func set_ok_func(p_func:FuncRef):
	okFunc = p_func

func _on_okBtn_pressed():
	if okFunc:
		okFunc.call_func()
	hide()

func _on_interfaceEdit_text_changed(p_text):
	emit_signal("interface_changed", p_text)

func _on_methodEdit_text_changed(p_text):
	emit_signal("method_changed", p_text)

func _on_interfacePopup_index_pressed(p_index):
	get_interface_edit().text = get_interface_popup().get_item_metadata(p_index)

func _on_methodPopup_index_pressed(p_index):
	get_method_edit().text = get_method_popup().get_item_metadata(p_index)

func _on_methodBtn_about_to_show():
	emit_signal("method_menu_popup", get_method_popup())

func _on_interfaceBtn_about_to_show():
	emit_signal("interface_menu_popup", get_interface_popup())

func _on_cancelBtn_pressed():
	hide()
