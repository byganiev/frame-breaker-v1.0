extends Node2D

# --- SKETCHBOOK Atmosphere ---
const BEANIE_COLOR := Color("#f4c430")
const SCARF_COLOR := Color("#e74c3c")
const INK_COLOR := Color("#1b1918")
const PAPER_COLOR := Color("#fdfaf1")

var state := "TITLE" # "TITLE", "PLAY", "WIN"
var level := 1
var total_grabs := 0
var run_time := 0.0

var panel_pos := Vector2(160, 120)
var panel_top_y := 0.0
var panel_w := 860.0
var panel_h := 420.0

var min_w := 400.0
var max_w := 920.0
var min_h := 210.0
var max_h := 450.0
var max_top_y := 175.0

var drag_mode := "" # "", "RIGHT", "BOTTOM", "TOP"
var last_drag_val := 0.0
var has_key := false

var status_label: Label
var helper_label: Label
var left_floor: StaticBody2D
var spike_bridge: StaticBody2D
var spike_col: CollisionShape2D
var right_wall_body: StaticBody2D
var bottom_lift_body: StaticBody2D
var bottom_lift_col: CollisionShape2D
var player: CharacterBody2D

var was_on_floor := false
var p_squash := Vector2(1.0, 1.0)
var walk_time := 0.0
var facing := 1.0
var shake_amt := 0.0
var dust_list: Array = []
var confetti_list: Array = []

var sfx_player: AudioStreamPlayer
var sfx_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	status_label = Label.new()
	status_label.position = Vector2(160, 32)
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", Color("#fff8e7"))
	add_child(status_label)

	helper_label = Label.new()
	helper_label.position = Vector2(160, 615)
	helper_label.add_theme_font_size_override("font_size", 16)
	helper_label.add_theme_color_override("font_color", Color("#b8b2a6"))
	add_child(helper_label)

	left_floor = _make_collider(Vector2(200, 24), Vector2(100, 12))
	add_child(left_floor)

	spike_bridge = StaticBody2D.new()
	spike_col = CollisionShape2D.new()
	var sb_r := RectangleShape2D.new()
	sb_r.size = Vector2(220, 24)
	spike_col.shape = sb_r
	spike_col.position = Vector2(110, 12)
	spike_bridge.add_child(spike_col)
	add_child(spike_bridge)

	right_wall_body = StaticBody2D.new()
	var rf_s := CollisionShape2D.new()
	var rf_r := RectangleShape2D.new()
	rf_r.size = Vector2(210, 24)
	rf_s.shape = rf_r
	rf_s.position = Vector2(-105, 12)
	right_wall_body.add_child(rf_s)

	var rw_s := CollisionShape2D.new()
	var rw_r := RectangleShape2D.new()
	rw_r.size = Vector2(20, 600)
	rw_s.shape = rw_r
	rw_s.position = Vector2(10, -150)
	right_wall_body.add_child(rw_s)
	add_child(right_wall_body)

	bottom_lift_body = StaticBody2D.new()
	bottom_lift_col = CollisionShape2D.new()
	var bl_r := RectangleShape2D.new()
	bl_r.size = Vector2(140, 20)
	bottom_lift_col.shape = bl_r
	bottom_lift_col.position = Vector2(70, -10)
	bottom_lift_body.add_child(bottom_lift_col)
	add_child(bottom_lift_body)

	player = CharacterBody2D.new()
	var p_s := CollisionShape2D.new()
	var p_r := RectangleShape2D.new()
	p_r.size = Vector2(26, 44)
	p_s.shape = p_r
	player.add_child(p_s)
	add_child(player)

	sfx_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.35
	sfx_player.stream = gen
	add_child(sfx_player)
	sfx_player.play()
	sfx_playback = sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback

	_enter_title()

func _make_collider(sz: Vector2, offset: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = sz
	cs.shape = rs
	cs.position = offset
	body.add_child(cs)
	return body

func _play_tone(freq_start: float, freq_end: float, duration: float, vol: float = 0.25) -> void:
	if sfx_playback == null:
		return
	var samples := int(22050.0 * duration)
	if sfx_playback.get_frames_available() < samples:
		return
	var phase := 0.0
	for i in range(samples):
		var t := float(i) / float(samples)
		var freq := lerpf(freq_start, freq_end, t)
		phase += freq / 22050.0
		var env := (1.0 - t) * vol
		var wave := sin(phase * TAU) * 0.7 + signf(sin(phase * TAU)) * 0.3
		sfx_playback.push_frame(Vector2(wave * env, wave * env))

func _spawn_dust(pos: Vector2, count: int) -> void:
	for i in range(count):
		dust_list.append({
			"pos": pos + Vector2(randf_range(-10, 10), 0),
			"vel": Vector2(randf_range(-45, 45), randf_range(-55, -15)),
			"life": 1.0
		})

func _spawn_confetti(pos: Vector2) -> void:
	var cols := [Color("#ff4757"), Color("#2ecc71"), Color("#f4c430"), Color("#1e90ff"), Color("#9b59b6")]
	for i in range(32):
		confetti_list.append({
			"pos": pos,
			"vel": Vector2(randf_range(-200, 200), randf_range(-280, -70)),
			"col": cols[i % cols.size()],
			"life": 1.2
		})

func _enter_title() -> void:
	state = "TITLE"
	panel_top_y = 0.0
	panel_w = 860.0
	panel_h = 420.0
	_sync_physics()

func _load_level(lvl: int) -> void:
	state = "PLAY"
	level = lvl
	panel_top_y = 0.0
	panel_w = 860.0
	panel_h = 420.0
	drag_mode = ""
	player.velocity = Vector2.ZERO
	player.global_position = panel_pos + Vector2(75, 255)

	has_key = not (level in [3, 5])
	bottom_lift_col.disabled = not (level in [2, 5])
	spike_col.disabled = (level != 4)

	_sync_physics()

func _sync_physics() -> void:
	left_floor.position = panel_pos + Vector2(0, 310)
	spike_bridge.position = panel_pos + Vector2(200, 310)
	bottom_lift_body.position = panel_pos + Vector2(220, panel_h)

	var right_y := 310.0
	if level in [2, 5]:
		right_y = 165.0
	elif level == 4:
		right_y = 274.0 # Sits right above the spikes!
	right_wall_body.position = panel_pos + Vector2(panel_w, right_y)

func _get_goal_pos() -> Vector2:
	return right_wall_body.position + Vector2(-65, -48)

func _get_key_pos() -> Vector2:
	var kx := 135.0 if level == 3 else 285.0
	return panel_pos + Vector2(kx, panel_top_y + 52.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state in ["TITLE", "WIN"] and event.keycode in [KEY_SPACE, KEY_ENTER]:
			total_grabs = 0
			run_time = 0.0
			_play_tone(330, 660, 0.15, 0.3)
			_load_level(1)
		elif state == "PLAY":
			if event.keycode == KEY_1: _load_level(1)
			elif event.keycode == KEY_2: _load_level(2)
			elif event.keycode == KEY_3: _load_level(3)
			elif event.keycode == KEY_4: _load_level(4)
			elif event.keycode == KEY_5: _load_level(5)

func _process(delta: float) -> void:
	var m := get_global_mouse_position()

	if state in ["TITLE", "WIN"]:
		var btn_rect := Rect2(panel_pos + Vector2(290, 275), Vector2(280, 64))
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and btn_rect.has_point(m):
			total_grabs = 0
			run_time = 0.0
			_play_tone(330, 660, 0.15, 0.3)
			_load_level(1)
	elif state == "PLAY":
		run_time += delta
		var mid_y := (panel_top_y + panel_h) * 0.5
		var hr_rect := Rect2(panel_pos + Vector2(panel_w - 18, mid_y - 48), Vector2(36, 96))
		var hb_rect := Rect2(panel_pos + Vector2(panel_w * 0.5 - 48, panel_h - 18), Vector2(96, 36))
		var ht_rect := Rect2(panel_pos + Vector2(panel_w * 0.35 - 48, panel_top_y - 18), Vector2(96, 36))

		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if drag_mode == "":
				if hr_rect.grow(15).has_point(m):
					drag_mode = "RIGHT"
					last_drag_val = panel_w
					total_grabs += 1
					_play_tone(320, 480, 0.05, 0.2)
				elif (level in [2, 5]) and hb_rect.grow(15).has_point(m):
					drag_mode = "BOTTOM"
					last_drag_val = panel_h
					total_grabs += 1
					_play_tone(320, 480, 0.05, 0.2)
				elif (level in [3, 5]) and ht_rect.grow(15).has_point(m):
					drag_mode = "TOP"
					last_drag_val = panel_top_y
					total_grabs += 1
					_play_tone(320, 480, 0.05, 0.2)

			if drag_mode == "RIGHT":
				var old_w := panel_w
				panel_w = clampf(m.x - panel_pos.x, min_w, max_w)
				if absf(panel_w - last_drag_val) > 18.0:
					last_drag_val = panel_w
					_play_tone(550, 420, 0.025, 0.14)
				if (panel_w == min_w or panel_w == max_w) and old_w != panel_w:
					shake_amt = 6.0
					_play_tone(140, 80, 0.09, 0.3)
				_sync_physics()
			elif drag_mode == "BOTTOM":
				var old_h := panel_h
				panel_h = clampf(m.y - panel_pos.y, min_h, max_h)
				if panel_h < old_h:
					player.global_position.y -= (old_h - panel_h)
				if absf(panel_h - last_drag_val) > 18.0:
					last_drag_val = panel_h
					_play_tone(600, 460, 0.025, 0.14)
				_sync_physics()
			elif drag_mode == "TOP":
				panel_top_y = clampf(m.y - panel_pos.y, 0.0, max_top_y)
				if absf(panel_top_y - last_drag_val) > 18.0:
					last_drag_val = panel_top_y
					_play_tone(480, 620, 0.025, 0.14)
				_sync_physics()
		else:
			drag_mode = ""

	p_squash = p_squash.lerp(Vector2(1.0, 1.0), delta * 12.0)
	shake_amt = move_toward(shake_amt, 0.0, delta * 28.0)

	for d in dust_list:
		d["pos"] += d["vel"] * delta
		d["life"] -= delta * 2.2
	dust_list = dust_list.filter(func(d): return d["life"] > 0.0)

	for c in confetti_list:
		c["vel"].y += 420.0 * delta
		c["pos"] += c["vel"] * delta
		c["life"] -= delta * 0.85
	confetti_list = confetti_list.filter(func(c): return c["life"] > 0.0)

	queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "PLAY":
		return

	var on_flr := player.is_on_floor()
	if on_flr and not was_on_floor:
		p_squash = Vector2(1.38, 0.65)
		_spawn_dust(player.global_position + Vector2(0, 22), 6)
		_play_tone(180, 110, 0.05, 0.18)
	was_on_floor = on_flr

	if not on_flr:
		player.velocity.y += 980.0 * delta

	if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)) and on_flr:
		player.velocity.y = -345.0
		p_squash = Vector2(0.68, 1.38)
		_spawn_dust(player.global_position + Vector2(0, 22), 5)
		_play_tone(260, 580, 0.11, 0.25)

	var dir := float(int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)))
	if dir != 0.0:
		facing = dir
		walk_time += delta * 14.0
	else:
		walk_time = 0.0

	player.velocity.x = dir * 235.0

	# Locked gate prevents walking
	var g_pos := _get_goal_pos()
	if not has_key and player.global_position.x > g_pos.x - 42.0 and absf(player.global_position.y - g_pos.y) < 60.0:
		player.global_position.x = g_pos.x - 42.0

	player.move_and_slide()

	# kalitni olish
	if not has_key and player.global_position.distance_to(_get_key_pos()) < 34.0:
		has_key = true
		shake_amt = 5.0
		_spawn_confetti(_get_key_pos())
		_play_tone(520, 980, 0.18, 0.3)

	# Check Red Ink Spikes in Level 4
	if level == 4:
		var spike_left := panel_pos.x + 210.0
		var spike_right := minf(panel_pos.x + 410.0, right_wall_body.position.x - 210.0)
		if spike_right > spike_left:
			var hazard_rect := Rect2(Vector2(spike_left, panel_pos.y + 288.0), Vector2(spike_right - spike_left, 26.0))
			if hazard_rect.has_point(player.global_position + Vector2(0, 18)):
				shake_amt = 8.0
				_play_tone(300, 90, 0.2, 0.3)
				_load_level(level)
				return

	if player.global_position.y > 720.0 or Input.is_key_pressed(KEY_R):
		_play_tone(400, 150, 0.18, 0.25)
		_load_level(level)
		return

	if has_key and Rect2(g_pos - Vector2(10, 10), Vector2(46, 62)).has_point(player.global_position):
		_spawn_confetti(g_pos + Vector2(14, 10))
		_play_tone(440, 880, 0.22, 0.3)
		if level < 5:
			_load_level(level + 1)
		else:
			state = "WIN"
			panel_top_y = 0.0
			panel_w = 860.0
			panel_h = 420.0

# ---  SKETCHBOOK RENDERER ---
func _sketch_line(rng: RandomNumberGenerator, a: Vector2, b: Vector2, col: Color, width: float) -> void:
	for pass_i in range(2):
		var j1 := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var j2 := Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
		var mid := (a + b) * 0.5 + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
		draw_line(a + j1, mid, col, width)
		draw_line(mid, b + j2, col, width)

func _sketch_box(rng: RandomNumberGenerator, r: Rect2, fill_col: Color, ink_col: Color) -> void:
	draw_rect(r, fill_col, true)
	var x := r.position.x + 6.0
	while x < r.end.x - 4.0:
		draw_line(Vector2(x, r.position.y + 3), Vector2(maxf(r.position.x + 3, x - 10), r.end.y - 3), Color(ink_col, 0.32), 1.5)
		x += 14.0
	var tl := r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br := r.end
	var bl := Vector2(r.position.x, r.end.y)
	_sketch_line(rng, tl, tr, ink_col, 3.0)
	_sketch_line(rng, tr, br, ink_col, 3.0)
	_sketch_line(rng, br, bl, ink_col, 3.0)
	_sketch_line(rng, bl, tl, ink_col, 3.0)

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 120)

	var cam_off := Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
	var p_tl := panel_pos + Vector2(0, panel_top_y) + cam_off
	var cur_h := panel_h - panel_top_y

	draw_rect(Rect2(0, 0, 2000, 1200), Color("#24201d"), true)
	draw_rect(Rect2(p_tl + Vector2(10, 12), Vector2(panel_w, cur_h)), Color(0, 0, 0, 0.38), true)
	draw_rect(Rect2(p_tl, Vector2(panel_w, cur_h)), PAPER_COLOR, true)

	# notebook lines & red margin
	var ly := p_tl.y + 32.0
	while ly < p_tl.y + cur_h - 10.0:
		draw_line(Vector2(p_tl.x + 8, ly), Vector2(p_tl.x + panel_w - 8, ly), Color("#a4c8e1", 0.45), 1.2)
		ly += 28.0
	draw_line(Vector2(p_tl.x + 54, p_tl.y + 6), Vector2(p_tl.x + 54, p_tl.y + cur_h - 6), Color("#e66767", 0.55), 1.8)

	var hy := p_tl.y + 26.0
	while hy < p_tl.y + cur_h - 18.0:
		draw_circle(Vector2(p_tl.x + 22, hy), 6.5, Color("#24201d"))
		hy += 42.0

	var font := ThemeDB.fallback_font

	if state == "TITLE":
		_draw_title_screen(rng, p_tl, font)
	elif state == "WIN":
		_draw_win_screen(rng, p_tl, font)
	else:
		_draw_gameplay(rng, p_tl, cur_h, cam_off, font)

	# Outer Comic Frame Border
	var tr := p_tl + Vector2(panel_w, 0)
	var br := p_tl + Vector2(panel_w, cur_h)
	var bl := p_tl + Vector2(0, cur_h)
	_sketch_line(rng, p_tl, tr, INK_COLOR, 5.0)
	_sketch_line(rng, tr, br, INK_COLOR, 5.0)
	_sketch_line(rng, br, bl, INK_COLOR, 5.0)
	_sketch_line(rng, bl, p_tl, INK_COLOR, 5.0)

	for d in dust_list:
		draw_circle(d["pos"] + cam_off, 5.0 * d["life"], Color(0.5, 0.48, 0.44, d["life"] * 0.6))
	for c in confetti_list:
		draw_rect(Rect2(c["pos"] + cam_off, Vector2(7, 7)), Color(c["col"], clampf(c["life"], 0.0, 1.0)), true)

func _draw_title_screen(rng: RandomNumberGenerator, p_tl: Vector2, font: Font) -> void:
	draw_string(font, p_tl + Vector2(210, 115), "FRAME-BREAKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, INK_COLOR)
	draw_string(font, p_tl + Vector2(360, 210), "Give It A TRY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e66767"))

	var btn := Rect2(p_tl + Vector2(290, 275), Vector2(280, 64))
	_sketch_box(rng, btn, Color("#f4c430"), INK_COLOR)
	draw_string(font, btn.position + Vector2(100, 40), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, INK_COLOR)

	# Mascot doodle on cover
	draw_set_transform(p_tl + Vector2(130, 300), 0.0, Vector2(2.0, 2.0))
	_draw_hero(rng, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
func _draw_win_screen(rng: RandomNumberGenerator, p_tl: Vector2, font: Font) -> void:
	draw_string(font, p_tl + Vector2(185, 115), "SKETCHBOOK COMPLETED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("#27ae60"))
	var time_str := "Clear Time: %.1f seconds   |   Frame Grabs: %d" % [run_time, total_grabs]
	draw_string(font, p_tl + Vector2(215, 175), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK_COLOR)

	var btn := Rect2(p_tl + Vector2(290, 275), Vector2(280, 64))
	_sketch_box(rng, btn, Color("#2ecc71"), INK_COLOR)
	draw_string(font, btn.position + Vector2(100, 40), "PLAY AGAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK_COLOR)
	_draw_hero(rng, p_tl + Vector2(130, 300))

func _draw_gameplay(rng: RandomNumberGenerator, p_tl: Vector2, cur_h: float, cam_off: Vector2, font: Font) -> void:
	# left floor
	_sketch_box(rng, Rect2(left_floor.position + cam_off, Vector2(200, 24)), Color("#dcd6c8"), INK_COLOR)

	# Level 4 Spike Bridge
	if level == 4:
		var sb_w := clampf(panel_w - 200.0, 0.0, 220.0)
		if sb_w > 10.0:
			_sketch_box(rng, Rect2(spike_bridge.position + cam_off, Vector2(sb_w, 24)), Color("#dcd6c8"), INK_COLOR)
			var sx := spike_bridge.position.x + 14.0
			var max_sx := minf(spike_bridge.position.x + sb_w - 10.0, right_wall_body.position.x - 210.0)
			while sx < max_sx:
				var sp_pts := PackedVector2Array([
					Vector2(sx, spike_bridge.position.y) + cam_off,
					Vector2(sx + 8, spike_bridge.position.y - 18) + cam_off,
					Vector2(sx + 16, spike_bridge.position.y) + cam_off
				])
				draw_colored_polygon(sp_pts, Color("#ff4757"))
				_sketch_line(rng, sp_pts[0], sp_pts[1], INK_COLOR, 2.2)
				_sketch_line(rng, sp_pts[1], sp_pts[2], INK_COLOR, 2.2)
				sx += 20.0

	# pastki elevator
	if level in [2, 5]:
		_sketch_box(rng, Rect2(bottom_lift_body.position + Vector2(0, -20) + cam_off, Vector2(140, 20)), Color("#c8d6e5"), INK_COLOR)

	# right ledge
	_sketch_box(rng, Rect2(right_wall_body.position + Vector2(-210, 0) + cam_off, Vector2(210, 24)), Color("#dcd6c8"), INK_COLOR)

	# kalit (Levels 3 & 5)
	if not has_key:
		var kp := _get_key_pos() + cam_off
		_sketch_line(rng, Vector2(kp.x, p_tl.y), kp + Vector2(0, -10), INK_COLOR, 2.2)
		draw_circle(kp, 11.0, Color("#f4c430"))
		draw_arc(kp, 11.0, 0, TAU, 18, INK_COLOR, 2.8)
		_sketch_line(rng, kp + Vector2(0, 11), kp + Vector2(0, 26), INK_COLOR, 3.2)
		_sketch_line(rng, kp + Vector2(0, 22), kp + Vector2(8, 22), INK_COLOR, 3.0)

	# bayroq va gate
	var gp := _get_goal_pos() + cam_off
	_sketch_line(rng, gp + Vector2(6, 48), gp + Vector2(6, 0), INK_COLOR, 3.5)
	var wave := sin(Time.get_ticks_msec() * 0.008) * 5.0
	var flag_pts := PackedVector2Array([gp + Vector2(6, 2), gp + Vector2(36, 11 + wave), gp + Vector2(6, 22)])
	draw_colored_polygon(flag_pts, Color("#2ecc71"))
	_sketch_line(rng, flag_pts[0], flag_pts[1], INK_COLOR, 2.5)
	_sketch_line(rng, flag_pts[1], flag_pts[2], INK_COLOR, 2.5)

	if not has_key:
		var gate_r := Rect2(gp + Vector2(-34, -12), Vector2(22, 60))
		_sketch_box(rng, gate_r, Color("#9b59b6"), INK_COLOR)
		draw_string(font, gate_r.position + Vector2(4, 36), "🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# tablarni tortish
	var hr := Rect2(p_tl + Vector2(panel_w - 16, cur_h * 0.5 - 45), Vector2(32, 90))
	_sketch_box(rng, hr, Color("#ff5252"), INK_COLOR)
	_sketch_line(rng, hr.position + Vector2(20, 32), hr.position + Vector2(10, 45), Color.WHITE, 2.5)
	_sketch_line(rng, hr.position + Vector2(10, 45), hr.position + Vector2(20, 58), Color.WHITE, 2.5)

	if level in [2, 5]:
		var hb := Rect2(p_tl + Vector2(panel_w * 0.5 - 45, cur_h - 16), Vector2(90, 32))
		_sketch_box(rng, hb, Color("#ffa502"), INK_COLOR)
		_sketch_line(rng, hb.position + Vector2(32, 20), hb.position + Vector2(45, 10), Color.WHITE, 2.5)
		_sketch_line(rng, hb.position + Vector2(45, 10), hb.position + Vector2(58, 20), Color.WHITE, 2.5)

	if level in [3, 5]:
		var ht := Rect2(p_tl + Vector2(panel_w * 0.35 - 45, -16), Vector2(90, 32))
		_sketch_box(rng, ht, Color("#9b59b6"), INK_COLOR)
		_sketch_line(rng, ht.position + Vector2(32, 10), ht.position + Vector2(45, 22), Color.WHITE, 2.5)
		_sketch_line(rng, ht.position + Vector2(45, 22), ht.position + Vector2(58, 10), Color.WHITE, 2.5)

	_draw_hero(rng, player.global_position + cam_off)
	_draw_tutorial(rng, p_tl, cur_h, font)

func _draw_hero(rng: RandomNumberGenerator, pp: Vector2) -> void:
	var h_scale := p_squash.y
	var w_scale := p_squash.x
	var head_c := pp + Vector2(0, -14.0 * h_scale)
	var hip_c := pp + Vector2(0, 8.0 * h_scale)

	var swing := sin(walk_time) * 9.0 * w_scale
	_sketch_line(rng, hip_c, pp + Vector2(-5.0 * w_scale + swing, 22.0), INK_COLOR, 3.2)
	_sketch_line(rng, hip_c, pp + Vector2(5.0 * w_scale - swing, 22.0), INK_COLOR, 3.2)
	_sketch_line(rng, head_c + Vector2(0, 7), hip_c, INK_COLOR, 3.5)
	_sketch_line(rng, head_c + Vector2(0, 11), pp + Vector2(-11.0 * w_scale - swing * 0.5, 4.0), INK_COLOR, 2.8)
	_sketch_line(rng, head_c + Vector2(0, 11), pp + Vector2(11.0 * w_scale + swing * 0.5, 4.0), INK_COLOR, 2.8)

	draw_circle(head_c, 9.5 * w_scale, PAPER_COLOR)
	draw_arc(head_c, 9.5 * w_scale, 0, TAU, 20, INK_COLOR, 3.0)
	draw_circle(head_c + Vector2(facing * 3.5, -1.0), 1.8, INK_COLOR)

	var r := Rect2(head_c + Vector2(-10.0 * w_scale, -14.0), Vector2(20.0 * w_scale, 9.0))
	draw_rect(r, BEANIE_COLOR, true)
	draw_circle(head_c + Vector2(0, -16.0), 3.5, BEANIE_COLOR)
	_sketch_line(rng, r.position, Vector2(r.end.x, r.position.y), INK_COLOR, 2.2)
	_sketch_line(rng, Vector2(r.position.x, r.end.y), r.end, INK_COLOR, 2.2)

	var tail := Vector2(-facing * (12.0 + absf(player.velocity.x) * 0.03), 3.0 + sin(Time.get_ticks_msec() * 0.015) * 3.0)
	_sketch_line(rng, head_c + Vector2(-5, 7), head_c + Vector2(5, 7), SCARF_COLOR, 4.5)
	_sketch_line(rng, head_c + Vector2(-facing * 3.0, 7), head_c + Vector2(0, 7) + tail, SCARF_COLOR, 4.0)
func _draw_tutorial(rng: RandomNumberGenerator, p_tl: Vector2, cur_h: float, font: Font) -> void:
	# Sakrab turuvchi animatsiya (bouncing effect)
	var bounce := sin(Time.get_ticks_msec() * 0.008) * 8.0
	var hint_col := Color("#e74c3c")

	# LEVEL 1: harakatlanish va chap tab
	if level == 1:
		if player.global_position.x < panel_pos.x + 115.0:
			draw_string(font, player.global_position + Vector2(-48, -42 + bounce * 0.4), "A / D + SPACE", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#555049"))
		if panel_w > 760.0:
			var tip := p_tl + Vector2(panel_w - 175.0 + bounce, cur_h * 0.5 + 6.0)
			draw_string(font, tip, "DRAG LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, hint_col)
			_sketch_line(rng, tip + Vector2(105, -6), tip + Vector2(145, -6), hint_col, 3.0)
			_sketch_line(rng, tip + Vector2(120, -16), tip + Vector2(105, -6), hint_col, 3.0)
			_sketch_line(rng, tip + Vector2(120, 4), tip + Vector2(105, -6), hint_col, 3.0)

	# LEVEL 2: pastki tap
	elif level == 2 and panel_h > 370.0:
		var tip := p_tl + Vector2(panel_w * 0.5 - 52.0, cur_h - 48.0 + bounce)
		draw_string(font, tip, "DRAG UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#e67e22"))

	# LEVEL 3: Binafsha (tepa) tabni pastga tortish
	elif level == 3 and not has_key and panel_top_y < 40.0:
		var tip := p_tl + Vector2(panel_w * 0.35 - 65.0, 48.0 + bounce)
		draw_string(font, tip, "PULL DOWN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#8e44ad"))

	# LEVEL 4: Tikanlar
	elif level == 4 and panel_w > 640.0:
		var tip := p_tl + Vector2(220.0, 250.0 + bounce * 0.5)
		draw_string(font, tip, "COVER SPIKES!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, hint_col)
