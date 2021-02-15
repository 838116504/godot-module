tool
extends WindowDialog

signal ok

func get_desc_edit():
	return $vbox/descEdit

func get_params_edit():
	return $vbox/paramsEdit

func get_ok_btn():
	return $vbox/btnsHbox/okBtn

func set_desc(p_text:String):
	get_desc_edit().text = p_text

func get_desc() -> String:
	return get_desc_edit().text

func set_params(p_text:String):
	get_params_edit().text = p_text

func get_params() -> String:
	return get_params_edit().text

func _on_okBtn_pressed():
	hide()
	emit_signal("ok")

func _on_cancelBtn_pressed():
	hide()
