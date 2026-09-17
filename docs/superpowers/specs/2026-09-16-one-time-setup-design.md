# One-Time Simple Hyprland Setup Design

## Outcome

Provide one supported command for turning an up-to-date Arch Linux installation into a complete, minimal Hyprland desktop using this repository as the dotfile source. The command runs as the target desktop user, uses `sudo` only for system package and service changes, preserves existing user configuration, and can be rerun safely.

## Supported platform

- Arch Linux with `systemd` and `pacman`.
- Hyprland 0.55 or newer, using the current Lua configuration format.
- A regular user with `sudo` access.
- Intel, AMD, and NVIDIA systems share hardware-neutral defaults. NVIDIA-specific changes remain an explicit post-install customization.

## Package strategy

Use only packages from the official Arch repositories. The setup uses first-party Hyprland utilities where they replace the old AUR dependencies:

- `hyprlauncher` instead of Tofi for application launching.
- `hyprpaper` instead of swww for wallpaper management.
- `hyprshot` instead of Grimblast for screenshots.
- `hyprshutdown` instead of wlogout for graceful session exit.
- `hyprpolkitagent` instead of the KDE authentication agent.

The complete package set includes Hyprland, UWSM, XWayland, both required portal backends, PipeWire and WirePlumber, Qt Wayland support, the Hyprland utilities above, Waybar, Dunst, Kitty, Thunar, Firefox, clipboard and media tools, brightness control, one Nerd Font family, and lightweight appearance tools. SDDM is installed and enabled by default, with `--no-sddm` available for users who already have a session launcher.

## Dotfile deployment

The repository is the authoritative dotfile source. Installation preserves each application directory and links only the individual files managed by this project:

```text
~/.config/hypr/hyprland.lua    -> /absolute/repository/path/configs/hypr/hyprland.lua
~/.config/hypr/hypridle.conf   -> /absolute/repository/path/configs/hypr/hypridle.conf
~/.config/hypr/hyprlock.conf   -> /absolute/repository/path/configs/hypr/hyprlock.conf
~/.config/hypr/hyprpaper.conf  -> /absolute/repository/path/configs/hypr/hyprpaper.conf
~/.config/waybar/config.jsonc   -> /absolute/repository/path/configs/waybar/config.jsonc
~/.config/waybar/style.css      -> /absolute/repository/path/configs/waybar/style.css
~/.config/dunst/dunstrc         -> /absolute/repository/path/configs/dunst/dunstrc
~/.config/kitty/kitty.conf      -> /absolute/repository/path/configs/kitty/kitty.conf
~/.config/kitty/theme.conf      -> /absolute/repository/path/configs/kitty/theme.conf
~/.config/fuzzel/fuzzel.ini     -> /absolute/repository/path/configs/fuzzel/fuzzel.ini
~/.config/gtk-3.0/settings.ini  -> /absolute/repository/path/configs/gtk-3.0/settings.ini
~/.config/gtk-4.0/settings.ini  -> /absolute/repository/path/configs/gtk-4.0/settings.ini
```

This keeps changes visible in Git, allows the repository itself to live anywhere, and does not replace unrelated files in an application's configuration directory. Wallpaper and lock-screen assets are copied to `${XDG_DATA_HOME:-~/.local/share}/simple-hyprland`, which gives runtime tools a stable path without linking the full repository. File-level GTK settings select the bundled theme and icon set without taking ownership of either GTK configuration directory.

Before replacing any existing path, the installer moves it into a timestamped directory under `${XDG_STATE_HOME:-~/.local/state}/simple-hyprland/backups/`. Correct links are detected and left untouched. A rerun therefore performs no backup or replacement for already-correct configuration.

The bundled GTK and icon archives are extracted into user-owned XDG data directories rather than `/usr/share`, avoiding unnecessary root-owned theme files.

## Installer interface

The entry point is `./install.sh` from any repository location.

- Default: show one summary and confirmation, update/install packages, enable SDDM, deploy links and user themes, then print next steps.
- `--yes`: accept the single confirmation for unattended use.
- `--dry-run`: print all intended package, service, backup, theme, and link operations without changing state.
- `--dotfiles-only`: deploy links and themes without package or system service changes.
- `--no-sddm`: omit SDDM installation and enablement.
- `--help`: document the interface.

The installer uses strict Bash error handling, argument arrays rather than `eval`, a state-directory log owned by the user, and nonzero exit status on every failed required step. It rejects root execution because root cannot reliably identify or own the target user's files.

## Configuration behavior

`configs/hypr/hyprland.lua` is a current Hyprland Lua configuration preserving the repository's Catppuccin-inspired appearance and core bindings. It uses a hardware-neutral fallback monitor rule, contains no unconditional NVIDIA variables, launches only installed applications, and uses UWSM-compatible application commands. User-specific monitor and device changes can be kept in an optional untracked `~/.config/hypr/local.lua` file loaded by the main configuration when present.

The setup starts Waybar, Dunst, hyprpaper, hypridle, hyprpolkitagent, hyprlauncher, and clipboard watchers with the session. Locking, idle handling, screenshots, graceful exit, media keys, brightness keys, application launching, and clipboard selection all have installed command providers.

## Failure handling and recovery

- Package or service failures stop the setup immediately and preserve the command's exit status.
- Configuration replacement occurs only after its backup succeeds.
- The completion message is printed only after every selected phase succeeds.
- The reported backup path provides direct manual recovery.
- `--dry-run` provides a reviewable preview before any system changes.

## Verification

An integration-style shell test runs the dotfile installer against an isolated temporary home. It verifies backup creation, correct symlink targets, unchanged-link idempotence, dry-run non-mutation, and rejection of invalid options. Static checks cover Bash syntax, Lua syntax, broken repository links, and forbidden legacy hazards such as `eval`, hardcoded `/home`, root-only execution, or an NVIDIA environment block in the default config.
