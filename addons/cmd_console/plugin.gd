# plugin.gd
@tool
extends EditorPlugin

var console_panel: Control

func _enter_tree():
    console_panel = preload("res://addons/cmd_console/console_panel.tscn").instantiate()
    
    if console_panel.custom_minimum_size == Vector2.ZERO:
        console_panel.custom_minimum_size = Vector2(300, 150)
    
    add_control_to_bottom_panel(console_panel, "Console")
    
    print("[Console] Successfully added to bottom panel")

func _exit_tree():
    if console_panel:
        remove_control_from_bottom_panel(console_panel)
        console_panel.queue_free()
        console_panel = null
