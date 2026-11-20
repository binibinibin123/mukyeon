# Architecture

Mukyeon is two processes: a Godot game that draws the pond, and a tiny native helper that deals with Windows.

```
Mukyeon.exe (Godot)  <-- UDP 127.0.0.1:47631 ("1" covered / "0" visible) --  mukyeon_helper.exe
   draws the pond                                                              parents the window into the desktop
                                                                               layer, watches for full-screen apps,
                                                                               repaints the wallpaper on exit
```

## Frame

1. `_process` reads the global cursor with `DisplayServer.mouse_get_position()`. That works without the window
   having focus, which a wallpaper never has.
2. `fish_school.gd` steers the fish and rebuilds their strips.
3. `main.gd` queues up to 16 "stamps" (the cursor and a few fish tails) for the simulation shader.
4. The simulation viewports run one step each. Two 480×270 `SubViewport`s ping-pong: A reads B, B reads A, and
   neither is ever cleared (`CLEAR_MODE_NEVER`). The format is HDR (16-bit float) because water height and velocity go negative.
5. Draw order: paper with ink soaked in → fish → willow and lotus (multiplied onto the paper) → water pass.
6. The water pass reads the screen texture and offsets it by the gradient of the water height, so everything
   above it ripples. It also darkens and brightens by the slope, which is what makes the ripples readable.

## Simulation texture

| Channel | Meaning | Update |
| --- | --- | --- |
| R | ink | advected by a slow curl-noise field and by the water slope, blurred a little, decays slowly |
| G | water height | wave equation: `vel += laplacian * k`, damped, `height += vel` |
| B | water velocity | pushed by stamps (cursor and tails) |

At 480×270 the simulation is a quarter of the screen size in each direction and is sampled with bilinear filtering.
That is soft enough to read as water and costs almost nothing.

## Fish

Each carp is a painting stretched along a spine of 14 joints (`SEGS`), drawn as a triangle strip with
`RenderingServer.canvas_item_add_triangle_array`. Two tricks keep it looking painted:

- **Joint angle limit.** When a fish turns tighter than the strip is wide, the inside edge folds over itself and
  the painting crumples. Each joint may bend at most `MAX_BEND` radians relative to the one before it.
- **Vertex colour as parameters.** `fish.gdshader` reads ink strength from vertex alpha and softness (mip level)
  from vertex red. The soft shadow is the same strip, offset, drawn first with a high softness.

Steering is a sum of small vectors on top of the current heading: a slow wander, separation from the other fish
(sampled at the head, middle and tail of the neighbour), a push away from the screen edges, and the cursor.

### Following the cursor

Each fish has its own `bond` (how eager), `delay` (how long it takes to notice), `orbit` (preferred distance) and
`orbit_dir` (which way round it circles). While the cursor is on screen and has moved recently, a fish waits out
its delay, then ramps `interest` up to 1. It aims at a point on a ring around the cursor, slightly ahead of
itself along the circle, so it arcs in and then circles instead of stopping dead in front of the pointer.
Speed and turn rate rise with `interest`, so a fish that is far away swims fast, turns quickly, and slows to a
cruise once it reaches its ring.

A swipe faster than 3500 px/s startles any fish within 220 px: it flees for two to four seconds with `interest`
reset to 0, then drifts back. Thirty to ninety seconds without mouse movement and the fish lose interest one by one.

## Helper

The wallpaper trick: send message `0x052C` to `Progman`, which makes Explorer create a `WorkerW` window behind the icon
layer. `SetParent` the Godot window into it, and it draws behind the icons while they stay clickable.
Windows 11 24H2 changed the window layout, so there is a fallback that looks for the child under `Progman`.

Pausing: `SHQueryUserNotificationState` plus a check whether the foreground window covers the whole primary screen.
The helper only reports "covered" after two seconds in a row, so alt-tabbing or a brief full-screen flash does not
stop and restart rendering. Resuming is immediate. When covered, Godot sets `RenderingServer.render_loop_enabled = false`
and drops to 4 fps for the message loop.

The foreground check uses `GetAncestor(..., GA_ROOT)`; without it, the wallpaper's own window (now a child of the desktop
layer) counts as a full-screen app and the wallpaper pauses forever.

On exit the helper re-applies the current wallpaper path with flags `0`, which repaints the normal wallpaper
without writing anything to the user's settings.

## Demo video

`.github/workflows/demo.yml` renders `docs/demo.mp4` with Godot's Movie Maker under `xvfb` and a software OpenGL driver
at a fixed 60 fps, with `--demo` replacing the real cursor with a scripted path (see `_demo_cursor_at` in `main.gd`).
The random seed is fixed, so the video can be reproduced.
