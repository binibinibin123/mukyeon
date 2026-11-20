extends Node2D
## Ink pond wallpaper.
## Test flags after `--`: --windowed (do not attach to the desktop), --shot=PATH,
## --demo (scripted cursor and fixed random seed, for recording the demo video).

const SIM_SIZE := Vector2i(480, 270)
const PAUSE_PORT := 47631
const FPS := 30
const FPS_ACTIVE := 60

var size := Vector2(1920, 1080)
var sim_a: SubViewport
var sim_b: SubViewport
var sim_mat: ShaderMaterial
var school: Node2D
var udp := PacketPeerUDP.new()
var paused := false
var last_cursor := Vector2.ZERO
var fish_turn := 0
var active_until := 0
var demo := false
var demo_t := 0.0
var demo_cursor: Node2D
var log_t := 0.0
var log_n := 0
var log_sum := 0.0
var log_max := 0.0
var log_slow := 0
var shot_path := ""
var shot_frames := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var screen := DisplayServer.get_primary_screen()
	size = DisplayServer.screen_get_size(screen)
	get_window().position = DisplayServer.screen_get_position(screen)
	get_window().size = Vector2i(size)
	Engine.max_fps = FPS
	demo = "--demo" in args
	if demo:
		seed(7)
	for a in args:
		if a.begins_with("--shot="):
			shot_path = a.trim_prefix("--shot=")
			shot_frames = 900

	var paper_tex := _bake_paper()
	var carps: Array[Texture2D] = [_mip("res://assets/carp_a.png"), _mip("res://assets/carp_b.png")]
	_build_sim()
	var sim_tex := sim_b.get_texture()

	var paper := ColorRect.new()
	paper.size = size
	paper.material = _mat("res://shaders/paper_view.gdshader", {"paper": paper_tex, "sim": sim_tex})
	add_child(paper)

	school = preload("res://fish_school.gd").new()
	school.material = _mat("res://shaders/fish.gdshader", {})
	add_child(school)
	school.setup(carps, size)

	var willow := Sprite2D.new()
	willow.texture = load("res://assets/willow.png")
	willow.centered = false
	var wscale := size.x * 0.62 / willow.texture.get_width()
	willow.scale = Vector2(wscale, wscale)
	willow.material = _mat("res://shaders/mul_sway.gdshader", {"sway": 0.012})
	add_child(willow)

	var lotus := Sprite2D.new()
	lotus.texture = load("res://assets/lotus.png")
	var lscale := size.y * 0.52 / lotus.texture.get_height()
	lotus.scale = Vector2(lscale, lscale)
	lotus.position = size - Vector2(size.y * 0.2, size.y * 0.17)
	lotus.material = _mat("res://shaders/mul_sway.gdshader", {"sway": 0.0})
	add_child(lotus)

	var water := ColorRect.new()
	water.size = size
	water.material = _mat("res://shaders/water.gdshader", {"sim": sim_tex, "texel": Vector2.ONE / Vector2(SIM_SIZE)})
	add_child(water)

	if demo:
		demo_cursor = _make_demo_cursor()
		add_child(demo_cursor)

	if "--windowed" not in args:
		_add_tray()
		udp.bind(PAUSE_PORT, "127.0.0.1")
		var helper := OS.get_executable_path().get_base_dir().path_join("mukyeon_helper.exe")
		if not FileAccess.file_exists(helper):
			helper = ProjectSettings.globalize_path("res://helper/mukyeon_helper.exe")
		var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
		OS.create_process(helper, [str(hwnd), str(OS.get_process_id())])

func _make_demo_cursor() -> Node2D:
	var root := Node2D.new()
	var outline := Polygon2D.new()
	outline.polygon = PackedVector2Array([Vector2(-2, -3), Vector2(-2, 29), Vector2(7, 21), Vector2(13, 34), Vector2(19, 31), Vector2(13, 19), Vector2(26, 19)])
	outline.color = Color(0.08, 0.08, 0.09, 0.9)
	root.add_child(outline)
	var fill := Polygon2D.new()
	fill.polygon = PackedVector2Array([Vector2(1, 3), Vector2(1, 23), Vector2(7, 17), Vector2(14, 31), Vector2(16, 30), Vector2(10, 16), Vector2(19, 16)])
	fill.color = Color(1, 1, 1, 0.96)
	root.add_child(fill)
	return root

## Where the demo cursor is at time t, as a screen position; (-1, -1) = away from the screen.
func _demo_cursor_at(t: float) -> Vector2:
	# [time, x, y]: slow strokes, a calm circle, then one flick that scares the nearest fish.
	var keys := [
		[5.0, 0.0, 640.0], [8.0, 430.0, 610.0], [11.0, 760.0, 410.0], [14.0, 1110.0, 520.0],
		[17.0, 1250.0, 720.0], [19.0, 560.0, 330.0], [20.0, 960.0 + 260.0, 540.0],
	]
	if t < 5.0:
		return Vector2(-1, -1)
	if t < 20.0:
		for i in range(keys.size() - 1):
			var a: Array = keys[i]
			var b: Array = keys[i + 1]
			if t <= b[0]:
				var k := smoothstep(0.0, 1.0, (t - a[0]) / (b[0] - a[0]))
				return Vector2(a[1], a[2]).lerp(Vector2(b[1], b[2]), k)
	var circle_end := _demo_circle(1.1)
	if t < 25.0: # one slow circle around the middle of the pond
		return _demo_circle((t - 20.0) / 5.0 * 1.1)
	if t < 25.8:
		return circle_end.lerp(Vector2(1400.0, 520.0), smoothstep(0.0, 1.0, (t - 25.0) / 0.8))
	if t < 25.9: # the flick, fast enough to startle the fish beside it
		return Vector2(1400.0, 520.0).lerp(Vector2(1830.0, 640.0), (t - 25.8) / 0.1)
	return Vector2(1830.0, 640.0)

func _demo_circle(turns: float) -> Vector2:
	var ang := turns * TAU
	return Vector2(960.0, 540.0) + Vector2(cos(ang), sin(ang)) * Vector2(260.0, 190.0)

func _mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _mip(path: String) -> Texture2D:
	var img: Image = (load(path) as Texture2D).get_image()
	img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _bake_paper() -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(size)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := ColorRect.new()
	r.size = size
	r.material = _mat("res://shaders/paper_bake.gdshader", {"res": size})
	vp.add_child(r)
	add_child(vp)
	return vp.get_texture()

func _sim_view() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIM_SIZE
	vp.use_hdr_2d = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	var r := ColorRect.new()
	r.size = Vector2(SIM_SIZE)
	vp.add_child(r)
	add_child(vp)
	return vp

func _build_sim() -> void:
	sim_a = _sim_view()
	sim_b = _sim_view()
	var params := {
		"texel": Vector2.ONE / Vector2(SIM_SIZE),
		"aspect": size.x / size.y,
	}
	sim_mat = _mat("res://shaders/sim.gdshader", params)
	sim_mat.set_shader_parameter("prev", sim_b.get_texture())
	(sim_a.get_child(0) as ColorRect).material = sim_mat
	var other := _mat("res://shaders/sim.gdshader", params)
	other.set_shader_parameter("prev", sim_a.get_texture())
	(sim_b.get_child(0) as ColorRect).material = other

func _add_tray() -> void:
	var menu := PopupMenu.new()
	menu.prefer_native_menu = true
	menu.add_item("Quit", 0)
	menu.id_pressed.connect(func(_id): get_tree().quit())
	add_child(menu)
	var tray := StatusIndicator.new()
	tray.tooltip = "Mukyeon"
	var icon := (load("res://assets/carp_b.png") as Texture2D).get_image()
	icon.decompress()
	icon.resize(64, 64)
	tray.icon = ImageTexture.create_from_image(icon)
	add_child(tray)
	tray.menu = tray.get_path_to(menu)

## Prints frame-time stats every 10 s while running: godot.log shows where it stutters.
func _log_frames(delta: float) -> void:
	log_t += delta
	log_n += 1
	log_sum += delta
	log_max = maxf(log_max, delta)
	if delta > 0.05:
		log_slow += 1
	if log_t >= 10.0:
		print("%.1f frames=%d avg=%.1fms max=%.0fms over50ms=%d fps_cap=%d" % [
			Time.get_ticks_msec() / 1000.0, log_n, log_sum / log_n * 1000.0, log_max * 1000.0, log_slow, Engine.max_fps])
		log_t = 0.0
		log_n = 0
		log_sum = 0.0
		log_max = 0.0
		log_slow = 0

func _set_paused(on: bool) -> void:
	if on == paused:
		return
	paused = on
	print("%.1f paused=%s" % [Time.get_ticks_msec() / 1000.0, on])
	RenderingServer.render_loop_enabled = not on
	Engine.max_fps = 4 if on else FPS

func _process(delta: float) -> void:
	while udp.is_bound() and udp.get_available_packet_count() > 0:
		_set_paused(udp.get_packet().get_string_from_ascii() == "1")
	if paused:
		return
	var dt := minf(delta, 0.1)
	_log_frames(delta)

	var cursor := Vector2(DisplayServer.mouse_get_position())
	if demo:
		demo_t += delta
		cursor = _demo_cursor_at(demo_t)
		demo_cursor.visible = cursor.x >= 0.0
		demo_cursor.position = cursor
	if shot_path != "":
		if "--real-cursor" not in OS.get_cmdline_user_args():
			var t := Time.get_ticks_msec() / 1000.0
			cursor = size * 0.5 + Vector2(cos(t * 0.5) * 520, sin(t * 0.8) * 300)
		shot_frames -= 1
		if shot_frames <= 0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
	var cursor_on := cursor.x >= 0 and cursor.y >= 0 and cursor.x < size.x and cursor.y < size.y
	var moved := cursor - last_cursor
	last_cursor = cursor
	# Smooth cursor ripples need 60 fps; the slow fish and idle pond do not.
	if moved.length() > 0.5:
		active_until = Time.get_ticks_msec() + 2000
	Engine.max_fps = FPS_ACTIVE if Time.get_ticks_msec() < active_until else FPS
	school.step(dt, cursor, moved.length() / dt, cursor_on)

	var stamps := PackedVector4Array()
	var pushes := PackedFloat32Array()
	if cursor_on and moved.length() > 0.5:
		var uv := cursor / size
		stamps.append(Vector4(uv.x, uv.y, 0.011, clampf(moved.length() * 0.02, 0.0, 0.5)))
		pushes.append(clampf(moved.length() * 0.001, 0.0, 0.025))
	for i in 2: # fish tails take turns leaving a thin wake
		fish_turn = (fish_turn + 1) % school.fish.size()
		var f = school.fish[fish_turn]
		var tail: Vector2 = f.spine[f.spine.size() - 2] / size
		stamps.append(Vector4(tail.x, tail.y, 0.009, 0.01))
		pushes.append(0.0012 * sin(f.phase))
	var count := stamps.size()
	stamps.resize(16)
	pushes.resize(16)
	sim_mat.set_shader_parameter("stamp_count", count)
	sim_mat.set_shader_parameter("stamps", stamps)
	sim_mat.set_shader_parameter("pushes", pushes)
