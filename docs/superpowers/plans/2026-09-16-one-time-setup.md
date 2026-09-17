# One-Time Simple Hyprland Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one safe, idempotent Arch Linux setup command that installs a minimal current Hyprland desktop and symlinks this repository's individual dotfiles into the user's existing application configuration directories.

**Architecture:** A regular-user Bash entry point owns orchestration and sources a focused helper library for backup and link operations. Each managed config file links directly to its repository source while its parent application directory remains user-owned; current Lua-based Hyprland configuration and official Arch packages remove the old hardware assumptions and AUR bootstrap.

**Tech Stack:** Bash 5, pacman/systemd, Hyprland Lua configuration, standard POSIX userland tools.

**Spec:** `docs/superpowers/specs/2026-09-16-one-time-setup-design.md`

## Global Constraints

- Target Arch Linux with `systemd`, `pacman`, and Hyprland 0.55 or newer.
- Run the installer as a regular user and use `sudo` only for system changes.
- Use only official Arch repository packages.
- Preserve every existing configuration path before replacement.
- Keep correct links unchanged on rerun.
- Use hardware-neutral defaults and no unconditional NVIDIA configuration.
- Treat the repository as the live source for managed config files without linking the repository or whole application directories.

---

### Task 1: Installer contract and symlink deployment

**Files:**
- Create: `tests/install.sh`
- Create: `scripts/lib/install.sh`
- Create: `install.sh`

**Interfaces:**
- Consumes: repository `configs/` and `assets/` trees; `HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, and `XDG_DATA_HOME`.
- Produces: CLI options `--yes`, `--dry-run`, `--dotfiles-only`, `--no-sddm`, and `--help`; `backup_path`, `ensure_link`, `deploy_dotfiles`, `deploy_assets`, and `deploy_themes` Bash functions.

- [x] **Step 1: Write the failing integration test**

Create a dependency-free Bash test that runs `install.sh --dotfiles-only --yes` with temporary XDG directories, starts with an existing Hyprland config and unrelated neighbor file, and asserts that the old managed file is backed up, every managed config file links directly to the repository, the neighbor remains unchanged, assets are copied to XDG data, a second run creates no additional backup, dry-run creates no files, and an unknown option fails.

- [x] **Step 2: Run the test to verify it fails**

Run: `bash tests/install.sh`

Expected: FAIL because the root installer and helper library do not exist.

- [x] **Step 3: Implement safe link and backup helpers**

Implement strict Bash helpers using quoted arrays and paths. `ensure_link SOURCE DEST` must compare canonical link targets, lazily create one timestamped backup root, move a conflicting destination under its path relative to the configured home, and create the requested symlink only after backup succeeds.

- [x] **Step 4: Implement the installer orchestration**

Parse the documented flags, reject root and non-Arch execution, print one confirmation, install official packages with `sudo pacman -Syu --needed`, optionally enable SDDM, link only supported configuration files to their repository sources, copy runtime assets and extract themes under the user's XDG data directory, and print completion only after success.

- [x] **Step 5: Run the focused test**

Run: `bash tests/install.sh`

Expected: all installer behavior checks pass.

### Task 2: Current, hardware-neutral dotfiles

**Files:**
- Create: `configs/hypr/hyprland.lua`
- Create: `configs/hypr/hyprpaper.conf`
- Create: `configs/fuzzel/fuzzel.ini`
- Create: `configs/gtk-3.0/settings.ini`
- Create: `configs/gtk-4.0/settings.ini`
- Modify: `configs/hypr/hypridle.conf`
- Modify: `configs/hypr/hyprlock.conf`
- Modify: `configs/waybar/config.jsonc`
- Modify: `configs/dunst/dunstrc`

**Interfaces:**
- Consumes: commands installed by Task 1 and assets copied under `${XDG_DATA_HOME:-~/.local/share}/simple-hyprland`.
- Produces: Hyprland 0.55+ Lua configuration, hyprpaper configuration, and complete bindings backed by installed commands.

- [x] **Step 1: Add failing static assertions**

Extend `tests/install.sh` to require `configs/hypr/hyprland.lua`, parse it with `luac -p`, assert it contains the fallback monitor rule and first-party utility commands, and reject the legacy mirror rule, hardcoded NVIDIA environment, missing application commands, and Intel-only Waybar backlight device.

- [x] **Step 2: Run the test to verify the dotfile assertions fail**

Run: `bash tests/install.sh`

Expected: FAIL because the Lua and hyprpaper configurations do not exist and legacy assumptions remain.

- [x] **Step 3: Add the current Hyprland configuration**

Translate the useful Simple Hyprland behavior to the installed version's Lua API, preserve the appearance and core bindings, use `hyprlauncher`, `hyprpaper`, `hyprshot`, `hyprshutdown`, `hyprpolkitagent`, Firefox, Kitty, and Thunar, load an optional unmanaged `~/.config/hypr/local.lua`, and remove hardware-specific defaults.

- [x] **Step 4: Align companion configurations**

Add the wallpaper and clipboard-picker configs, correct idle timing comments, reference assets through the stable repository anchor, remove stale Dunst dependencies, and let Waybar discover the backlight device.

- [x] **Step 5: Run the focused test**

Run: `bash tests/install.sh`

Expected: all installer and dotfile checks pass.

### Task 3: Remove the misleading legacy path and document the supported setup

**Files:**
- Modify: `README.md`
- Create: `.gitignore`
- Modify: `scripts/installer/install.sh`
- Delete: `scripts/installer/helper.sh`
- Delete: `scripts/installer/prerequisites.sh`
- Delete: `scripts/installer/hypr.sh`
- Delete: `scripts/installer/utilities.sh`
- Delete: `scripts/installer/theming.sh`
- Delete: `scripts/installer/final.sh`

**Interfaces:**
- Consumes: root `install.sh` interface from Task 1.
- Produces: one canonical quick-start command and one compatibility forwarder for the historical installer path.

- [x] **Step 1: Add failing documentation and hazard checks**

Extend `tests/install.sh` to assert the README invokes `./install.sh`, the compatibility wrapper forwards to it without root requirements, generated logs and `yay/` are ignored, and no tracked installer contains `eval`, `logname`, `/home/$SUDO_USER`, or `sudo sh install.sh`.

- [x] **Step 2: Run the test to verify it fails**

Run: `bash tests/install.sh`

Expected: FAIL on the old README and legacy scripts.

- [x] **Step 3: Replace the legacy installer surface**

Keep `scripts/installer/install.sh` as a small `exec` wrapper to the root entry point, delete the unsafe stage scripts, and ignore generated installer logs and in-repository AUR build directories without deleting user-owned untracked artifacts.

- [x] **Step 4: Rewrite the quick-install documentation**

Document the supported platform, regular-user invocation, stable symlink layout, backup location, flags, official-package policy, UWSM session selection, local overrides, and recovery procedure.

- [x] **Step 5: Run the focused test**

Run: `bash tests/install.sh`

Expected: all checks pass.

### Task 4: Full verification and local deployment

**Files:**
- Verify all changed files.
- Deploy into the current user's home only after repository checks pass.

**Interfaces:**
- Consumes: completed installer and dotfiles.
- Produces: verified repository state and a working symlinked local configuration.

- [x] **Step 1: Run repository verification**

Run: `bash -n install.sh scripts/lib/install.sh scripts/installer/install.sh tests/install.sh && luac -p configs/hypr/hyprland.lua && bash tests/install.sh`

Expected: exit 0 with every test reported as passing.

- [x] **Step 2: Review the integrated diff**

Run: `git diff --check && git status --short && git diff --stat && git diff`

Expected: no whitespace errors, no generated files, no secrets, and only setup-related changes.

- [x] **Step 3: Preview the real installation**

Run: `./install.sh --dry-run --yes`

Expected: official package, optional SDDM, theme, backup, and symlink actions are printed with no state changes.

- [x] **Step 4: Apply the setup**

Run in a normal terminal: `./install.sh --yes`. In a noninteractive automation environment, install the identical declared package set and enable SDDM through its available privilege broker, then run `./install.sh --dotfiles-only --yes`.

Expected: packages and SDDM succeed, existing managed files are backed up, and every managed config file becomes a direct symlink to its repository source.

- [x] **Step 5: Verify installed state**

Run: `find ~/.config/{hypr,waybar,dunst,kitty,fuzzel} -maxdepth 1 -type l -exec readlink -f {} \;` and query required packages with `pacman -Q`.

Expected: every managed file link resolves inside this repository, application directories remain real directories, and every required package is installed.
