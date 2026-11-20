# Contributing

Thanks for looking. Small, focused pull requests are easiest to review.

## Set up

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/) (standard build, not .NET).
2. Install a MinGW-w64 `g++` (for the helper), for example from [MSYS2](https://www.msys2.org/).
3. Build the helper:
   ```bash
   g++ -std=c++17 -O2 -municode -mwindows -static helper/helper.cpp -o helper/mukyeon_helper.exe -lws2_32 -lshell32 -luser32
   ```
4. Try it in a normal window first, so a mistake cannot hide your desktop:
   ```bash
   Godot_v4.7.2-stable_win64.exe --path . -- --windowed
   ```
   Drop `--windowed` to attach to the desktop like the real thing.

## Useful flags (after `--`)

| Flag | What it does |
| --- | --- |
| `--windowed` | Do not attach to the desktop and do not start the helper. |
| `--shot=PATH` | Save a screenshot after 900 frames with a simulated cursor, then quit. |
| `--demo` | Scripted cursor and fixed random seed. Used to record `docs/demo.mp4`. |

`godot.log` prints frame-time stats every 10 seconds. Please check that no frame is slower
than about 35 ms before and after a change that touches rendering or the fish.

## Guidelines

- Keep the look: paper, ink, a few strokes. No UI and no text on the pond.
- Keep it light. The target is a few percent of a mid-range GPU at 30 fps idle.
- Comments say why, not what.
- Art: new paintings go in `art/` with the prompt in `art/prompts/`, and are released as CC0.

## Reporting bugs

Use the bug template and include your Windows version, your GPU, and the last lines of `godot.log`
(`%APPDATA%\Godot\app_userdata\Mukyeon\logs\godot.log`).
