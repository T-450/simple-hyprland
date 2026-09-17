# Simple Hyprland

A small, current Hyprland desktop for Arch Linux, styled around the high-contrast Ziggy palette.

![Simple Hyprland desktop](assets/github_repo/images/final-setup-01.png)

## What the setup installs

- Hyprland managed through UWSM, with XWayland and desktop portals.
- Hyprpaper, Hyprlock, Hypridle, Hyprshot, Hyprpicker, Hyprshutdown, and Hyprpolkitagent.
- Waybar, Dunst, Foot, Rofi, Thunar, Firefox, Cliphist, Fuzzel, PipeWire, and media and brightness controls.
- TuneD power management: performance on AC power and balanced-battery tuning after unplugging.
- Zsh with a custom Lambda-style Ziggy prompt: a bold blue lambda, violet path, and cyan Git state. The configured plugins are Git, sudo, fzf, z, command-not-found, colored-man-pages, zsh-autosuggestions, zsh-completions, zsh-history-substring-search, and zsh-syntax-highlighting. The system pkgfile update timer keeps command-not-found suggestions usable.
- A coordinated Ziggy theme for Hyprland, Foot, Rofi, Fuzzel, Waybar, Dunst, Hyprlock, GTK, and Qt6 applications, using the `SauceCodePro Nerd Font` face in Foot.
- An authenticated tty1 login that starts the UWSM-managed Hyprland session without a graphical display manager. Passwordless auto-login is available only through an explicit installer option.

All host packages come from Arch's official repositories. The installer does not bootstrap an AUR helper or build packages inside this repository.

## One-time setup

Start from an up-to-date Arch Linux installation with a regular user that has `sudo` access:

```bash
git clone https://github.com/gaurav23b/simple-hyprland.git ~/simple-hyprland
cd ~/simple-hyprland
./install.sh
```

Run the command as your regular user. The script asks for confirmation once and invokes `sudo` for package installation, setting Zsh as the login shell, and configuring tty1 getty. It disables and removes SDDM.

After installation, restart the computer and log in on tty1. The managed login profile launches **Hyprland (uwsm-managed)** automatically. If this machine is physically secured and you intentionally want passwordless console access, run the installer with `--autologin`; a later run without that flag removes the managed auto-login override.

### Installer options

```text
--yes             Accept the setup confirmation.
--dry-run         Print intended operations without changing anything.
--dotfiles-only   Link configs and install user assets without system changes.
--autologin       Explicitly enable passwordless tty1 login for this user.
--with-hermes-agent
                  Install Docker and the pinned Hermes Agent container.
--help            Show command help.
```

Previewing the complete setup is safe:

```bash
./install.sh --dry-run
```

### Optional Hermes Agent container

Install Docker from Arch's official repositories and build the reviewed
[`xmbshwll/hermes-agent-docker`](https://github.com/xmbshwll/hermes-agent-docker)
image with:

```bash
./install.sh --with-hermes-agent
```

This option pins the Docker packaging repository, the x86-64 Docker base
image, the Hermes release commit, its installer checksum, and the upstream
entrypoint checksum. The build reuses the pinned base image's `uv`, installs
Hermes's locked Python dependency graph from prebuilt wheels without installing
the local project as a package, and executes the checked-in Hermes entrypoint
directly. It omits mutable APT, Node frontend, browser automation, computer-use
driver, and optional Codex installation steps. The build uses the host network
only while constructing the image so downloads use the host's working DNS;
container runtime networking remains the explicit bridge described below. The
resulting image provides the core Hermes CLI and bundled skills, while browser,
computer-use, Node UI, and FFmpeg-dependent features are intentionally
unavailable. It uses a root-only
`docker.socket` for on-demand daemon startup and deliberately does not add your
account to the `docker` group, because membership grants root-equivalent host
access. Socket activation delays startup but does not automatically stop
Docker after a container has used it. The root-owned
`/usr/local/bin/hermes-docker` launcher therefore invokes Docker through
`sudo` and invalidates cached sudo authentication before and after each run.

Run Hermes from the project directory it may read and modify:

```bash
cd ~/src/my-project
hermes-docker
```

The managed Zsh configuration adds these convenience commands after the next
shell reload:

| Command | Action |
| --- | --- |
| `hermes [arguments]` or `h [arguments]` | Run the hardened Docker launcher in the current project. |
| `hchat [arguments]` | Start `hermes chat`. |
| `hsetup` | Configure Hermes credentials and settings. |
| `hdoctor` | Run Hermes diagnostics. |
| `hproject DIRECTORY [arguments]` | Run Hermes from another project without changing the current shell directory. |

These helpers call the fixed root-owned `/usr/local/bin/hermes-docker`
launcher. They do not expose unrestricted Docker or sudo aliases.

The launcher bind-mounts only two host directories: the current directory at
`/home/agent/workspace` and the private persistent state directory at
`${XDG_DATA_HOME:-~/.local/share}/simple-hyprland/hermes`. It runs as your host
UID and GID with a read-only container root filesystem, bounded temporary
filesystems, no Linux capabilities, no privilege escalation, and finite
process, memory, CPU, and file-descriptor limits. It never mounts the Docker
socket and never pulls an unreviewed replacement image at runtime.

The explicit bridge network still permits outbound traffic and connections to
reachable host and LAN services. Hermes and any project tools it runs can read
the mounted Hermes state, including stored credentials, and can modify the
selected project directory. Only run it in a directory and network context
you are willing to expose to the agent.

## How dotfiles are linked

The installer keeps application directories as normal directories and symlinks only files managed by this repository. For example:

```text
~/.config/hypr/hyprland.lua  -> ~/simple-hyprland/configs/hypr/hyprland.lua
~/.config/waybar/config.jsonc -> ~/simple-hyprland/configs/waybar/config.jsonc
~/.config/foot/foot.ini       -> ~/simple-hyprland/configs/foot/foot.ini
~/.config/rofi/ziggy.rasi     -> ~/simple-hyprland/configs/rofi/ziggy.rasi
~/.config/git/config          -> ~/simple-hyprland/configs/git/config
~/.zshrc                      -> ~/simple-hyprland/configs/zsh/zshrc
~/.zprofile                   -> ~/simple-hyprland/configs/zsh/zprofile
~/.oh-my-zsh/custom/themes/ziggy.zsh-theme -> ~/simple-hyprland/configs/zsh/ziggy.zsh-theme
~/.config/nvim/colors/ziggy.vim -> ~/simple-hyprland/configs/nvim/colors/ziggy.vim
```

This leaves unrelated files such as `~/.config/hypr/local.lua` untouched. Editing a managed file through `~/.config` edits the tracked file in this repository.

Oh My Zsh and the four external plugins are pinned Git checkouts under `~/.oh-my-zsh`. Each installer run verifies the expected upstream and checks out the repository's reviewed commit without following a mutable branch. The Ziggy prompt is a managed repository symlink rather than a downloaded theme. To update a dependency, review a new upstream revision and change its checked-in SHA in `scripts/lib/install.sh`. Put personal shell additions in `~/.zshrc.local`, which the managed Zsh configuration loads last.

By default, the installer removes its legacy `/etc/systemd/system/getty@tty1.service.d/simple-hyprland.conf` override and uses an authenticated getty. With `--autologin`, it creates that override for the account reported by `id -un`. The managed `~/.zprofile` starts UWSM only from tty1, so ordinary Foot terminals and SSH shells remain regular Zsh sessions.

TuneD manages the CPU and platform power policy. The installer installs a udev rule and a boot service that select the `performance` profile while external system power is online or no system battery is present, and `balanced` when a battery-powered machine is unplugged; device-scoped peripheral batteries and USB supplies are ignored. TuneD's battery-aware mapping applies its `balanced-battery` profile in that state.

Before replacing a managed file, the installer moves it to:

```text
${XDG_STATE_HOME:-~/.local/state}/simple-hyprland/backups/<timestamp>/
```

Wallpapers are copied to `${XDG_DATA_HOME:-~/.local/share}/simple-hyprland`, and bundled themes are installed in the corresponding user data directories. No user config or theme is written as root.

## Local customization

Put machine-specific Hyprland configuration in:

```text
~/.config/hypr/local.lua
```

The tracked config loads this file when present. It is the right place for monitor layouts, keyboard variants, GPU-specific environment variables, and personal bindings. The default monitor rule works with an arbitrary display at its preferred mode and automatic scale.

NVIDIA users should follow the current [Hyprland NVIDIA guide](https://wiki.hypr.land/Nvidia/) and keep those settings in `local.lua`; they are intentionally absent from the portable defaults.

## Main key bindings

| Binding | Action |
| --- | --- |
| `Super + Return` | Open Foot |
| `Super + B` | Open Brave (when installed) |
| `Super + E` | Open Thunar |
| `Super + D` | Open Rofi's application launcher |
| `Super + Q` | Close the active window |
| `Super + Shift + F` | Toggle floating mode |
| `Super + H/J/K/L` | Focus left/down/up/right |
| `Super + Shift + H/J/K/L` | Swap the active window left/down/up/right |
| `Ctrl + Alt + [` / `]` | Shrink/grow the active window width by 40 px while held |
| `Ctrl + Alt + -` / `+` | Shrink/grow the active window height by 40 px while held |
| `Super + Tab` | Cycle master, dwindle, scrolling, and monocle layouts |
| `Alt + Tab` | Cycle to the next window |
| `Super + V` | Pick from clipboard history |
| `Super + P` | Pick a color and copy it |
| `Super + Ctrl + L` | Lock the session |
| `Super + Escape` | Exit gracefully with Hyprshutdown |
| `Print` | Capture the current output to the clipboard |
| `Super + Print` | Capture a window to the clipboard |
| `Super + Shift + Print` | Capture a selected region to the clipboard |
| `Super + 1…0` | Select workspace 1…10 |
| `Super + Shift + 1…0` | Move the active window to workspace 1…10 |

Media and brightness keys work through PipeWire, Playerctl, and Brightnessctl.

## Validation

Run the repository checks with:

```bash
bash tests/install.sh
```

The test uses an isolated temporary home and verifies config backups, direct file symlinks, preservation of unrelated files, copied assets, pinned shell dependencies, authenticated-login defaults, explicit auto-login, power-profile selection, Lua syntax, hardware-neutral defaults, idempotent reruns, and dry-run behavior.

The documents under [`docs/`](docs/) and their Kitty, Tofi, Wlogout, and Catppuccin assets are retained as legacy manual examples; they are not installed by the supported setup. The root installer and this README are the supported path for current Hyprland releases.
