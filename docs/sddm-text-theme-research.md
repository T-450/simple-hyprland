# Text-oriented SDDM theme research

Date: 2026-09-16

The active setup uses an authenticated getty instead of SDDM. That is the smallest text-only login path: `agetty` owns tty1 and the managed Zsh profile starts Hyprland with UWSM after login. Passwordless auto-login is an explicit installer option, not the default.

GitHub community projects closest to a terminal aesthetic:

- [GistOfSpirit/TerminalStyleLogin](https://github.com/GistOfSpirit/TerminalStyleLogin) is the closest terminal-style SDDM result.
- [numbpill3d/ascii-cybersigilist-sddm](https://github.com/numbpill3d/ascii-cybersigilist-sddm) is a small QML ASCII terminal aesthetic with animated text.
- [achrefbenmbarek1/terminal-inspired-sddm-theme](https://github.com/achrefbenmbarek1/terminal-inspired-sddm-theme) is an older, very small terminal-inspired QML theme.

These remain graphical QML themes, so none are as lightweight or genuinely text-only as getty. They are references only and are not installed by Simple Hyprland.
