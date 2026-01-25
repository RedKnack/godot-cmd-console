@tool
extends Control


@onready var shell_opt: OptionButton = $"VBox/TopBar/Shell"
@onready var kill_btn: Button = $"VBox/TopBar/Kill"
@onready var clear_btn: Button = $"VBox/TopBar/Clear"
@onready var output: RichTextLabel = $"VBox/Scroll/Output"
@onready var cmd_line: LineEdit = $"VBox/BottomBar/Command"
@onready var run_btn: Button = $"VBox/BottomBar/Run"

var _history: PackedStringArray = []
var _history_index := -1

var _proc: Dictionary = {}
var _pid: int = -1
var _poll_timer: Timer
var _thread: Thread

func _ready() -> void:
    if shell_opt == null or kill_btn == null or clear_btn == null or output == null or cmd_line == null or run_btn == null:
        push_error("CMD Console: UI nodes missing. Please ensure console_panel.tscn is unchanged.")
        return

    _build_shell_list()

    clear_btn.pressed.connect(_on_clear_pressed)
    run_btn.pressed.connect(_on_run_pressed)
    kill_btn.pressed.connect(_on_kill_pressed)
    cmd_line.text_submitted.connect(_on_text_submitted)
    cmd_line.gui_input.connect(_on_cmd_gui_input)

    _poll_timer = Timer.new()
    _poll_timer.wait_time = 0.05
    _poll_timer.one_shot = false
    _poll_timer.timeout.connect(_on_poll_timeout)
    add_child(_poll_timer)
    output.set_scroll_follow(true)

    _append_line("CMD Console ready. Tip: on Windows we switch the shell to UTF-8 (chcp 65001 / UTF8 OutputEncoding).")

func _exit_tree() -> void:
    _stop_process()
    _stop_thread()

func _build_shell_list() -> void:
    shell_opt.clear()

    var os_name := OS.get_name()
    var items: Array = []

    # We store a small "wrap" mode per shell to force UTF-8 on Windows.
    if os_name == "Windows":
        items.append({
            "label":"cmd.exe (UTF-8)",
            "path":"cmd.exe",
            "prefix":["/C"],
            "wrap":"cmd_utf8"
        })
        items.append({
            "label":"PowerShell (UTF-8)",
            "path":"powershell.exe",
            "prefix":["-NoProfile", "-Command"],
            "wrap":"pwsh_utf8"
        })
    else:
        items.append({"label":"bash", "path":"bash", "prefix":["-lc"], "wrap":""})
        items.append({"label":"sh", "path":"sh", "prefix":["-lc"], "wrap":""})
        items.append({"label":"zsh", "path":"zsh", "prefix":["-lc"], "wrap":""})

    for i in items.size():
        shell_opt.add_item(items[i]["label"])
        shell_opt.set_item_metadata(i, items[i])

    shell_opt.select(0)

func _on_clear_pressed() -> void:
    if output:
        output.clear()

func _on_text_submitted(text: String) -> void:
    _run_command(text)

func _on_run_pressed() -> void:
    _run_command(cmd_line.text)

func _on_kill_pressed() -> void:
    _append_line("[kill] Attempting to terminate process…")
    if _pid > 0:
        OS.kill(_pid)
    _stop_process()

func _on_cmd_gui_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_UP:
                _history_prev()
                cmd_line.accept_event()
            KEY_DOWN:
                _history_next()
                cmd_line.accept_event()

func _history_prev() -> void:
    if _history.is_empty():
        return
    if _history_index == -1:
        _history_index = _history.size() - 1
    else:
        _history_index = max(_history_index - 1, 0)
    cmd_line.text = _history[_history_index]
    cmd_line.caret_column = cmd_line.text.length()

func _history_next() -> void:
    if _history.is_empty():
        return
    if _history_index == -1:
        return
    _history_index += 1
    if _history_index >= _history.size():
        _history_index = -1
        cmd_line.text = ""
    else:
        cmd_line.text = _history[_history_index]
        cmd_line.caret_column = cmd_line.text.length()

func _run_command(raw: String) -> void:
    var command := raw.strip_edges()
    if command.is_empty():
        return
    if command.to_lower().begins_with("tree") and !(command.to_lower().contains("/a") or command.to_lower().contains("/f")):
        command += " /a /f"
    if _history.is_empty() or _history[_history.size() - 1] != command:
        _history.append(command)
    _history_index = -1

    cmd_line.text = ""
    cmd_line.grab_focus()

    _append_line("")
    _append_line(" [color=#FFEE00]→[/color]\"[color=#00FFBB][b]"+ command + "[/b][/color]\"")

    _stop_process()
    _stop_thread()

    var meta: Dictionary = shell_opt.get_selected_metadata()
    var path: String = meta.get("path", "")
    var prefix: PackedStringArray = meta.get("prefix", PackedStringArray())
    var wrap: String = str(meta.get("wrap", ""))

    var args: PackedStringArray = prefix.duplicate()

    # Force UTF-8 output on Windows to avoid "Invalid UTF-8" spam in the GODOT-CONSOLE.
    # cmd.exe outputs in OEM codepage by default; chcp 65001 switches to UTF-8 for the session.
    # change if needed! chcp 850, 437 or 65001. 65001 is recommended!
    if wrap == "cmd_utf8":
        args.append("chcp 65001>nul & " + command)
    elif wrap == "pwsh_utf8":
        # Ensure both managed and native command output is UTF-8.
        var prolog := "$OutputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; "
        args.append(prolog + command)
    else:
        args.append(command)

    var p := OS.execute_with_pipe(path, args, false)
    if p.is_empty():
        _append_line("[warn] OS.execute_with_pipe() failed; falling back to threaded OS.execute().")
        _start_thread_execute(path, args)
        return

    _proc = p
    _pid = int(_proc.get("pid", -1))

    run_btn.disabled = true
    kill_btn.disabled = false
    _poll_timer.start()

func _start_thread_execute(path: String, args: PackedStringArray) -> void:
    run_btn.disabled = true
    kill_btn.disabled = true

    _thread = Thread.new()
    _thread.start(Callable(self, "_thread_execute").bind(path, args))

func _thread_execute(path: String, args: PackedStringArray) -> void:
    var out: Array = []
    var code := OS.execute(path, args, out, true, false) # read_stderr=true
    var text := ""
    for i in out.size():
        text += str(out[i])
        if i != out.size() - 1:
            text += "\n"
    call_deferred("_on_thread_done", code, text)

func _on_thread_done(code: int, text: String) -> void:
    if not text.is_empty():
        _append(text)
    _append_line("\n[color=#DDAA00][exit] code=" + str(code) + "[/color]")
    run_btn.disabled = false
    kill_btn.disabled = true
    _stop_thread()

func _on_poll_timeout() -> void:
    if _pid <= 0 or _proc.is_empty():
        _poll_timer.stop()
        run_btn.disabled = false
        kill_btn.disabled = true
        return

    _read_pipe(_proc.get("stdio"), false)
    _read_pipe(_proc.get("stderr"), true)

    if not OS.is_process_running(_pid):
        _read_pipe(_proc.get("stdio"), false)
        _read_pipe(_proc.get("stderr"), true)

        _append_line("\n====[color=#DDAAFF][exit] pid=" + str(_pid) + " finished.[/color]====")
        _stop_process()
        run_btn.disabled = false
        kill_btn.disabled = true

func _read_pipe(fa, is_err: bool) -> void:
    if fa == null:
        return

    var file: FileAccess = fa
    while true:
        var chunk: PackedByteArray = file.get_buffer(4096)
        if chunk.is_empty():
            break

        # With the Windows UTF-8 wrappers above, this should be valid UTF-8.
        var text := chunk.get_string_from_utf8()

        if is_err and not text.is_empty():
            _append("[color=#FF5555][stderr] " + text + "[/color]")
        else:
            _append(text)

func _stop_process() -> void:
    if _poll_timer:
        _poll_timer.stop()
    if _proc.has("stdio") and _proc["stdio"] != null:
        _proc["stdio"].close()
    if _proc.has("stderr") and _proc["stderr"] != null:
        _proc["stderr"].close()
    _proc = {}
    _pid = -1

func _stop_thread() -> void:
    if _thread:
        _thread.wait_to_finish()
        _thread = null

func _append(text: String) -> void:
    if output == null:
        return
    output.append_text(text)
    _scroll_to_end()

func _append_line(text: String) -> void:
    if output == null:
        return
    output.append_text(text + "\n")
    _scroll_to_end()

func _scroll_to_end() -> void:
    pass
    #call_deferred("_scroll_to_end_deferred")

func _scroll_to_end_deferred() -> void:
    if output == null:
        return
    output.scroll_to_line(max(output.get_line_count() - 1, 0))
