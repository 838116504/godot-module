tool
extends VBoxContainer

enum { BTN_ID_MODULE_EDIT = 0, BTN_ID_MODULE_ADD_BIND, BTN_ID_INTERFACE_EDIT, BTN_ID_INTERFACE_GO_METHOD, BTN_ID_INTERFACE_UNBIND }
var editorInterface:EditorInterface
var data
var moduleItems := {}

func get_moduleDir_label():
	return $hbox/moduleDirLabel

func get_moduleDir_btn():
	return $hbox/moduleDirBtn

func get_create_btn():
	return $hbox/createBtn

func get_createFolder_btn():
	return $hbox/createFolderBtn

func get_update_btn():
	return $hbox/updateBtn

func get_table_tree():
	return $tableTree

func get_createModule_dialog():
	return $tableTree/createModuleDialog

func get_moduleDir_fileDialog():
	return $tableTree/moduleDirFileDialog

func get_error_dialog():
	return $tableTree/errorDialog

func get_interface_dialog():
	return $tableTree/interfaceDialog

func get_confirm_dialog():
	return $tableTree/confirmDialog

func _notification(p_what):
	if p_what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			update_table()
	elif p_what == NOTIFICATION_READY || p_what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED:
		var table = get_table_tree()
		table.set_column_expand(0, false)
		table.set_column_min_width(0, 60)
		table.set_column_min_width(1, 120)
		get_moduleDir_btn().icon = get_icon("Folder", "EditorIcons")
		get_create_btn().icon = get_icon("Add", "EditorIcons")
		if get_color("font_color", "Label").r < 0.5:
			get_createFolder_btn().icon = preload("res://addons/module/createFolderIcon.svg")
		else:
			get_createFolder_btn().icon = preload("res://addons/module/createFolderIcon_white.svg")
		get_update_btn().icon = get_icon("ReloadSmall", "EditorIcons")

func _ready():
	get_table_tree().set_drag_forwarding(self)

func can_drop_data_fw(p_pos, p_data, p_from:Control):
	if get_table_tree() == p_from:
		var section = p_from.get_drop_section_at_position(p_pos)
		p_from.drop_mode_flags = 0
		match section:
			-100:
				return true
			0:
				var item = p_from.get_item_at_position(p_pos)
				if item && item != p_data && item.get_metadata(0) == "folder":
					p_from.drop_mode_flags = Tree.DROP_MODE_ON_ITEM | Tree.DROP_MODE_INBETWEEN
					return true
			-1, 1:
				var item = p_from.get_item_at_position(p_pos)
				if item && item != p_data && (item.get_parent().get_metadata(0) == "folder" || item.get_parent() == p_from.get_root()):
					p_from.drop_mode_flags = Tree.DROP_MODE_INBETWEEN
					if item.get_metadata(0) == "folder":
						p_from.drop_mode_flags |= Tree.DROP_MODE_ON_ITEM
					return true
	return false

func drop_data_fw(p_pos, p_data, p_from:Control):
	if get_table_tree() == p_from:
		var section = p_from.get_drop_section_at_position(p_pos)
		var item = p_from.get_item_at_position(p_pos)
		var parent
		match section:
			-100:
				parent = p_from.get_root()
			0:
				parent = item
			-1, 1:
				parent = item.get_parent()
			_:
				return
		if p_data.get_metadata(0) == "folder":
			var dir := Directory.new()
			
			var path = ""
			if parent != p_from.get_root():
				path = parent.get_metadata(1)
			
			var dirName = p_data.get_text(1)
			if dir.dir_exists(data.moduleDescPath + path + dirName):
				var re := RegEx.new()
				re.compile("[0-9]+$")
				var prefix = p_data.get_text(1)
				var result = re.search(prefix)
				var count = 2
				if result:
					count = result.get_string().to_int() + 1
					prefix = prefix.substr(0, prefix.length() - result.get_string().length())
				
				while dir.dir_exists(data.moduleDescPath + path + prefix + str(count)):
					count += 1
				
				dirName = prefix + str(count)
			
			dir.rename(data.moduleDescPath + p_data.get_metadata(1), data.moduleDescPath + path + dirName)
			data.module_desc_folder_rename(p_data.get_metadata(1), path + dirName)
			update_table()
		elif p_data.get_metadata(0) == "module":
			var path = ""
			if parent != p_from.get_root():
				path = parent.get_metadata(1)
			
			data.module_desc_set_folder_path(p_data.get_metadata(1), path)
			update_table()

func get_drag_data_fw(p_pos, p_from:Control):
	if get_table_tree() == p_from:
		var item = p_from.get_item_at_position(p_pos)
		if item && (item.get_metadata(0) == "folder" || item.get_metadata(0) == "module"):
			var preview = Label.new()
			preview.text = item.get_text(1)
			set_drag_preview(preview)
			return item
	return null

func update_table():
	var table = get_table_tree()
	table.clear()
	var root = table.create_item()
	moduleItems.clear()
	if !data:
		return
	
	add_folder_item(root, "")
	for i in data.modules.keys():
		if moduleItems.has(i):
			continue
		
		add_module_item(table.create_item(root), i)
	
	get_moduleDir_label().text = data.modulePath

func add_folder_item(p_self:TreeItem, p_path:String):
	var dir = Directory.new()
	if !dir.open(data.moduleDescPath + p_path) == OK:
		return
	
	dir.list_dir_begin(true)
	var filename = dir.get_next()
	var table = get_table_tree()
	var temp
	if p_self != table.get_root():
		p_self.set_icon(0, get_icon("Folder", "EditorIcons"))
		p_self.set_text(1, p_path.get_base_dir().get_file())
		p_self.set_metadata(0, "folder")
		p_self.set_metadata(1, p_path)
		p_self.set_tooltip(0, p_path)
		p_self.set_tooltip(1, p_path)
		p_self.set_editable(1, true)
		p_self.disable_folding = false
	while filename != "":
		if dir.current_is_dir():
			add_folder_item(table.create_item(p_self), p_path + filename + "/")
		elif filename.begins_with("_md_") && filename.get_extension() == "cfg":
			temp = data.get_module_name_by_desc_path(data.moduleDescPath + p_path + filename)

			add_module_item(table.create_item(p_self), temp)
		filename = dir.get_next()
	dir.list_dir_end()

func add_module_item(p_self:TreeItem, p_name:String):
	moduleItems[p_name] = p_self
	p_self.set_metadata(0, "module")
	var desc = ""
	if data.moduleDesc.has(p_name):
		desc = data.moduleDesc[p_name][1]
		if !data.modules.has(p_name):
			p_self.set_icon(1, get_icon("ImportFail", "EditorIcons"))
		else:
			desc += "\n" + "script path: " + data.modules[p_name][0]
			var dir = Directory.new()
			if !dir.file_exists(data.modules[p_name][0]):
				p_self.set_icon(1, get_icon("ImportFail", "EditorIcons"))
		
		p_self.set_text(0, data.moduleDesc[p_name][2])
		p_self.set_text(1, data.moduleDesc[p_name][0])
		p_self.set_tooltip(0, desc)
		p_self.set_tooltip(1, desc)
	elif data.modules.has(p_name):
		if "-" in p_name:
			p_self.set_text(1, p_name.substr(p_name.find_last("-") + 1))
		else:
			p_self.set_text(1, p_name)
		var dir = Directory.new()
		if !dir.file_exists(data.modules[p_name][0]):
			p_self.set_icon(1, get_icon("ImportFail", "EditorIcons"))
		else:
			p_self.set_icon(1, get_icon("InformationSign", "EditorIcons"))
		desc = "script path: " + data.modules[p_name][0]
	else:
		print_debug("Doesn't exist module ", p_name)
	
	p_self.set_tooltip(0, desc)
	p_self.set_tooltip(1, desc)
	p_self.set_editable(0, true)
	p_self.set_metadata(1, p_name)
	p_self.add_button(1, get_icon("Edit", "EditorIcons"), BTN_ID_MODULE_EDIT, false, "Edit")
	p_self.add_button(1, get_icon("Add", "EditorIcons"), BTN_ID_MODULE_ADD_BIND, false, "Add Interface Bind")
	
	if data.modules.has(p_name):
		var table = get_table_tree()
		var interface
		var params
		for b in data.modules[p_name][1]:
			interface = table.create_item(p_self)
			interface.set_cell_mode(0, TreeItem.CELL_MODE_RANGE)
			interface.set_metadata(0, "interface")
			interface.set_range_config(0, -65536, 65536, 1)
			interface.set_range(0, b[1])
			interface.set_editable(0, true)
			interface.set_metadata(1, b)
			params = ""
			desc = "method: " + b[2]
			if data.interfaceDesc.has(b[0]):
				desc += "\n" + data.interfaceDesc[b[0]][1]
				params = data.interfaceDesc[b[0]][2]
			interface.set_text(1, b[0] + params)
			
			interface.add_button(1, get_icon("Edit", "EditorIcons"), BTN_ID_INTERFACE_EDIT, false, "Edit")
			interface.add_button(1, get_icon("AudioBusMute", "EditorIcons"), BTN_ID_INTERFACE_GO_METHOD, false, "Go Method")
			interface.add_button(1, get_icon("GuiClose", "EditorIcons"), BTN_ID_INTERFACE_UNBIND, false, "Unbind")
			
			interface.set_tooltip(0, desc)
			interface.set_tooltip(1, desc)
			interface.disable_folding = true

func _on_createModuleDialog_ok():
	var dialog = get_createModule_dialog()
	if dialog.has_meta("ok_func"):
		dialog.get_meta("ok_func").call_func(dialog)

func create_module(p_dialog):
	var filename = p_dialog.get_filename_edit().text
	if filename == "":
		get_error_dialog().dialog_text = "Please input filename."
		get_createModule_dialog().popup_centered()
		get_error_dialog().popup_centered()
		return
	var table = get_table_tree()
	if table.get_selected() && table.get_selected().get_metadata(0) == "folder":
		filename = data.get_module_name_by_desc_path(table.get_selected().get_tooltip(1) + "_md_" + filename + ".cfg")
	if data.modules.has(filename):
		get_error_dialog().dialog_text = "The filename is exists."
		get_createModule_dialog().popup_centered()
		get_error_dialog().popup_centered()
		return
	
	data.create_module(filename, p_dialog.get_name_edit().text, p_dialog.get_desc_edit().text, p_dialog.get_version_edit().text, p_dialog.get_gdPath_edit().text)
	update_table()

func edit_module(p_dialog):
	var filename = p_dialog.get_filename_edit().text
	var mod:String = p_dialog.get_meta("module")
	if "-" in mod:
		filename = mod.substr(0, mod.find_last("-") + 1) + filename
	
	if filename != mod:
		if filename == "":
			get_error_dialog().dialog_text = "Please input filename."
			get_createModule_dialog().popup_centered()
			get_error_dialog().popup_centered()
			return
		
		if data.modules.has(filename):
			get_error_dialog().dialog_text = "The filename is exists."
			get_createModule_dialog().popup_centered()
			get_error_dialog().popup_centered()
			return
		
		data.rename_module(p_dialog.get_meta("module"), filename)
	
	data.moduleDesc[filename] = [p_dialog.get_name_edit().text, p_dialog.get_desc_edit().text, p_dialog.get_version_edit().text]
	data.save_module_desc(filename)
	if data.modules.has(filename):
		data.modules[filename][0] = p_dialog.get_gdPath_edit().text
	else:
		data.modules[filename] = [ p_dialog.get_gdPath_edit().text, [] ]
	data.save_module_bind(filename)
	update_table()

func _on_moduleDIrFileDialog_dir_selected(p_dir):
	get_moduleDir_label().text = p_dir
	data.set_module_path(p_dir)

func _on_moduleDirBtn_pressed():
	var dialog = get_moduleDir_fileDialog()
	if data:
		dialog.current_dir = data.modulePath
	dialog.popup_centered()

func _on_createBtn_pressed():
	var dialog = get_createModule_dialog()
	dialog.window_title = "Create Module"
	dialog.get_ok_btn().text = "Create"
	dialog.set_meta("ok_func", funcref(self, "create_module"))
	dialog.popup_centered()

func _on_tableTree_button_pressed(p_item:TreeItem, p_column, p_id):
	match p_id:
		BTN_ID_MODULE_EDIT:
			var dialog = get_createModule_dialog()
			dialog.window_title = "Edit Module"
			dialog.get_ok_btn().text = "Edit"
			var mod = p_item.get_metadata(1)
			dialog.set_meta("module", mod)
			dialog.set_meta("ok_func", funcref(self, "edit_module"))
			var filename = mod
			if "-" in filename:
				filename = filename.substr(filename.find_last("-") + 1)
			var modName = ""
			var modDesc = ""
			var modVer = ""
			var gdPath = ""
			if data.moduleDesc.has(mod):
				modName = data.moduleDesc[mod][0]
				modDesc = data.moduleDesc[mod][1]
				modVer = data.moduleDesc[mod][2]
			if data.modules.has(mod):
				gdPath = data.modules[mod][0]
			dialog.set_data(filename, modName, modDesc, modVer, gdPath)
			dialog.popup_centered()
		BTN_ID_MODULE_ADD_BIND:
			var dialog = get_interface_dialog()
			dialog.set_meta("module", p_item.get_metadata(1))
			dialog.set_ok_func(funcref(self, "add_interface_bind"))
			dialog.window_title = "Module " + p_item.get_text(1) + " Add Interface"
			dialog.get_ok_btn().text = "Add"
			dialog.popup_centered()
		BTN_ID_INTERFACE_EDIT:
			var dialog = get_interface_dialog()
			var mod = p_item.get_parent().get_metadata(1)
			var b = p_item.get_metadata(1)
			dialog.set_meta("module", mod)
			var prev = p_item.get_prev()
			var idx = 0
			while prev:
				idx += 1
				prev = prev.get_prev()
			dialog.set_meta("interface_idx", idx)
			dialog.set_ok_func(funcref(self, "edit_interface_bind"))
			dialog.window_title = "Module " + p_item.get_parent().get_text(1) + " Bind Interface " + p_item.get_text(1) + " Edit"
			dialog.get_ok_btn().text = "Edit"
			dialog.set_interface(b[0])
			dialog.set_level(b[1])
			dialog.set_method(b[2])
			dialog.set_priority(b[3])
			dialog.popup_centered()
		BTN_ID_INTERFACE_GO_METHOD:
			var mod = p_item.get_parent().get_metadata(1)
			var b = p_item.get_metadata(1)
			if data.modules.has(mod):
				var dir = Directory.new()
				if dir.file_exists(data.modules[mod][0]):
					var script = load(data.modules[mod][0])
					if script:
						var re := RegEx.new()
						re.compile("\nfunc\\s+" + b[2] + "\\s*\\(")
						var result = re.search(script.source_code)
						if result:
							var line = script.source_code.count("\n", 0, result.get_start() + 1)
							editorInterface.get_script_editor()._goto_script_line(script, line)
							get_parent().get_parent().hide()
		BTN_ID_INTERFACE_UNBIND:
			var mod = p_item.get_parent().get_metadata(1)
			var prev = p_item.get_prev()
			var idx = 0
			while prev:
				idx += 1
				prev = prev.get_prev()
			confirm_dialog("Unbind Interface", "Do you unbind interface " + p_item.get_text(1) + " from " + p_item.get_parent().get_text(1) + "?", 
					funcref(self, "unbind_interface"), [mod, idx])


func add_interface_bind():
	var dialog = get_interface_dialog()
	var mod = dialog.get_meta("module")
	data.module_add_interface_bind(mod, dialog.get_interface(), dialog.get_level(), dialog.get_method(), dialog.get_priority())
	update_table()

func edit_interface_bind():
	var dialog = get_interface_dialog()
	var mod = dialog.get_meta("module")
	var idx = dialog.get_meta("interface_idx")
	data.module_set_interface_bind(mod, idx, dialog.get_interface(), dialog.get_level(), dialog.get_method(), dialog.get_priority())
	update_table()

func _on_interfaceDialog_interface_menu_popup(p_popup:PopupMenu):
	p_popup.clear()
	if data:
		var keys = data.interfaceDesc.keys()
		for i in keys.size():
			p_popup.add_item(keys[i])
			p_popup.set_item_tooltip(i, data.interfaceDesc[keys[i]][1])
			p_popup.set_item_metadata(i, keys[i])

func _on_interfaceDialog_method_menu_popup(p_popup:PopupMenu):
	p_popup.clear()
	if get_interface_dialog().has_meta("module") && data:
		var mod = get_interface_dialog().get_meta("module")
		if data.modules.has(mod):
			var dir = Directory.new()
			if dir.file_exists(data.modules[mod][0]):
				var script = load(data.modules[mod][0])
				if script is GDScript:
					for i in script.get_script_method_list():
						p_popup.add_item(i.name)
						p_popup.set_item_metadata(p_popup.get_item_count() - 1, i.name)

func unbind_interface(p_data):
	data.module_remove_interface_bind(p_data[0], p_data[1])
	update_table()

func confirm_dialog(p_title:String, p_text:String, p_confirmFunc:FuncRef, p_data = null):
	var dialog = get_confirm_dialog()
	dialog.set_meta("confirm_func", p_confirmFunc)
	dialog.set_meta("user_data", p_data)
	dialog.dialog_text = p_text
	dialog.window_title = p_title
	dialog.popup_centered()

func _on_confirmDialog_confirmed():
	var dialog = get_confirm_dialog()
	if dialog.has_meta("confirm_func"):
		var data = null
		if dialog.has_meta("user_data"):
			data = dialog.get_meta("user_data")
		var confirmFunc = dialog.get_meta("confirm_func")
		if confirmFunc is FuncRef:
			confirmFunc.call_func(data)


func _on_tableTree_item_activated():
	var table = get_table_tree()
	var item = table.get_selected()
	if !item:
		return
	
	match item.get_metadata(0):
		"module":
			var mod = item.get_metadata(1)
			if data.modules.has(mod):
				var dir = Directory.new()
				var path = data.modules[mod][0]
				if dir.file_exists(path):
					var script = load(path)
					if script && script is GDScript:
						editorInterface.get_script_editor()._goto_script_line(script, 0)
						get_parent().get_parent().hide()
		"interface":
			var itfPanel = get_node_or_null("../interface")
			if itfPanel:
				get_parent().current_tab = itfPanel.get_index()
				if itfPanel.interfaceItems.has(item.get_metadata(1)[0]):
					itfPanel.interfaceItems[item.get_metadata(1)[0]].select(0)

func _on_tableTree_item_edited():
	var table = get_table_tree()
	var item = table.get_edited()
	var col = table.get_edited_column()
	if !item || !data:
		return
	
	if item.get_metadata(0) == "module":
		if col == 0:
			data.module_set_version(item.get_metadata(1), item.get_text(0))
	
	if item.get_metadata(0) == "interface":
		if col == 0:
			var idx = 0
			var prev = item.get_prev()
			while prev:
				idx += 1
				prev = prev.get_prev()
			data.module_set_interface_lv(item.get_parent().get_metadata(1), idx, item.get_range(0))
	
	if item.get_metadata(0) == "folder":
		if col == 1:
			var dir = Directory.new()
			var path = item.get_metadata(1)
			if path[path.length()-1] == "/":
				path = path.substr(0, path.length() - 1)
			
			var newPath = path.substr(0, path.find_last("/") + 1) + item.get_text(1)
			if dir.dir_exists(newPath):
				item.set_text(path.get_file())
				return
			
			dir.rename(data.moduleDescPath + path, data.moduleDescPath + newPath)
			data.module_desc_folder_rename(path, newPath)
			update_table()

func _on_updateBtn_pressed():
	update_table()

func _on_createFolderBtn_pressed():
	if !data:
		return
	
	var dir = Directory.new()
	var dirName = "folder"
	var count = 2
	while dir.dir_exists(data.moduleDescPath + dirName):
		dirName = "folder" + str(count)
		count += 1
	
	dir.make_dir(data.moduleDescPath + dirName)
	update_table()
