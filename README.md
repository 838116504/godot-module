[中文readme](README_zh.md)

# Introduction
Separating the interface from the features is equivalent to using multiple scripts to write the implementation of the same method. The calling interface is called with the name as the parameter through the use of the global node as the intermediary, which is equivalent to calling the global function.

Take the module as the unit, each module is bound with a script and N interfaces.

Each interface is divided into levels, and the binding modules are called from low to high. If the module method return no null, it will break call. If the same level is bound, the priority of the binding is determined. Only the lowest priority in the same level is called. If the priority same, the module that later binded call.

Modules are only useful after they are turned on. To facilitate opening, N modules can be packed into groups, and this group can be turned on or off directly. The group has an automatic loading feature. After this feature is turned on, the group is opened when a node with the same path as the group name joins the scene, and the group is closed when the node leaves the scene.


# Installing
Official installing plugin document︰[Link](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/installing_plugins.html)


# Usage
After enable this plugin, the ProjectSettings window will appear three Tabs(ModuleGroup, Module and Interface).

Module Panel︰for create module.
![](screenshot/modulePanel1.png)

1. Change module save path Button

2. Create module Button

3. Create Folder Button

4. Refresh Button

Below is table.
![](screenshot/modulePanel2.png)

1. Folder︰First column is folder icon. Second column is folder name. This column can edit. It drag to other folder.

2. Module︰First column is version. This column can edit. Second column is module name. It can drag to folder.

3. Interface︰First column is level it binded. This column can edit. Second column is interface.

ModuleGroup Panel︰For create module group
![](screenshot/moduleGroupPanel.png)
The top UI like Module Panel.

1. Module group︰First column is whether auto load. Second column is group name. This column can edit. The group name rule for auto load is remove 「res://」 from path than replace「/」to「-」.

2. Module︰First column is whether the module exists. Second column is module name.

Code part

After wirted the module script, if no add to module group that set auto load, need call moduleManager.enable_module_group(group:String) or moduleManager.enable_module(module:String) to enable.

Note: The module disable need the time that you enabled. The module group doesn't have this limit.

Then you can call moduleManager.call_interface(interface: String, params: Array = []) to indirect call your module, that is enabled, method.


# Document
moduleManager︰[Link](https://shimo.im/docs/Qcx9q68VJ8TKpKcp/)



