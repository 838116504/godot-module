tool
extends VBoxContainer

enum { BTN_ID_ADD_MODULE = 0, BTN_ID_ERASE_GROUP, BTN_ID_REMOVE_MODULE, BTN_ID_AUTO_ENABLE }

var editorInterface:EditorInterface
var data

func get_groupDir_label():
	return $hbox/groupDirLabel

func get_groupDir_btn():
	return $hbox/groupDirBtn

func get_create_btn():
	return $hbox/createBtn

func get_update_btn():
	return $hbox/updateBtn

func get_table_tree():
	return $tableTree

func get_module_popupMenu():
	return $tableTree/modulePopupMenu

func get_groupDir_fileDialog():
	return $tableTree/groupDirFileDialog

func get_confirm_dialog():
	return $tableTree/confirmDialog

func get_autoEnable_dialog():
	return $tableTree/autoEnableFileDialog

func _notification(p_what):
	if p_what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			update_table()
	elif p_what == NOTIFICATION_READY || p_what == EditorSettings.NOTIFICATION_EDITOR_SETTINGS_CHANGED:
		get_groupDir_btn().icon = get_icon("Folder", "EditorIcons")
		get_create_btn().icon = get_icon("Add", "EditorIcons")
		get_update_btn().icon = get_icon("ReloadSmall", "EditorIcons")
		var table = get_table_tree()
		
		if !table.is_connected("button_pressed", self, "_on_tableTree_button_pressed"):
			table.connect("button_pressed", self, "_on_tableTree_button_pressed")
		if !table.is_connected("item_activated", self, "_on_tableTree_item_item_activated"):
			table.connect("item_activated", self, "_on_tableTree_item_item_activated")
		if !table.is_connected("item_edited", self, "_on_tableTree_item_edited"):
			table.connect("item_edited", self, "_on_tableTree_item_edited")

func add_group_item(p_name, p_isAuto, p_modules):
	if !p_name is String || !p_isAuto is bool || !p_modules is Array:
		return
	
	var table = get_table_tree()
	var item = table.create_item(table.get_root())
	item.set_cell_mode(0, TreeItem.CELL_MODE_STRING)
	item.set_text(0, p_name)
	item.set_metadata(0, "group")
	item.set_meta("data", p_name)
	item.set_editable(0, true)
	item.add_button(0, get_icon("AutoPlay", "EditorIcons") if p_isAuto else get_icon("AutoEnd", "EditorIcons"), BTN_ID_AUTO_ENABLE, false, "auto enable")
	item.add_button(0, get_icon("Add", "EditorIcons"), BTN_ID_ADD_MODULE, data.modules.size() - p_modules.size() <= 0, "add module")
	item.add_button(0, get_icon("GuiClose", "EditorIcons"), BTN_ID_ERASE_GROUP, false, "delete group")

	var child
	for i in p_modules:
		child = table.create_item(item)
		child.set_metadata(0, "module")
		child.set_meta("data", i)
		if data && data.moduleDesc.has(i):
			child.set_text(0, data.moduleDesc[i][0])
			child.set_tooltip(0, data.moduleDesc[i][1])
			
			if data.modules.has(i):
				child.set_icon(0, get_icon("ImportCheck", "EditorIcons"))
			else:
				child.set_icon(0, get_icon("ImportFail"), "EditorIcons")
		else:
			child.set_text(0, i)
			if data && data.data.modules.has(i):
				child.set_icon(0, get_icon("InformationSign", "EditorIcons"))
			else:
				child.set_icon(0, get_icon("ImportFail"), "EditorIcons")

		child.add_button(0, get_icon("Close", "EditorIcons"), BTN_ID_REMOVE_MODULE, false, "remove module")
		child.disable_folding = true

func update_table():
	get_table_tree().clear()
	get_table_tree().create_item()
	if !data:
		return
	
	for i in data.groups.keys():
		add_group_item(i, data.groups[i][0], data.groups[i][1])
	
	get_groupDir_label().text = data.groupPath

func _on_tableTree_item_edited():
	var table = get_table_tree()
	var item = table.get_edited()
	if !item:
		return
#	match table.get_edited_column():
#		0:
#			data.group_set_auto(table.get_edited().get_text(1), table.get_edited().is_checked(0))
	data.group_set_name(item.get_meta("data"), item.get_text(0))
	item.set_meta("data", item.get_text(0))

func _on_tableTree_button_pressed(p_item, p_col, p_btnId):
	match p_btnId:
		BTN_ID_ADD_MODULE:
			var menu = get_module_popupMenu()
			menu.clear()
			
			for i in data.modules.keys():
				if i in data.groups[p_item.get_text(0)][1]:
					continue
				
				if data.moduleDesc.has(i):
					menu.add_item(data.moduleDesc[i][0])
					menu.set_item_tooltip(menu.get_item_count() - 1, data.moduleDesc[i][1])
				else:
					menu.add_item(i)
				menu.set_item_metadata(menu.get_item_count() - 1, i)
			menu.set_meta("group", p_item.get_meta("data"))
			var table = get_table_tree()
			var minSize = menu.get_combined_minimum_size()
			menu.popup(Rect2(table.rect_global_position + table.get_stylebox("bg").get_offset() + table.get_item_area_rect(p_item).end - Vector2(minSize.x, 0.0), minSize))
		BTN_ID_ERASE_GROUP:
			confirm_dialog("Delete Group", "Do you delete group " + p_item.get_meta("data") + "?", funcref(self, "_on_delete_group_confirmed"), p_item.get_meta("data"))
		BTN_ID_REMOVE_MODULE:
			confirm_dialog("Remove Module", "Do you remove module " + p_item.get_meta("data") + " from group " + p_item.get_parent().get_meta("data") + "?", \
					funcref(self, "_on_remove_module_confirmed"), [p_item.get_meta("data"), p_item.get_parent().get_meta("data")])
		BTN_ID_AUTO_ENABLE:
			var group = p_item.get_meta("data")
			if data.groups[group][0]:
				data.group_set_auto(group, false)
				update_table()
			else:
				var dialog = get_autoEnable_dialog()
				dialog.current_path = group_name_to_path(group)
				dialog.set_meta("group", group)
				dialog.popup_centered()

func group_name_to_path(p_group:String) -> String:
	while "-" in p_group:
		p_group = p_group.replace("-", "/")
	return "res://" + p_group

func path_to_group_name(p_path:String) -> String:
	var find = p_path.find("//")
	if find >= 0:
		p_path = p_path.substr(find + 2)
	
	while "/" in p_path:
		p_path = p_path.replace("/", "-")
	return p_path

func _on_tableTree_item_item_activated():
	var item = get_table_tree().get_selected()
	if !item || item.get_metadata(0) != "module":
		return
	
	var mod = item.get_meta("data")
	var modPanel = get_node_or_null("../module")
	if modPanel:
		get_parent().current_tab = modPanel.get_index()
		if modPanel.moduleItems.has(mod):
			modPanel.moduleItems[mod].select(1)

func _on_updateBtn_pressed():
	update_table()


func _on_createBtn_pressed():
	data.add_group(data.get_group_new_name())
	update_table()


func _on_groupDirBtn_pressed():
	var dialog = get_groupDir_fileDialog()
	dialog.current_dir = data.groupPath
	dialog.popup_centered()


func _on_modulePopupMenu_index_pressed(p_index):
	var menu = get_module_popupMenu()
	if !menu.has_meta("group"):
		return
	
	var module = menu.get_item_metadata(p_index)
	data.add_group_module(menu.get_meta("group"), module)
	update_table()


func _on_groupDirFileDialog_dir_selected(p_dir):
	get_groupDir_label().text = p_dir
	data.groupDir = p_dir


func confirm_dialog(p_title:String, p_text:String, p_confirmFunc:FuncRef, p_data = null):
	var dialog = get_confirm_dialog()
	dialog.set_meta("confirm_func", p_confirmFunc)
	dialog.set_meta("user_data", p_data)
	dialog.dialog_text = p_text
	dialog.window_title = p_title
	dialog.popup_centered()

func _on_delete_group_confirmed(p_data):
	data.erase_group(p_data)
	update_table()

func _on_remove_module_confirmed(p_data):
	data.remove_group_module(p_data[1], p_data[0])
	update_table()

func _on_confirmDialog_confirmed():
	var dialog = get_confirm_dialog()
	if dialog.has_meta("confirm_func"):
		var data = null
		if dialog.has_meta("user_data"):
			data = dialog.get_meta("user_data")
		var confirmFunc = dialog.get_meta("confirm_func")
		if confirmFunc is FuncRef:
			confirmFunc.call_func(data)

func _on_autoEnableFileDialog_file_selected(p_path:String):
	var dialog = get_autoEnable_dialog()
	if !dialog.has_meta("group"):
		return
	
	var group = dialog.get_meta("group")
	if !data.groups.has(group):
		return
	
	data.group_set_auto(group, true)
	data.group_set_name(group, path_to_group_name(p_path))
	dialog.set_meta("group", null)
	update_table()
