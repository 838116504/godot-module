tool
extends WindowDialog

signal ok

func get_filename_edit():
	return $vbox/filenameHbox/filenameEdit

func get_name_edit():
	return $vbox/nameHbox/nameEdit

func get_desc_edit():
	return $vbox/descHbox/descEdit

func get_version_edit():
	return $vbox/versionHbox/versionEdit

func get_gdPath_edit():
	return $vbox/gdPathHbox/gdPathEdit

func get_gdPath_btn():
	return $vbox/gdPathHbox/gdPathBtn

func get_ok_btn():
	return $vbox/btnsHbox/okBtn

func get_gdPath_dialog():
	return $vbox/gdPathHbox/gdPathBtn/FileDialog

func _notification(p_what):
	if p_what == NOTIFICATION_READY || p_what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED:
		get_gdPath_btn().icon = get_icon("Folder", "EditorIcons")

func _on_createBtn_pressed():
	emit_signal("ok")
	hide()

func _on_cancelBtn_pressed():
	hide()

func set_data(p_filename, p_name, p_desc, p_version, p_gdPath):
	get_filename_edit().text = p_filename
	get_name_edit().text = p_name
	get_desc_edit().text = p_desc
	get_version_edit().text = p_version
	get_gdPath_edit().text = p_gdPath


func _on_FileDialog_file_selected(p_path):
	get_gdPath_edit().text = p_path


func _on_gdPathBtn_pressed():
	get_gdPath_dialog().popup_centered()
