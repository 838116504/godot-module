tool
extends VBoxContainer

enum { BTN_ID_INTERFACE_EDIT = 0, BTN_ID_MODULE_UNBIND }

var editorInterface:EditorInterface
var data
var interfaceItems := {}

func get_table_tree():
	return $tableTree

func get_createFolder_btn():
	return $hbox/createFolderBtn

func get_update_btn():
	return $hbox/updateBtn

func get_confirm_dialog():
	return $tableTree/confirmDialog

func get_interface_dialog():
	return $tableTree/interfaceDialog

func _notification(p_what):
	if p_what == NOTIFICATION_VISIBILITY_CHANGED:
		if visible:
			update_table()
	elif p_what == NOTIFICATION_READY || p_what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED:
		if get_color("font_color", "Label").r < 0.5:
			get_createFolder_btn().icon = preload("res://addons/module/createFolderIcon.svg")
		else:
			get_createFolder_btn().icon = preload("res://addons/module/createFolderIcon_white.svg")
		get_update_btn().icon = get_icon("ReloadSmall", "EditorIcons")

func _ready():
	get_table_tree().set_drag_forwarding(self)

func can_drop_data_fw(p_pos, p_data, p_from):
	if p_from != get_table_tree():
		return false
	
	var section = p_from.get_drop_section_at_position(p_pos)
	match section:
		-100:
			return true
		0:
			var item = p_from.get_item_at_position(p_pos)
			if item && item.get_metadata(0) == "folder":
				p_from.drop_mode_flags = Tree.DROP_MODE_ON_ITEM | Tree.DROP_MODE_INBETWEEN
				return true
		-1, 1:
			var item = p_from.get_item_at_position(p_pos)
			if item && (item.get_parent().get_metadata(0) == "folder" || item.get_parent() == p_from.get_root()):
				p_from.drop_mode_flags = Tree.DROP_MODE_INBETWEEN
				if item.get_metadata(0) == "folder":
					p_from.drop_mode_flags |= Tree.DROP_MODE_ON_ITEM
				return true
	
	return false

func drop_data_fw(p_pos, p_data, p_from):
	if p_from != get_table_tree() || !p_data is TreeItem:
		return
	
	var item = p_from.get_item_at_position(p_pos)
	var section = p_from.get_drop_section_at_position(p_pos)
	var parent
	match section:
		-100:
			parent = p_from.get_root()
		-1, 1:
			parent = item.get_parent()
		0:
			parent = item
		_:
			return
	
	if p_data.get_metadata(0) == "folder":
		var dir = Directory.new()
		var oldPath = data.interfaceDescPath + p_data.get_meta("data")
		
		if dir.dir_exists(oldPath):
			var newDir = ""
			if parent != p_from.get_root():
				newDir = parent.get_meta("data")
			dir.rename(oldPath, data.interfaceDescPath + newDir + p_data.get_text(0))
		
		data.load_data()
		update_table()
	elif p_data.get_metadata(0) == "interface":
		var oldPath = data.interface_desc_get_path(p_data.get_meta("data"))
		var dir := Directory.new()
		if dir.file_exists(oldPath):
			var newDir = ""
			if parent != p_from.get_root():
				newDir = parent.get_meta("data")
			dir.rename(oldPath, data.interfaceDescPath + newDir + data.INTERFACE_DESC_FILE_PREFIX + p_data.get_text(0) + ".cfg")
		
		data.load_data()
		update_table()

func get_drag_data_fw(p_pos, p_from):
	if p_from != get_table_tree():
		return null
	
	var item = p_from.get_item_at_position(p_pos)
	if !item || (item.get_metadata(0) != "folder" && item.get_metadata(0) != "interface"):
		return null
	
	var preview = Label.new()
	preview.text = item.get_meta("data")
	set_drag_preview(preview)
	return item

func update_table():
	var table = get_table_tree()
	table.clear()
	var root = table.create_item()
	interfaceItems.clear()
	if !data:
		return
	
	add_folder_item(root, "")
	
	var temp
	for mod in data.modules.keys():
		temp = data.modules[mod]
		for i in temp[1].size():
			if !interfaceItems.has(temp[1][i][0]):
				add_interface_item(table.create_item(root), temp[1][i][0])
			
			add_module_bind_item(table.create_item(interfaceItems[temp[1][i][0]]), mod, i)


func add_folder_item(p_self:TreeItem, p_path:String):
	var dir = Directory.new()
	if !dir.open(data.moduleDescPath + p_path) == OK:
		return
	
	var table = get_table_tree()
	if p_self != table.get_root():
		p_self.set_metadata(0, "folder")
		p_self.set_text(0, p_path.get_basename().get_file())
		p_self.set_icon(0, get_icon("Folder", "EditorIcons"))
		p_self.set_meta("data", p_path)
		p_self.set_tooltip(0, p_path)
	
	dir.list_dir_begin(true)
	var filename = dir.get_next()
	while filename != "":
		if dir.current_is_dir():
			add_folder_item(table.create_item(p_self), p_path + filename + "/")
		elif filename.begins_with(data.INTERFACE_DESC_FILE_PREFIX) && filename.get_extension() == "cfg":
			add_interface_item(table.create_item(p_self), 
					filename.get_basename().substr(data.INTERFACE_DESC_FILE_PREFIX.length()))
		filename = dir.get_next()
	
	dir.list_dir_end()

func add_interface_item(p_self:TreeItem, p_name:String):
	p_self.set_metadata(0, "interface")
	p_self.set_meta("data", p_name)
	if data.interfaceDesc.has(p_name):
		p_self.set_text(0, p_name + "(" + data.interfaceDesc[p_name][2] + ")")
		p_self.set_tooltip(0, data.interfaceDesc[p_name][1])
	else:
		p_self.set_text(0, p_name)
	p_self.add_button(0, get_icon("Edit", "EditorIcons"), BTN_ID_INTERFACE_EDIT, false, "Edit Description")
	
	interfaceItems[p_name] = p_self

func add_module_bind_item(p_self:TreeItem, p_module:String, p_idx:int):
	if !data.modules.has(p_module) || data.modules[p_module][1].size() <= p_idx:
		return
	
	var d = data.modules[p_module][1][p_idx]
	p_self.set_metadata(0, "module")
	p_self.set_meta("data", [p_module, p_idx])
	var desc = "level: " + str(d[1]) + "(" + str(d[3]) + ")"
	if data.moduleDesc.has(p_module):
		p_self.set_text(0, data.moduleDesc[p_module][0] + "." + d[2])
		desc += "\n" + data.moduleDesc[p_module][1]
	else:
		p_self.set_text(0, p_module + "." + d[2])
	p_self.set_tooltip(0, desc)
	p_self.add_button(0, get_icon("GuiClose", "EditorIcons"), BTN_ID_MODULE_UNBIND, false, "Unbind Module")

func _on_createFolderBtn_pressed():
	if !data:
		return
	
	var dir = Directory.new()
	var dirName = "folder"
	var count = 2
	while dir.dir_exists(data.interfaceDescPath + dirName):
		dirName = "folder" + str(count)
		count += 1
	
	dir.make_dir(data.moduleDescPath + dirName)
	update_table()


func _on_updateBtn_pressed():
	update_table()


func _on_tableTree_item_activated():
	var table = get_table_tree()
	var item = table.get_selected()
	if !item:
		return
	
	if item.get_metadata(0) == "module":
		var modPanel = get_node_or_null("../module")
		if modPanel:
			var mod = item.get_meta("data")[0]
			if modPanel.moduleItems.has(mod):
				get_parent().current_tab = modPanel.get_index()
				modPanel.moduleItems[mod].select(1)


func _on_tableTree_button_pressed(p_item:TreeItem, p_column, p_id:int):
	match p_id:
		BTN_ID_INTERFACE_EDIT:
			var dialog = get_interface_dialog()
			var itf = p_item.get_meta("data")
			dialog.set_meta("target", itf)
			var dir = ""
			if p_item.get_parent() != get_table_tree().get_root():
				dir = p_item.get_parent().get_meta("data")
			dialog.set_meta("dir", dir)
			if data.interfaceDesc.has(itf):
				dialog.set_desc(data.interfaceDesc[itf][1])
				dialog.set_params(data.interfaceDesac[itf][2])
			else:
				dialog.set_desc("")
				dialog.set_params("")
			dialog.window_title = "Edit Interface " + itf
			dialog.popup_centered()
		BTN_ID_MODULE_UNBIND:
			var itf = p_item.get_parent().get_meta("data")
			var mod = p_item.get_meta("data")[0]
			confirm_dialog("Confirm", "Do you remove inteface " + itf + " bind from module " + mod, funcref(self, "unbind_module"), p_item.get_meta("data"))

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

func _on_interfaceDialog_ok():
	var dialog = get_interface_dialog()
	if !dialog.has_meta("target"):
		return
	
	var itf = dialog.get_meta("target")
	data.set_interface_desc(itf, dialog.get_meta("dir"), dialog.get_desc(), dialog.get_params())
	dialog.set_meta("target", null)
	update_table()

func unbind_module(p_data):
	data.module_remove_interface_bind(p_data[0], p_data[1])
	update_table()

func _on_tableTree_item_edited():
	var table = get_table_tree()
	var item = table.get_edited()
	if !item:
		return
	
	if item.get_metadata(0) == "folder":
		var newPath = ""
		if item.get_parent() != table.get_root():
			newPath = item.get_parent().get_meta("data")
		newPath += item.get_text(0)
		var dir = Directory.new()
		dir.rename(data.interfaceDescPath + item.get_meta("data"), data.interfaceDescPath + newPath)
		data.load_data()
		update_table()
	elif item.get_metadata(0) == "interface":
		var newItf = item.get_text(0)
		if interfaceItems.has(newItf):
			update_table()
			return
		
		var itf = item.get_meta("data")
		data.rename_interface(itf, newItf)
		update_table()
