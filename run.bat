@echo off
rem Runs the project from source. Set GODOT to your Godot 4.7.2 executable if it is not on PATH.
if "%GODOT%"=="" set GODOT=godot
start "" "%GODOT%" --path "%~dp0."
