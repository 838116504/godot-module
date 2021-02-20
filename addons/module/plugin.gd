tool
extends EditorPlugin

const MODULE_MANAGER_NAME = "moduleManager"

var moduleGroupTable = preload("moduleGroup.tscn").instance()
var moduleTable = preload("module.tscn").instance()
var interfaceTable = preload("interface.tscn").instance()
var data = preload("data.gd").new()

func _enter_tree():
	data.load_editor_settings()
	data.load_settings()
	data.load_data()
	moduleGroupTable.editorInterface = get_editor_interface()
	moduleGroupTable.data = data
	moduleTable.editorInterface = get_editor_interface()
	moduleTable.data = data
	interfaceTable.editorInterface = get_editor_interface()
	interfaceTable.data = data
	add_control_to_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, moduleGroupTable)
	add_control_to_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, moduleTable)
	add_control_to_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, interfaceTable)
	var p = moduleGroupTable.get_parent()
	p.move_child(moduleGroupTable, p.get_child_count() - 1)
	p.move_child(moduleTable, p.get_child_count() - 1)
	p.move_child(interfaceTable, p.get_child_count() - 1)
	
	var fileDock = get_editor_interface().get_file_system_dock()
	if !fileDock.is_connected("file_removed", self, "_on_fileDock_file_removed"):
		fileDock.connect("file_removed", self, "_on_fileDock_file_removed")
	if !fileDock.is_connected("files_moved", self, "_on_fileDock_files_moved"):
		fileDock.connect("files_moved", self, "_on_fileDock_files_moved")
	if !fileDock.is_connected("folder_removed", self, "_on_fileDock_folder_removed"):
		fileDock.connect("folder_removed", self, "_on_fileDock_folder_removed")
	if !fileDock.is_connected("folder_moved", self, "_on_fileDock_folder_moved"):
		fileDock.connect("folder_moved", self, "_on_fileDock_folder_moved")
	
	add_autoload_singleton(MODULE_MANAGER_NAME, get_script().get_path().get_base_dir() + "/moduleManager.gd")


func _exit_tree():
	remove_control_from_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, moduleGroupTable)
	remove_control_from_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, moduleTable)
	remove_control_from_container(EditorPlugin.CONTAINER_PROJECT_SETTING_TAB_RIGHT, interfaceTable)
	
	var fileDock = get_editor_interface().get_file_system_dock()
	if fileDock.is_connected("file_removed", self, "_on_fileDock_file_removed"):
		fileDock.disconnect("file_removed", self, "_on_fileDock_file_removed")
	if fileDock.is_connected("files_moved", self, "_on_fileDock_files_moved"):
		fileDock.disconnect("files_moved", self, "_on_fileDock_files_moved")
	if fileDock.is_connected("folder_removed", self, "_on_fileDock_folder_removed"):
		fileDock.disconnect("folder_removed", self, "_on_fileDock_folder_removed")
	if fileDock.is_connected("folder_moved", self, "_on_fileDock_folder_moved"):
		fileDock.disconnect("folder_moved", self, "_on_fileDock_folder_moved")
	
	remove_autoload_singleton(MODULE_MANAGER_NAME)

func _on_fileDock_file_removed(p_file:String):
	if !data || !data.is_my_file(p_file):
		return
	
	data.load_data()

func _on_fileDock_files_moved(p_old:String, p_new):
	if !data || !data.is_my_file(p_old):
		return
	
	if data.is_module_desc_file(p_old) && data.is_module_desc_file(p_new):
		var dir = Directory.new()
		var path = data.get_module_bind_path_by_name(data.get_module_name_by_desc_path(p_old))
		if dir.file_exists(path):
			dir.rename(path, data.get_module_bind_path_by_name(data.get_module_name_by_desc_path(p_new)))
	data.load_data()

func _on_fileDock_folder_removed(p_folder:String):
	if !data:
		return
	
	if data.groupPath == p_folder || data.modulePath == p_folder || \
			p_folder.begins_with(data.moduleDescPath) || p_folder.begins_with(data.interfaceDescPath):
		data.load_data()

func _on_fileDock_folder_moved(p_old:String, p_new:String):
	if !data:
		return
	
	var dirty = false
	if p_old.begins_with(data.moduleDescPath):
		dirty = true
		if p_new.begins_with(data.moduleDescPath):
			data.module_desc_folder_rename_without_reload(p_old.substr(data.moduleDescPath.length()), 
					p_new.substr(data.moduleDescPath.length()))
	
	if p_old.begins_with(data.interfaceDescPath):
		dirty = true
	
	if data.groupPath == p_old:
		data.groupPath = p_new
		data.save_settings()
	if data.modulePath == p_old:
		data.modulePath = p_new
		data.save_settings()
	if data.moduleDescPath == p_old:
		data.moduleDescPath = p_new
		data.save_editor_settings()
	if data.interfaceDescPath == p_old:
		data.interfaceDescPath = p_new
		data.save_editor_settings()
	
	if dirty:
		data.load_data()
