extends Node2D
## Carp as bendable ink strips. Every fish keeps its own space, so they never pile up.

const SEGS := 14
const MIN_SPEED := 26.0
const MAX_SPEED := 74.0
const CHASE_SPEED := 240.0 # px/s when swimming after the cursor
const MAX_TURN := 1.0 # rad/s
const MAX_BEND := 0.2 # rad per spine joint; keeps the wide strip from folding
const EDGE := 230.0

class Fish:
	var pos: Vector2
	var heading: float
	var speed: float
	var cruise: float
	var length: float
	var strength: float # paler fish read as deeper
	var phase: float
	var wander: float
	var bond: float # how eagerly it follows the cursor
	var orbit: float # distance it likes to keep from the cursor
	var orbit_dir: float # which way round the cursor it circles
	var interest := 0.0 # 0 = ignores the cursor, 1 = fully following
	var wait := 0.0 # time spent wanting the cursor, for the reaction delay
	var delay: float # how long it takes this fish to notice
	var shy := 0.0 # seconds left after being startled
	var tex: Texture2D
	var half_width: float
	var spine := PackedVector2Array()

var fish: Array[Fish] = []
var idle := 0.0 # seconds since the cursor last moved
var area := Vector2(1920, 1080)
var indices := PackedInt32Array()
var uvs := PackedVector2Array()

func setup(textures: Array[Texture2D], size: Vector2) -> void:
	area = size
	for i in SEGS - 1:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	for i in SEGS:
		var u := 1.0 - float(i) / (SEGS - 1) # head is at the right of the painting
		uvs.append(Vector2(u, 0.0))
		uvs.append(Vector2(u, 1.0))
	var lengths := [330.0, 300.0, 270.0, 250.0, 235.0, 220.0, 200.0, 190.0, 170.0]
	for i in lengths.size():
		var f := Fish.new()
		f.tex = textures[i % textures.size()]
		f.length = lengths[i]
		var ratio := float(f.tex.get_height()) / f.tex.get_width()
		f.half_width = f.length * ratio * 0.5
		f.pos = Vector2(randf_range(EDGE, area.x - EDGE), randf_range(EDGE, area.y - EDGE))
		f.heading = randf() * TAU
		f.cruise = randf_range(32.0, 54.0)
		f.speed = f.cruise
		f.strength = randf_range(0.62, 1.0)
		f.phase = randf() * TAU
		f.wander = randf() * 100.0
		f.bond = randf_range(0.6, 1.0)
		f.delay = randf_range(0.1, 1.4)
		f.orbit = randf_range(110.0, 300.0)
		f.orbit_dir = 1.0 if randf() < 0.5 else -1.0
		var back := Vector2.from_angle(f.heading)
		for s in SEGS:
			f.spine.append(f.pos - back * f.length * s / (SEGS - 1))
		fish.append(f)

func step(dt: float, cursor: Vector2, cursor_speed: float, cursor_on: bool) -> void:
	idle = 0.0 if cursor_speed > 12.0 else idle + dt
	for f in fish:
		var steer := Vector2.from_angle(f.heading)
		var target_speed := f.cruise

		f.wander += dt * 0.35
		steer = steer.rotated((sin(f.wander * 1.7) * 0.45 + sin(f.wander * 0.61) * 0.5) * (1.0 - 0.8 * f.interest))

		for o in fish:
			if o == f:
				continue
			var reach := (f.length + o.length) * 0.5
			for s in [0, SEGS / 2, SEGS - 1]:
				var away: Vector2 = f.pos - o.spine[s]
				var d := away.length()
				if d < reach and d > 0.01:
					var k := 1.0 - d / reach
					steer += away / d * k * k * 14.0

		var m := EDGE
		if f.pos.x < m: steer.x += (m - f.pos.x) / m * 3.0
		if f.pos.x > area.x - m: steer.x -= (f.pos.x - area.x + m) / m * 3.0
		if f.pos.y < m: steer.y += (m - f.pos.y) / m * 3.0
		if f.pos.y > area.y - m: steer.y -= (f.pos.y - area.y + m) / m * 3.0

		# Following the cursor: each fish notices it at its own pace, swims over, then
		# circles at its own distance. Long idle or a sudden swipe sends it back to wandering.
		f.shy = maxf(f.shy - dt, 0.0)
		var wants := cursor_on and f.shy <= 0.0 and idle < 30.0 + f.bond * 60.0
		f.wait = f.wait + dt if wants else 0.0
		var rate := 1.2 * f.bond if f.wait > f.delay else (0.0 if wants else 1.0)
		f.interest = move_toward(f.interest, 1.0 if wants else 0.0, dt * rate)
		if cursor_on:
			var to_cursor := cursor - f.pos
			var d := to_cursor.length()
			if cursor_speed > 3500.0 and d < 220.0 and d > 1.0:
				steer -= to_cursor / d * 6.0 # startled
				target_speed = CHASE_SPEED * 0.8
				f.shy = randf_range(2.0, 4.0)
				f.interest = 0.0
			elif f.interest > 0.0 and d > 1.0:
				# Aim at a point on a ring around the cursor, ahead of the fish along the circle.
				var around := (f.pos - cursor).normalized().rotated(f.orbit_dir * 0.8)
				var goal := (cursor + around * f.orbit).clamp(Vector2(EDGE * 0.6, EDGE * 0.6), area - Vector2(EDGE * 0.6, EDGE * 0.6))
				var to_goal := goal - f.pos
				var gd := to_goal.length()
				if gd > 1.0:
					var pull := clampf(gd / 220.0, 0.35, 1.6)
					steer += to_goal / gd * pull * 4.0 * f.interest * f.bond
					# Swim faster when far behind, ease off once on the ring.
					var hurry := clampf((d - f.orbit) / 350.0, 0.0, 1.0)
					target_speed = lerpf(f.cruise, CHASE_SPEED, hurry * f.interest)

		var want := steer.angle()
		var turn := lerpf(MAX_TURN, 2.4, f.interest) * dt
		f.heading += clampf(wrapf(want - f.heading, -PI, PI), -turn, turn)
		var top := lerpf(MAX_SPEED, CHASE_SPEED, maxf(f.interest, 0.0 if f.shy <= 0.0 else 1.0))
		f.speed = clampf(lerpf(f.speed, target_speed, dt * 2.0), MIN_SPEED, top)
		f.pos += Vector2.from_angle(f.heading) * f.speed * dt
		f.phase += dt * (1.3 + f.speed * 0.055)

		f.spine[0] = f.pos
		var seg := f.length / (SEGS - 1)
		var ahead := f.heading + PI
		for s in range(1, SEGS):
			var angle := (f.spine[s] - f.spine[s - 1]).angle()
			ahead += clampf(wrapf(angle - ahead, -PI, PI), -MAX_BEND, MAX_BEND)
			f.spine[s] = f.spine[s - 1] + Vector2.from_angle(ahead) * seg
	queue_redraw()

func _strip(f: Fish, offset: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(SEGS * 2)
	for s in SEGS:
		var a := f.spine[maxi(s - 1, 0)]
		var b := f.spine[mini(s + 1, SEGS - 1)]
		var normal := (a - b).normalized().orthogonal()
		var t := float(s) / (SEGS - 1)
		var c := f.spine[s] + normal * sin(f.phase - s * 0.72) * f.length * 0.055 * pow(t, 1.5) + offset
		pts[s * 2] = c - normal * f.half_width
		pts[s * 2 + 1] = c + normal * f.half_width
	return pts

func _emit(f: Fish, pts: PackedVector2Array, color: Color) -> void:
	var cols := PackedColorArray()
	cols.resize(pts.size())
	cols.fill(color)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, pts, cols, uvs,
		PackedInt32Array(), PackedFloat32Array(), f.tex.get_rid())

func _draw() -> void:
	for f in fish: # soft shadows first, so no shadow falls on a fish
		_emit(f, _strip(f, Vector2(14, 20) * f.strength), Color(0.62, 0, 0, 0.13))
	for f in fish:
		_emit(f, _strip(f, Vector2.ZERO), Color(0, 0, 0, f.strength))
