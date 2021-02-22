tool
extends Reference

const MODULE_DESC_FILE_PREFIX = "_md_"
const INTERFACE_DESC_FILE_PREFIX = "_id_"

const ModuleManager = preload("moduleManager.gd")
const DEFAULT_MODULE_DESC_PATH = "res://module/mod_desc/"
const DEFAULT_INTERFACE_DESC_PATH = "res://module/itf_desc/"

var groupPath = ModuleManager.DEFAULT_GROUP_PATH
var modulePath = ModuleManager.DEFAULT_MODULE_PATH
var moduleDescPath = DEFAULT_MODULE_DESC_PATH
var interfaceDescPath = DEFAULT_INTERFACE_DESC_PATH
var groups = {}				# [ auto, modules = [ name0, name1, ...] ]
var modules = {}			# [ gdPath, binds = [[ interface, lv, method, priority ], ...] ]
var moduleDesc = {}			# [ name, desc, version ]
var interfaceDesc = {}		# [ dir, desc, params = "p_a:type, p_b:type"


func is_my_file(p_path:String) -> bool:
	return is_group_file(p_path) || is_module_bind_file(p_path) || is_module_desc_file(p_path) || is_interface_desc_file(p_path)

func is_group_file(p_path:String) -> bool:
	return p_path.get_base_dir() + "/" == groupPath && p_path.get_file().begins_with(ModuleManager.MODULE_GROUP_FILE_PREFIX) && p_path.get_extension() == "cfg"

func is_module_bind_file(p_path:String):
	return p_path.get_base_dir() + "/" == modulePath && p_path.get_file().begins_with(ModuleManager.MODULE_BIND_FILE_PREFIX) && p_path.get_extension() == "cfg"

func is_module_desc_file(p_path:String) -> bool:
	return p_path.begins_with(moduleDescPath) == moduleDescPath && p_path.get_file().begins_with(MODULE_DESC_FILE_PREFIX) && p_path.get_extension() == "cfg"

func is_interface_desc_file(p_path:String) -> bool:
	return p_path.begins_with(interfaceDescPath) && p_path.get_file().begins_with(INTERFACE_DESC_FILE_PREFIX) && p_path.get_extension() == "cfg"

func load_editor_settings():
	var cfg = ConfigFile.new()
	if cfg.load(get_script().get_path().get_base_dir() + "/editorSettings.cfg") == OK:
		moduleDescPath = cfg.get_value("Path", "module_desc", DEFAULT_MODULE_DESC_PATH)
		interfaceDescPath = cfg.get_value("Path", "interface_desc", DEFAULT_INTERFACE_DESC_PATH)
	else:
		moduleDescPath = DEFAULT_MODULE_DESC_PATH
		interfaceDescPath = DEFAULT_INTERFACE_DESC_PATH
	
	var dir = Directory.new()
	dir.make_dir_recursive(moduleDescPath)
	dir.make_dir_recursive(interfaceDescPath)

func save_editor_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("Path", "module_desc", moduleDescPath)
	cfg.set_value("Path", "interface_desc", interfaceDescPath)
	cfg.save(get_script().get_path().get_base_dir() + "/editorSettings.cfg")

func load_settings():
	var cfg = ConfigFile.new()
	if cfg.load(get_script().get_path().get_base_dir() + "/settings.cfg") == OK:
		groupPath = cfg.get_value("Path", "group", ModuleManager.DEFAULT_GROUP_PATH)
		modulePath = cfg.get_value("Path", "module", ModuleManager.DEFAULT_MODULE_PATH)
	else:
		groupPath = ModuleManager.DEFAULT_GROUP_PATH
		modulePath = ModuleManager.DEFAULT_MODULE_PATH
	
	var dir = Directory.new()
	dir.make_dir_recursive(groupPath)
	dir.make_dir_recursive(modulePath)

func save_settings():
	var cfg = ConfigFile.new()
	cfg.set_value("Path", "group", groupPath)
	cfg.set_value("Path", "module", modulePath)
	cfg.save(get_script().get_path().get_base_dir() + "/settings.cfg")

func load_data():
	groups.clear()
	var dir = Directory.new()
	var cfg = ConfigFile.new()
	if dir.open(groupPath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if !dir.current_is_dir() && filename.begins_with(ModuleManager.MODULE_GROUP_FILE_PREFIX) && filename.get_extension() == "cfg" && \
					cfg.load(groupPath + filename) == OK:
				groups[filename.get_basename().substr(ModuleManager.MODULE_GROUP_FILE_PREFIX.length())] = \
						[cfg.get_value("group", "auto", false), cfg.get_value("group", "modules", [])]
			filename = dir.get_next()
		dir.list_dir_end()
	
	modules.clear()
	if dir.open(modulePath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if !dir.current_is_dir() && filename.begins_with(ModuleManager.MODULE_BIND_FILE_PREFIX) && filename.get_extension() == "cfg" && \
					cfg.load(modulePath + filename) == OK:
				var modName = filename.get_basename().substr(ModuleManager.MODULE_BIND_FILE_PREFIX.length())
				modules[modName] = [cfg.get_value("module", "script_path", ""), cfg.get_value("module", "binds", [])]
			filename = dir.get_next()
		dir.list_dir_end()
	
	moduleDesc.clear()
	load_module_desc("")
	
	interfaceDesc.clear()
	load_interface_desc("")

func load_module_desc(p_dir:String):
	var dir = Directory.new()
	var path = moduleDescPath + p_dir
	if dir.open(path) == OK:
		var cfg = ConfigFile.new()
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if dir.current_is_dir():
				load_module_desc(p_dir + filename + "/")
			elif filename.begins_with(MODULE_DESC_FILE_PREFIX) && filename.get_extension() == "cfg" && \
					cfg.load(path + filename) == OK:
				var modName = get_module_name_by_desc_path(path + filename)
				moduleDesc[modName] = [cfg.get_value("module", "name", "no name"), cfg.get_value("module", "description", "no description"), 
						cfg.get_value("module", "version", "1.0.0")]
			filename = dir.get_next()
		dir.list_dir_end()

func load_interface_desc(p_dir:String):
	var path = interfaceDescPath + p_dir
	var dir = Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true)
		var filename:String = dir.get_next()
		var cfg = ConfigFile.new()
		while filename != "":
			if dir.current_is_dir():
				load_interface_desc(p_dir + filename + "/")
			elif filename.begins_with(INTERFACE_DESC_FILE_PREFIX) && filename.get_extension() == "cfg" && \
					cfg.load(path + filename) == OK:
				var itf = filename.get_basename().substr(INTERFACE_DESC_FILE_PREFIX.length())
				interfaceDesc[itf] = [ p_dir, cfg.get_value("interface", "description", ""), cfg.get_value("interface", "params", "") ]
			filename = dir.get_next()
		dir.list_dir_end()

func save_group(p_name:String):
	if !groups.has(p_name):
		return
	
	var cfg = ConfigFile.new()
	if groups[p_name][0]:
		cfg.set_value("group", "auto", true)
	cfg.set_value("group", "modules", groups[p_name][1])
	cfg.save(groupPath + ModuleManager.MODULE_GROUP_FILE_PREFIX + p_name + ".cfg")

func save_module_desc(p_name:String):
	if !moduleDesc.has(p_name):
		return
	var cfg = ConfigFile.new()
	cfg.set_value("module", "name", moduleDesc[p_name][0])
	cfg.set_value("module", "description", moduleDesc[p_name][1])
	cfg.set_value("module", "version", moduleDesc[p_name][2])
	cfg.save(get_module_desc_path_by_name(p_name))

func save_module_bind(p_name:String):
	if !modules.has(p_name):
		return
	
	var cfg = ConfigFile.new()
	cfg.set_value("module", "script_path", modules[p_name][0])
	cfg.set_value("module", "binds", modules[p_name][1])
	cfg.save(get_module_bind_path_by_name(p_name))

func save_interface_desc(p_name:String):
	if !interfaceDesc.has(p_name):
		return
	
	var cfg = ConfigFile.new()
	cfg.set_value("interface", "description", interfaceDesc[p_name][1])
	cfg.set_value("interface", "params", interfaceDesc[p_name][2])
	cfg.save(interface_desc_get_path(p_name))

func get_group_new_name():
	var ret = "group"
	var count = 2
	while groups.has(ret):
		ret = "group" + str(count)
		count += 1
	
	return ret

func add_group(p_name:String, p_auto:bool = false, p_modules := []):
	if groups.has(p_name):
		return
	
	groups[p_name] = [p_auto, p_modules]
	save_group(p_name)

func erase_group(p_name:String):
	if !groups.has(p_name):
		return
	
	groups.erase(p_name)
	var dir = Directory.new()
	var path = groupPath + ModuleManager.MODULE_GROUP_FILE_PREFIX + p_name + ".cfg"
	if dir.file_exists(path):
		dir.remove(path)

func group_set_name(p_old:String, p_new:String):
	if !groups.has(p_old) || groups.has(p_new):
		return
	
	var temp = groups[p_old]
	groups.erase(p_old)
	groups[p_new] = temp
	var dir = Directory.new()
	var path = groupPath + ModuleManager.MODULE_GROUP_FILE_PREFIX + p_old + ".cfg"
	if dir.file_exists(path):
		dir.rename(path, groupPath + ModuleManager.MODULE_GROUP_FILE_PREFIX + p_new + ".cfg")
	else:
		save_group(p_new)

func group_set_auto(p_name:String, p_auto:bool):
	if !groups.has(p_name):
		return
	
	groups[p_name][0] = p_auto
	save_group(p_name)

func add_group_module(p_name:String, p_module:String):
	if !groups.has(p_name):
		return
	
	groups[p_name][1].append(p_module)
	save_group(p_name)

func remove_group_module(p_name:String, p_module:String):
	if !groups.has(p_name):
		return
	
	groups[p_name][1].erase(p_module)
	save_group(p_name)

func set_group_path(p_path:String):
	if p_path == groupPath:
		return
	
	if !p_path.ends_with("/") && !p_path.ends_with("\\"):
		p_path += "/"
	
	var dir = Directory.new()
	dir.make_dir_recursive(p_path)
	
	if dir.open(groupPath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if !dir.current_is_dir() && filename.begins_with(ModuleManager.MODULE_GROUP_FILE_PREFIX) && filename.get_extension() == "cfg":
				dir.rename(groupPath + filename, p_path + filename)
			filename = dir.get_next()
		dir.list_dir_end()
	
	groupPath = p_path
	save_settings()

func set_module_path(p_path:String):
	if p_path == modulePath:
		return
	
	if !p_path.ends_with("/") && !p_path.ends_with("\\"):
		p_path += "/"
	
	var dir = Directory.new()
	dir.make_dir_recursive(p_path)
	
	if dir.open(modulePath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if !dir.current_is_dir() && filename.begins_with(ModuleManager.MODULE_BIND_FILE_PREFIX) && filename.get_extension() == "cfg":
				dir.rename(modulePath + filename, p_path + filename)
			filename = dir.get_next()
		dir.list_dir_end()
	
	modulePath = p_path
	save_settings()

func create_module(p_filename:String, p_name:String, p_desc:String, p_version:String, p_gdPath:String):
	moduleDesc[p_filename] = [ p_name, p_desc, p_version ]
	save_module_desc(p_filename)
	modules[p_filename] = [ p_gdPath, [] ]
	save_module_bind(p_filename)

func get_module_name_by_desc_path(p_path:String):
	var ret:String = p_path.get_base_dir() + "/" + p_path.get_basename().get_file().substr(MODULE_DESC_FILE_PREFIX.length())
	if p_path.begins_with(moduleDescPath):
		ret = ret.substr(moduleDescPath.length())
	while "/" in ret:
		ret = ret.replace("/", "-")
	
	while "\\" in ret:
		ret = ret.replace("\\", "-")
	
	return ret

func get_module_desc_path_by_name(p_name:String):
	var ret:String = p_name
	while "-" in ret:
		ret = ret.replace("-", "/")
	
	if "/" in ret:
		ret = ret.get_base_dir() + "/" + MODULE_DESC_FILE_PREFIX + ret.get_file() + ".cfg"
	else:
		ret = MODULE_DESC_FILE_PREFIX + ret + ".cfg"
	return moduleDescPath + ret

func get_module_bind_path_by_name(p_name:String):
	return modulePath + ModuleManager.MODULE_BIND_FILE_PREFIX + p_name + ".cfg"

func rename_module(p_old:String, p_new:String):
	if p_old == p_new:
		return
	
	var descPath = get_module_desc_path_by_name(p_old)
	var dir = Directory.new()
	if dir.file_exists(descPath):
		dir.rename(descPath, get_module_desc_path_by_name(p_new))
	
	if moduleDesc.has(p_old):
		moduleDesc[p_new] = moduleDesc[p_old]
		moduleDesc.erase(p_old)
	
	var bindPath = get_module_bind_path_by_name(p_old)
	if dir.file_exists(bindPath):
		dir.rename(bindPath, get_module_bind_path_by_name(p_new))
	
	if modules.has(p_old):
		modules[p_new] = modules[p_old]
		modules.erase(p_old)
	
	for i in groups.keys():
		for j in groups[i][1].size():
			if groups[i][1][j] == p_old:
				groups[i][1][j] = p_new
				save_group(i)
				break

func module_add_interface_bind(p_mod:String, p_interface:String, p_lv:int, p_method:String, p_priority:int):
	if !modules.has(p_mod):
		modules[p_mod] = [ "", [] ]
	
	modules[p_mod][1].append([p_interface, p_lv, p_method, p_priority])
	save_module_bind(p_mod)

func module_set_interface_bind(p_mod:String, p_interfaceIdx:int, p_interface:String, p_lv:int, p_method:String, p_priority:int):
	if !modules.has(p_mod) || modules[p_mod][1].size() <= p_interfaceIdx:
		return
	
	modules[p_mod][1][p_interfaceIdx] = [p_interface, p_lv, p_method, p_priority]
	save_module_bind(p_mod)

func module_remove_interface_bind(p_mod:String, p_interfaceIdx:int):
	if !modules.has(p_mod) || modules[p_mod][1].size() <= p_interfaceIdx:
		return
	
	modules[p_mod][1].remove(p_interfaceIdx)
	save_module_bind(p_mod)

func module_set_version(p_mod:String, p_version:String):
	if !moduleDesc.has(p_mod):
		moduleDesc[p_mod] = [ p_mod, "", p_version ]
	else:
		moduleDesc[p_mod][2] = p_version
	
	save_module_desc(p_mod)

func module_set_interface_lv(p_mod:String, p_interfaceIdx:int, p_lv:int):
	if !modules.has(p_mod) || modules[p_mod][1].size() <= p_interfaceIdx  || \
			modules[p_mod][1][p_interfaceIdx][1] == p_lv:
		return
	
	modules[p_mod][1][p_interfaceIdx][1] = p_lv
	save_module_bind(p_mod)

func module_desc_folder_rename(p_old:String, p_new:String):
	module_desc_folder_rename_without_reload(p_old, p_new)
	load_data()
	
func module_desc_folder_rename_without_reload(p_old:String, p_new:String):
	var dir = Directory.new()
	if dir.open(modulePath) == OK:
		var modDirName := p_old
		while "/" in modDirName:
			modDirName = modDirName.replace("/", "-")
		
		while "\\" in modDirName:
			modDirName = modDirName.replace("\\", "-")
		
		var newDirName = p_new
		while "/" in newDirName:
			newDirName = newDirName.replace("/", "-")
		
		while "\\" in newDirName:
			newDirName = newDirName.replace("\\", "-")
		
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if !dir.current_is_dir() && filename.begins_with(ModuleManager.MODULE_BIND_FILE_PREFIX) && filename.get_extension() == "cfg":
				if filename.substr(ModuleManager.MODULE_BIND_FILE_PREFIX.length()).begins_with(modDirName):
					dir.rename(modulePath + filename, modulePath + filename.replace(modDirName, newDirName))
			filename = dir.get_next()
		dir.list_dir_end()

func module_desc_set_folder_path(p_mod:String, p_path:String):
	if p_path.length() > 0 && p_path[p_path.length()-1] != "/" && p_path[p_path.length()-1] != "\\":
		p_path += "/"
	
	var find = p_mod.find_last("-")
	if find >= 0:
		p_path += MODULE_DESC_FILE_PREFIX + p_mod.substr(find + 1) + ".cfg"
	else:
		p_path += MODULE_DESC_FILE_PREFIX + p_mod + ".cfg"
	var newModName = get_module_name_by_desc_path(moduleDescPath + p_path)
	if p_mod == newModName:
		return
	
	if modules.has(p_mod):
		var dir = Directory.new()
		dir.rename(modulePath + ModuleManager.MODULE_BIND_FILE_PREFIX + p_mod + ".cfg", 
				modulePath + ModuleManager.MODULE_BIND_FILE_PREFIX + newModName + ".cfg")
		modules[newModName] = modules[p_mod]
		modules.erase(p_mod)
	
	if moduleDesc.has(p_mod):
		var dir = Directory.new()
		dir.rename(get_module_desc_path_by_name(p_mod), 
				get_module_desc_path_by_name(newModName))
		moduleDesc[newModName] = moduleDesc[p_mod]
		moduleDesc.erase(p_mod)

func set_interface_desc(p_interface:String, p_path:String, p_desc:String, p_params:String):
	var oldPath = interface_desc_get_path(p_interface)
	if oldPath != "":
		var dir = Directory.new()
		if dir.file_exists(oldPath):
			dir.remove(oldPath)
	interfaceDesc[p_interface] = [ p_path, p_desc, p_params ]
	save_interface_desc(p_interface)

func interface_desc_get_path(p_name:String):
	if !interfaceDesc.has(p_name):
		return ""
	return interfaceDescPath + interfaceDesc[p_name][0] + INTERFACE_DESC_FILE_PREFIX + p_name + ".cfg"

func rename_interface(p_old:String, p_new:String):
	if interfaceDesc.has(p_old):
		var oldPath = interface_desc_get_path(p_old)
		if oldPath != "":
			var dir = Directory.new()
			if dir.file_exists(oldPath):
				dir.remove(oldPath)
		interfaceDesc[p_new] = interfaceDesc[p_old]
		interfaceDesc.erase(p_old)
		save_interface_desc(p_new)
	
	var changed
	for i in modules.keys():
		changed = false
		for j in modules[i][1]:
			if j[0] == p_old:
				changed = true
				j[0] = p_new
		
		if changed:
			save_module_bind(i)
