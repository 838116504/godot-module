tool
extends Node

const MODULE_GROUP_FILE_PREFIX = "_mg_"
const MODULE_BIND_FILE_PREFIX = "_mb_"
const DEFAULT_MODULE_PATH = "res://module/bind/"
const DEFAULT_GROUP_PATH = "res://module/group/"
const Mod = preload("res://addons/module/mod.gd")

var groupPath:String
var modulePath:String
var autoGroups := {}		# [modules = [ name0, name1, ...], refCount]
var moduleGroups := {}		# modules = [ name0, name1, ...]
var modules := {}			# Mod
var interfaces := {}		# [ [lv, [priority, callObj, method]] ]

func _init():
	_load_paths()
	_update_module_group()

func _load_paths():
	var cfg = ConfigFile.new()
	if cfg.load(get_script().get_path().get_base_dir() + "/settings.cfg") == OK:
		groupPath = cfg.get_value("Path", "group", DEFAULT_GROUP_PATH)
		modulePath = cfg.get_value("Path", "module", DEFAULT_MODULE_PATH)
	else:
		groupPath = DEFAULT_GROUP_PATH
		modulePath = DEFAULT_MODULE_PATH

func _update_module_group():
	autoGroups.clear()
	var groups = get_module_groups()
	var data
	for g in groups:
		data = _load_group(g)
		if data && data[0]:
			autoGroups[g] = [data[1], 0]

func _ready():
	if !get_tree().is_connected("node_added", self, "_on_tree_node_added"):
		get_tree().connect("node_added", self, "_on_tree_node_added")
	if !get_tree().is_connected("node_removed", self, "_on_tree_node_removed"):
		get_tree().connect("node_removed", self, "_on_tree_node_removed")

func _exit_tree():
	if get_tree().is_connected("node_added", self, "_on_tree_node_added"):
		get_tree().disconnect("node_added", self, "_on_tree_node_added")
	if get_tree().is_connected("node_removed", self, "_on_tree_node_removed"):
		get_tree().disconnect("node_removed", self, "_on_tree_node_removed")

func _filename_to_group_name(p_filename:String):
	if p_filename.begins_with("res://"):
		p_filename = p_filename.substr("res://".length())
	while "/" in p_filename:
		p_filename = p_filename.replace("/", "-")

func _on_tree_node_added(p_node:Node):
	if !p_node.filename:
		return
	
	var groupName = _filename_to_group_name(p_node.filename)
	if autoGroups.has(groupName):
		autoGroups[groupName][1] += 1
		enable_module_group(groupName)

func _on_tree_node_removed(p_node:Node):
	if !p_node.filename:
		return
	
	var groupName = _filename_to_group_name(p_node.filename)
	if autoGroups.has(groupName):
		autoGroups[groupName][1] -= 1
		if autoGroups[groupName][1] <= 0:
			disable_module_group(groupName)

func clear():
	moduleGroups.clear()
	modules.clear()
	interfaces.clear()

func _get_group_path(p_group:String) -> String:
	return groupPath + MODULE_GROUP_FILE_PREFIX + p_group + ".cfg"

func _load_group(p_group:String):
	var path = _get_group_path(p_group)
	var cfg = ConfigFile.new()
	if cfg.load(path) == OK:
		return [cfg.get_value("group", "auto"), cfg.get_value("group", "modules")]
	return null

func enable_module_group(p_group:String):
	if moduleGroups.has(p_group):
		return
	
	if autoGroups.has(p_group):
		moduleGroups[p_group] = autoGroups[p_group][0]
	else:
		var groupData = _load_group(p_group)
		if !groupData:
			return
		
		moduleGroups[p_group] = groupData[1]
	
	_enable_modules(moduleGroups[p_group])

func _get_module_path(p_mod:String):
	return modulePath + MODULE_BIND_FILE_PREFIX + p_mod + ".cfg"

func _load_module(p_mod:String):
	var path = _get_module_path(p_mod)
	var cfg = ConfigFile.new()
	if cfg.load(path) == OK:
		return [cfg.get_value("module", "script_path", ""), cfg.get_value("module", "binds", [])]
	
	return null

func _enable_modules(p_mods:Array):
	var modData
	var lv
	var itf
	var meth
	
	for mod in p_mods:
		if modules.has(mod):
			modules[mod].enableCount += 1
			continue
		
		modData = _load_module(mod)
		if !modData:
			continue
		
		modules[mod] = Mod.new()
		modules[mod].callObj = load(modData[0])

		for bind in modData[1]:
			lv = bind[1]
			itf = bind[0]
			meth = bind[2]
			modules[mod].binds.append([itf, lv, meth])
			bind_interface(itf, lv, modules[mod].callObj, meth, bind[3])

func disable_module_group(p_group:String):
	if !is_module_group_enabled(p_group):
		return
	
	_disable_modules(moduleGroups[p_group])
	moduleGroups.erase(p_group)

func _disable_modules(p_mods:Array):
	var l:int
	var r:int
	var m:int
	for mod in p_mods:
		if !modules.has(mod):
			continue
		
		modules[mod].enableCount -= 1
		if modules[mod].enableCount == 0:
			for b in modules[mod].binds:
				unbind_interface(b[0], b[1], modules[mod].callObj, b[2])
			
			modules.erase(mod)

func is_module_group_enabled(p_group:String):
	return moduleGroups.has(p_group)

func get_module_groups():
	var dir := Directory.new()
	var ret = []
	if dir.open(groupPath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if filename.get_extension() == "cfg" && filename.begins_with(groupPath):
				ret.append(filename.get_basename().substr(groupPath.length()))
			filename = dir.get_next()
		dir.list_dir_end()
	return ret

func enable_module(p_mod:String):
	_enable_modules([p_mod])

func disable_module(p_mod:String):
	_disable_modules([p_mod])

func is_module_enabled(p_mod:String):
	return modules.has(p_mod)

func get_modules():
	var ret = []
	var dir = Directory.new()
	if dir.open(modulePath) == OK:
		dir.list_dir_begin(true)
		var filename = dir.get_next()
		while filename != "":
			if filename.get_extension() == "cfg" && filename.begins_with(MODULE_BIND_FILE_PREFIX):
				ret.append(filename.get_basename().substr(MODULE_BIND_FILE_PREFIX.length()))
			filename = dir.get_next()
		dir.list_dir_end()
	return ret

func get_module_script(p_mod:String):
	if modules.has(p_mod):
		return modules[p_mod].callObj
	
	return null

func bind_interface(p_itf:String, p_lv:int, p_obj, p_method:String, p_priority:int):
	var bindData = [p_priority, p_obj, p_method]
	var l:int
	var r:int
	var m:int
	if interfaces.has(p_itf):
		l = 0
		r = interfaces[p_itf].size() - 1
		while l <= r:
			m = (l + r) / 2
			if interfaces[p_itf][m][0] == p_lv:
				l = m
				break
			elif interfaces[p_itf][m][0] > p_lv:
				r = m - 1
			else:
				l = m + 1
		
		if interfaces[p_itf][l][0] != p_lv:
			interfaces[p_itf].insert(l, [p_lv, bindData])
		else:
			var t = interfaces[p_itf][l]
			l = 1
			r = t.size() - 1
			while l <= r:
				m = (l + r) / 2
				if t[m][0] >= bindData[0]:
					r = m - 1
				else:
					l = m + 1
			t[m].insert(l, bindData)
	else:
		interfaces[p_itf] = [ [p_lv, bindData] ]

func _find_interface_bind(p_itf:String, p_lv:int, p_obj, p_method:String):
	if !interfaces.has(p_itf):
		return null
	
	var l:int
	var r:int
	var m:int
	var itf = interfaces[p_itf]
	l = 0
	r = itf.size() - 1
	while l <= r:
		m = (l + r) / 2
		if itf[m][0] == p_lv:
			l = m
			break
		elif itf[m][0] > p_lv:
			r = m - 1
		else:
			l = m + 1
	
	if itf[l][0] != p_lv:
		return null
	
	for i in range(1, itf[l].size()):
		if itf[l][i][1] == p_obj && itf[l][i][2] == p_method:
			return [l, i]
	
	return null

func unbind_interface(p_itf:String, p_lv:int, p_obj, p_method:String):
	var find = _find_interface_bind(p_itf, p_lv, p_obj, p_method)
	if !find:
		return
	
	var itf = interfaces[p_itf]
	itf[find[0]].remove(find[1])
	if itf[find[0]].size() == 1:
		itf.remove(find[0])
		if itf.size() == 0:
			interfaces.erase(p_itf)

func is_interface_binded(p_itf:String, p_lv:int, p_obj, p_method:String):
	return _find_interface_bind(p_itf, p_lv, p_obj, p_method)

func get_binded_interfaces():
	return interfaces.keys()

remote func call_interface(p_itf:String, p_args:Array = []):
	if !interfaces.has(p_itf):
		return null
	
	var ret = null
	for i in interfaces[p_itf]:
		ret = i[1][1].callv(i[1][2], p_args)
		if ret:
			break
	
	return ret
