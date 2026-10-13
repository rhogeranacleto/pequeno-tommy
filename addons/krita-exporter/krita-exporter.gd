@tool
extends EditorPlugin

var import_plugin

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	import_plugin = preload("import_plugin.gd").new()
	add_import_plugin(import_plugin)
	pass


func _exit_tree() -> void:
	remove_import_plugin(import_plugin)
	import_plugin = null
	pass
