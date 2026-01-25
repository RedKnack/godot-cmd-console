@tool
extends EditorPlugin

var panel: Control

func _enter_tree() -> void:
    panel = preload("res://addons/cmd_console/console_panel.tscn").instantiate()
    add_control_to_bottom_panel(panel, "CMD")

func _exit_tree() -> void:
    if panel:
        remove_control_from_bottom_panel(panel)
        panel.queue_free()
        panel = null
