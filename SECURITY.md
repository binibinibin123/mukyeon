# Security

Mukyeon is a local desktop program. It opens no network ports to the outside: the Godot
process and the helper talk over UDP on `127.0.0.1:47631` only, and the program reads no
files outside its own folder except the current wallpaper path, which it re-applies on exit
to repaint the normal wallpaper.

If you find a security problem, please report it privately through
[GitHub security advisories](https://github.com/binibinibin123/mukyeon/security/advisories/new)
instead of a public issue.
