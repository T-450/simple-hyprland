#!/usr/bin/env bash

set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d)
trap 'rm -rf -- "$TEST_ROOT"' EXIT
REAL_TARGET_USER=$(/usr/bin/id -un "$EUID")

pass_count=0

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

pass() {
    pass_count=$((pass_count + 1))
    printf 'ok %d - %s\n' "$pass_count" "$1"
}

assert_file() {
    [[ -f "$1" ]] || fail "expected file: $1"
}

assert_directory() {
    [[ -d "$1" ]] || fail "expected directory: $1"
}

assert_link_to() {
    local link_path=$1
    local expected=$2

    [[ -L "$link_path" ]] || fail "expected symlink: $link_path"
    [[ $(readlink -f -- "$link_path") == $(readlink -f -- "$expected") ]] ||
        fail "$link_path does not resolve to $expected"
}

assert_absent() {
    [[ ! -e "$1" && ! -L "$1" ]] || fail "expected absent path: $1"
}

assert_git_config() {
    local file=$1
    local key=$2
    local expected=$3
    local actual

    actual=$(git config --file "$file" --get "$key") || fail "missing Git config key: $key"
    [[ $actual == "$expected" ]] || fail "Git config $key is '$actual', expected '$expected'"
}

assert_contains() {
    local file=$1
    local pattern=$2
    grep -Fq -- "$pattern" "$file" || fail "$file does not contain: $pattern"
}

assert_not_contains() {
    local file=$1
    local pattern=$2
    if grep -Fq -- "$pattern" "$file"; then
        fail "$file contains forbidden text: $pattern"
    fi
}

assert_count() {
    local file=$1
    local pattern=$2
    local expected=$3
    local actual

    actual=$(grep -Fc -- "$pattern" "$file" || true)
    [[ $actual -eq $expected ]] ||
        fail "$file contains '$pattern' $actual times, expected $expected"
}

assert_file "$REPO_DIR/configs/hypr/hyprland.lua"
assert_file "$REPO_DIR/configs/hypr/hyprpaper.conf"
assert_file "$REPO_DIR/configs/foot/foot.ini"
assert_file "$REPO_DIR/configs/zsh/zshrc"
assert_file "$REPO_DIR/configs/zsh/zprofile"
assert_file "$REPO_DIR/configs/zsh/ziggy.zsh-theme"
assert_file "$REPO_DIR/configs/git/config"
assert_file "$REPO_DIR/configs/fuzzel/fuzzel.ini"
assert_file "$REPO_DIR/configs/rofi/config.rasi"
assert_file "$REPO_DIR/configs/rofi/ziggy.rasi"
assert_file "$REPO_DIR/configs/gtk-3.0/settings.ini"
assert_file "$REPO_DIR/configs/gtk-4.0/settings.ini"
assert_file "$REPO_DIR/configs/gtk-3.0/gtk.css"
assert_file "$REPO_DIR/configs/gtk-4.0/gtk.css"
assert_file "$REPO_DIR/configs/qt6ct/colors/ziggy.conf"
assert_file "$REPO_DIR/configs/nvim/colors/ziggy.vim"
assert_file "$REPO_DIR/configs/nvim/lua/colors/ziggy.lua"
assert_file "$REPO_DIR/configs/nvim/plugin/simple-hyprland-ziggy.lua"
assert_file "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh"
assert_file "$REPO_DIR/configs/systemd/simple-hyprland-power-profile.service"
assert_file "$REPO_DIR/configs/udev/99-simple-hyprland-power-profile.rules"
assert_file "$REPO_DIR/configs/docker/hermes-agent.Dockerfile"
assert_file "$REPO_DIR/configs/systemd/docker.socket.d/simple-hyprland.conf"
assert_file "$REPO_DIR/scripts/hermes-docker"
bash -n "$REPO_DIR/scripts/hermes-docker" || fail 'Hermes Docker launcher has invalid syntax'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    'FROM docker/sandbox-templates:shell-0.5.0@sha256:16a88c7321c130de9aa8410ffd0865ea22dd051ebb7f58103fbf41ec50057476'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    '38547c22f4dd2224ba68a13bc3479309abb17e295b2a2ef79c2d1b8293bd822e'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    '9ecc9efaa151adc094989cb1004447aad1dc16dfd865fc37cb571a856f4c60a8'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    'test "$(git -C /home/agent/hermes-agent rev-parse HEAD)" = "345cd2b057a452236de401d3534b8502a7465e8d"'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    '/usr/local/bin/uv /home/agent/.hermes/bin/uv'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage repository'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage venv'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    'UV_PROJECT_ENVIRONMENT=/home/agent/hermes-agent/venv'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'sync --extra all --locked'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--no-install-project --no-build'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    'rm -f /etc/sudoers.d/agent'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    '/usr/bin/gpasswd --delete agent sudo'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
    '/usr/bin/gpasswd --delete agent docker'
assert_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'RUN --network=none'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'ARG HERMES_'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'ARG CODEX_'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'apt-get'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage python-deps'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage node-deps'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage setup'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage gateway'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '--stage desktop'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'npm install'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'npm audit fix'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" 'HERMES_REF=main'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '| bash'
assert_not_contains "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" '# syntax=docker/dockerfile:1'
assert_contains "$REPO_DIR/configs/systemd/docker.socket.d/simple-hyprland.conf" 'SocketUser=root'
assert_contains "$REPO_DIR/configs/systemd/docker.socket.d/simple-hyprland.conf" 'SocketGroup=root'
assert_contains "$REPO_DIR/configs/systemd/docker.socket.d/simple-hyprland.conf" 'SocketMode=0600'
assert_contains "$REPO_DIR/scripts/lib/install.sh" '[[ -x /usr/bin/sudo ]]'
assert_contains "$REPO_DIR/scripts/lib/install.sh" \
    'run /usr/bin/sudo -- /usr/bin/pacman -Syu --needed --noconfirm'
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" 'run sudo '
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" 'command -v sudo'
luac -p "$REPO_DIR/configs/hypr/hyprland.lua" || fail 'Hyprland Lua configuration has invalid syntax'
if ! HYPRLAND_VERIFY_OUTPUT=$(XDG_CONFIG_HOME="$TEST_ROOT/config-check" \
    Hyprland --verify-config --config "$REPO_DIR/configs/hypr/hyprland.lua" 2>&1); then
    printf '%s\n' "$HYPRLAND_VERIFY_OUTPUT" >&2
    fail 'Hyprland verifier exited unsuccessfully'
fi
[[ $HYPRLAND_VERIFY_OUTPUT == *'config ok'* ]] || {
    printf '%s\n' "$HYPRLAND_VERIFY_OUTPUT" >&2
    fail 'Hyprland rejected its Lua configuration'
}
foot --check-config --config="$REPO_DIR/configs/foot/foot.ini" || fail 'Foot configuration is invalid'
zsh -n "$REPO_DIR/configs/zsh/ziggy.zsh-theme" || fail 'Ziggy Zsh theme has invalid syntax'
zsh -n "$REPO_DIR/configs/zsh/zshrc" || fail 'Managed Zsh configuration has invalid syntax'
assert_contains "$REPO_DIR/configs/zsh/zshrc" '_hermes_docker_exec()'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'hermes()'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'hproject()'
assert_contains "$REPO_DIR/configs/zsh/zshrc" "alias h='hermes'"
assert_contains "$REPO_DIR/configs/zsh/zshrc" "alias hchat='hermes chat'"
assert_contains "$REPO_DIR/configs/zsh/zshrc" "alias hsetup='hermes setup'"
assert_contains "$REPO_DIR/configs/zsh/zshrc" "alias hdoctor='hermes doctor'"
HERMES_HELPER_WORKSPACE="$TEST_ROOT/hermes helper workspace"
HERMES_HELPER_OUTPUT="$TEST_ROOT/hermes-helper-output"
mkdir -p "$HERMES_HELPER_WORKSPACE"
env \
    HERMES_HELPER_OUTPUT="$HERMES_HELPER_OUTPUT" \
    HERMES_HELPER_WORKSPACE="$HERMES_HELPER_WORKSPACE" \
    zsh -fc '
        source <(/usr/bin/sed -n "/^# Hermes Docker helpers - start$/,/^# Hermes Docker helpers - end$/p" "$1")
        _hermes_docker_exec() {
            print -r -- "$PWD"
            print -rl -- "$@"
        }
        original_directory=$PWD
        hproject "$HERMES_HELPER_WORKSPACE" chat "prompt with spaces" >"$HERMES_HELPER_OUTPUT"
        [[ $PWD == "$original_directory" ]]
    ' zsh "$REPO_DIR/configs/zsh/zshrc" || fail 'Hermes Zsh helpers failed'
mapfile -t HERMES_HELPER_LINES <"$HERMES_HELPER_OUTPUT"
[[ ${HERMES_HELPER_LINES[0]} == "$HERMES_HELPER_WORKSPACE" ]] ||
    fail 'hproject did not run from the requested project directory'
[[ ${HERMES_HELPER_LINES[1]} == chat && ${HERMES_HELPER_LINES[2]} == 'prompt with spaces' ]] ||
    fail 'Hermes Zsh helpers did not preserve arguments'
HYPRLOCK_PARSE_OUTPUT=$(WAYLAND_DISPLAY=simple-hyprland-config-check \
    hyprlock --config "$REPO_DIR/configs/hypr/hyprlock.conf" --no-fade-in 2>&1 || true)
[[ $HYPRLOCK_PARSE_OUTPUT != *'Config has errors'* ]] || fail 'Hyprlock configuration is invalid'
DUNST_PARSE_OUTPUT=$(WAYLAND_DISPLAY=simple-hyprland-config-check \
    timeout 1 dunst -config "$REPO_DIR/configs/dunst/dunstrc" 2>&1 || true)
[[ $DUNST_PARSE_OUTPUT != *'Using legacy offset syntax'* ]] || fail 'Dunst uses legacy offset syntax'
[[ $DUNST_PARSE_OUTPUT != *"Setting notification_height in section global doesn't exist"* ]] ||
    fail 'Dunst configuration contains an unknown setting'
nvim --headless --clean --cmd "set runtimepath^=$REPO_DIR/configs/nvim" \
    '+colorscheme ziggy' '+lua assert(vim.g.colors_name == "ziggy")' +qa ||
    fail 'Ziggy Neovim theme cannot load'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprlauncher'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprshot'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprshot -m output -m active --clipboard-only'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprshot -m window -m active --clipboard-only'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprshutdown'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hyprpolkitagent.service'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'local terminal = "foot"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'local browser = "brave"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'local browser_fallback = "firefox"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'command -v '
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'QT_QPA_PLATFORMTHEME'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'rofi -show drun'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'gaps_in = 0'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'gaps_out = 0'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'border_size = 2'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'colors = { "rgb(6688ff)", "rgb(b1a0f8)", "rgb(21edba)" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'inactive_border = "rgb(353535)"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'rounding = 0'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'active_opacity = 1.0'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'inactive_opacity = 0.94'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hl.curve("snappy"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'leaf = "layers"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'leaf = "fade"'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'leaf = "workspaces"'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" '1.05'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ 0.1, 1.1 }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hl.dsp.window.swap({ direction = direction })'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ key = "H", direction = "left" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ key = "J", direction = "down" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ key = "K", direction = "up" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ key = "L", direction = "right" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" \
    'hl.bind("ALT + TAB", hl.dsp.window.cycle_next({ tiled = true }))'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'local resize_step = 40'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ bind = "CTRL + ALT + bracketleft", x = -resize_step, y = 0 }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ bind = "CTRL + ALT + bracketright", x = resize_step, y = 0 }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ bind = "CTRL + ALT + minus", x = 0, y = -resize_step }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ bind = "CTRL + ALT + plus", x = 0, y = resize_step }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" '{ repeating = true }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'local layouts = { "master", "dwindle", "scrolling", "monocle" }'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'workspace.tiled_layout'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'workspace.config_name'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'workspace.special'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'hl.workspace_rule'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'output = ""'
assert_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'mode = "preferred"'
assert_contains "$REPO_DIR/configs/hypr/hyprpaper.conf" 'source = $XDG_CONFIG_HOME/hypr/hyprpaper.d/simple-hyprland.conf'
assert_not_contains "$REPO_DIR/configs/hypr/hyprpaper.conf" 'splash ='
assert_contains "$REPO_DIR/configs/foot/foot.ini" 'background=222222'
assert_contains "$REPO_DIR/configs/foot/foot.ini" 'foreground=cccccc'
assert_contains "$REPO_DIR/configs/foot/foot.ini" 'font=SauceCodePro Nerd Font:size=10'
assert_contains "$REPO_DIR/configs/foot/foot.ini" 'pad=14x14'
assert_count "$REPO_DIR/configs/foot/foot.ini" '[cursor]' 1
assert_contains "$REPO_DIR/configs/foot/foot.ini" 'style=beam'
assert_contains "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh" 'profile=performance'
assert_contains "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh" 'profile=balanced'
assert_contains "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh" 'ActiveProfile s "$profile"'
assert_contains "$REPO_DIR/configs/systemd/simple-hyprland-power-profile.service" 'After=tuned-ppd.service'
assert_contains "$REPO_DIR/configs/udev/99-simple-hyprland-power-profile.rules" 'ENV{SYSTEMD_WANTS}+="simple-hyprland-power-profile.service"'
assert_contains "$REPO_DIR/configs/udev/99-simple-hyprland-power-profile.rules" 'ATTR{type}!="Battery"'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'ZSH_THEME="ziggy"'
assert_contains "$REPO_DIR/configs/zsh/ziggy.zsh-theme" '%B%F{blue}λ%f%b'
assert_contains "$REPO_DIR/configs/zsh/ziggy.zsh-theme" '%F{magenta}%~/%f'
assert_contains "$REPO_DIR/configs/zsh/ziggy.zsh-theme" '$(git_prompt_info)'
assert_contains "$REPO_DIR/configs/zsh/ziggy.zsh-theme" "ZSH_THEME_GIT_PROMPT_PREFIX='%F{cyan}'"
assert_contains "$REPO_DIR/configs/zsh/zprofile" 'uwsm check may-start'
assert_contains "$REPO_DIR/configs/zsh/zprofile" 'exec uwsm start hyprland-uwsm.desktop'
assert_contains "$REPO_DIR/configs/zsh/zprofile" '$(tty) == /dev/tty1'
assert_contains "$REPO_DIR/configs/zsh/zprofile" 'export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"'
assert_not_contains "$REPO_DIR/configs/zsh/zshrc" 'p10k'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'zsh-autosuggestions'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'zsh-syntax-highlighting'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'zsh-completions'
assert_contains "$REPO_DIR/configs/zsh/zshrc" 'zsh-history-substring-search'
assert_not_contains "$REPO_DIR/configs/zsh/zshrc" '/usr/share/fzf/key-bindings.zsh'
assert_not_contains "$REPO_DIR/configs/zsh/zshrc" '/usr/share/fzf/completion.zsh'
assert_contains "$REPO_DIR/configs/kitty/theme.conf" 'background              #222222'
assert_contains "$REPO_DIR/configs/fuzzel/fuzzel.ini" 'background=222222ff'
assert_contains "$REPO_DIR/configs/rofi/ziggy.rasi" '#6688ff'
assert_contains "$REPO_DIR/configs/waybar/style.css" '#222222'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" '"gtk-layer-shell": false'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" '"custom/arch"'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" '"format": ""'
assert_contains "$REPO_DIR/configs/waybar/style.css" '#custom-arch'
assert_contains "$REPO_DIR/configs/dunst/dunstrc" '#cccccc'
assert_contains "$REPO_DIR/configs/gtk-3.0/gtk.css" '#222222'
assert_contains "$REPO_DIR/configs/qt6ct/colors/ziggy.conf" '#ff222222'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" 'wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 2%+'
assert_contains "$REPO_DIR/configs/waybar/config.jsonc" 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-'
assert_not_contains "$REPO_DIR/configs/waybar/config.jsonc" 'pamixer'
assert_git_config "$REPO_DIR/configs/git/config" alias.co checkout
assert_git_config "$REPO_DIR/configs/git/config" alias.br branch
assert_git_config "$REPO_DIR/configs/git/config" alias.ci commit
assert_git_config "$REPO_DIR/configs/git/config" alias.st status
assert_git_config "$REPO_DIR/configs/git/config" init.defaultBranch master
assert_git_config "$REPO_DIR/configs/git/config" pull.rebase true
assert_git_config "$REPO_DIR/configs/git/config" push.autoSetupRemote true
assert_git_config "$REPO_DIR/configs/git/config" diff.algorithm histogram
assert_git_config "$REPO_DIR/configs/git/config" diff.colorMoved plain
assert_git_config "$REPO_DIR/configs/git/config" diff.mnemonicPrefix true
assert_git_config "$REPO_DIR/configs/git/config" commit.verbose true
assert_git_config "$REPO_DIR/configs/git/config" column.ui auto
assert_git_config "$REPO_DIR/configs/git/config" branch.sort -committerdate
assert_git_config "$REPO_DIR/configs/git/config" tag.sort -version:refname
assert_git_config "$REPO_DIR/configs/git/config" rerere.enabled true
assert_contains "$REPO_DIR/configs/hypr/hyprlock.conf" '$XDG_DATA_HOME/simple-hyprland/backgrounds/cat_leaves_blurred.png'
assert_contains "$REPO_DIR/configs/hypr/hyprlock.conf" '$XDG_DATA_HOME/simple-hyprland/backgrounds/cat_pacman.png'
assert_contains "$REPO_DIR/configs/zsh/zprofile" 'export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'LIBVA_DRIVER_NAME'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" 'GBM_BACKEND'
assert_not_contains "$REPO_DIR/configs/hypr/hyprland.lua" '__GLX_VENDOR_LIBRARY_NAME'
assert_not_contains "$REPO_DIR/configs/waybar/config.jsonc" '"device": "intel_backlight"'
pass 'current dotfiles are syntactically valid and hardware-neutral'

assert_file "$REPO_DIR/.gitignore"
assert_contains "$REPO_DIR/.gitignore" 'scripts/installer/*.log'
assert_contains "$REPO_DIR/.gitignore" '/yay/'
assert_contains "$REPO_DIR/README.md" './install.sh'
assert_not_contains "$REPO_DIR/README.md" 'sudo sh install.sh'
assert_contains "$REPO_DIR/scripts/installer/install.sh" 'exec'
assert_contains "$REPO_DIR/scripts/lib/install.sh" '    foot'
assert_contains "$REPO_DIR/scripts/lib/install.sh" '    rofi'
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" '    hyprlauncher'
assert_contains "$REPO_DIR/scripts/lib/install.sh" '    zsh'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'zsh-autosuggestions'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/foot/foot.ini'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/rofi/config.rasi'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/zsh/zshrc'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/zsh/ziggy.zsh-theme'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/git/config'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/nvim/colors/ziggy.vim'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/nvim/lua/colors/ziggy.lua'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configs/nvim/plugin/simple-hyprland-ziggy.lua'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configure_power_management'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'configure_command_not_found'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'systemctl enable --now pkgfile-update.timer'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'tuned-ppd'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'ohmyzsh/ohmyzsh.git'
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" 'romkatv/powerlevel10k.git'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'getty@tty1.service.d/simple-hyprland.conf'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'systemctl disable sddm.service'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'systemctl enable getty@tty1.service'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'if /usr/bin/pacman -Q sddm'
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" 'packages+=(sddm)'
assert_contains "$REPO_DIR/scripts/lib/install.sh" 'write_hyprpaper_source'
assert_not_contains "$REPO_DIR/scripts/lib/install.sh" 'kitty'
assert_contains "$REPO_DIR/README.md" 'not installed by the supported setup'

if grep -R -E -n --include='*.sh' 'eval|logname|/home/\$SUDO_USER|sudo sh install\.sh' \
    "$REPO_DIR/install.sh" "$REPO_DIR/scripts"; then
    fail 'installer surface contains a forbidden legacy hazard'
fi
pass 'documentation and installer surface use the supported safe entry point'

POWER_TEST_ROOT="$TEST_ROOT/power-supply"
POWER_TEST_BIN="$TEST_ROOT/power-busctl"
POWER_TEST_OUTPUT="$TEST_ROOT/power-profile"
mkdir -p "$POWER_TEST_ROOT/AC"
mkdir -p "$POWER_TEST_ROOT/BAT0"
printf 'Mains\n' >"$POWER_TEST_ROOT/AC/type"
printf 'Battery\n' >"$POWER_TEST_ROOT/BAT0/type"
cat >"$POWER_TEST_BIN" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$POWER_TEST_OUTPUT"
EOF
chmod +x "$POWER_TEST_BIN"

printf '0\n' >"$POWER_TEST_ROOT/AC/online"
POWER_SUPPLY_ROOT="$POWER_TEST_ROOT" POWER_PROFILE_BUSCTL="$POWER_TEST_BIN" \
    "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh"
assert_contains "$POWER_TEST_OUTPUT" 'ActiveProfile s balanced'

printf '1\n' >"$POWER_TEST_ROOT/AC/online"
POWER_SUPPLY_ROOT="$POWER_TEST_ROOT" POWER_PROFILE_BUSCTL="$POWER_TEST_BIN" \
    "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh"
assert_contains "$POWER_TEST_OUTPUT" 'ActiveProfile s performance'

rm -f -- "$POWER_TEST_ROOT/AC/type" "$POWER_TEST_ROOT/AC/online" "$POWER_TEST_ROOT/BAT0/type"
mkdir -p "$POWER_TEST_ROOT/HID-BATTERY"
printf 'Battery\n' >"$POWER_TEST_ROOT/HID-BATTERY/type"
printf 'Device\n' >"$POWER_TEST_ROOT/HID-BATTERY/scope"
POWER_SUPPLY_ROOT="$POWER_TEST_ROOT" POWER_PROFILE_BUSCTL="$POWER_TEST_BIN" \
    "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh"
assert_contains "$POWER_TEST_OUTPUT" 'ActiveProfile s performance'

mkdir -p "$POWER_TEST_ROOT/USB-C-DEVICE"
printf 'Battery\n' >"$POWER_TEST_ROOT/BAT0/type"
printf 'USB\n' >"$POWER_TEST_ROOT/USB-C-DEVICE/type"
printf 'Device\n' >"$POWER_TEST_ROOT/USB-C-DEVICE/scope"
printf '1\n' >"$POWER_TEST_ROOT/USB-C-DEVICE/online"
POWER_SUPPLY_ROOT="$POWER_TEST_ROOT" POWER_PROFILE_BUSCTL="$POWER_TEST_BIN" \
    "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh"
assert_contains "$POWER_TEST_OUTPUT" 'ActiveProfile s balanced'
pass 'TuneD profile selection distinguishes system power from desktops and peripherals'

TEST_HOME="$TEST_ROOT/home"
TEST_CONFIG="$TEST_HOME/.config"
TEST_DATA="$TEST_HOME/.local/share"
TEST_STATE="$TEST_HOME/.local/state"
TEST_BIN="$TEST_ROOT/bin"
TEST_GIT_LOG="$TEST_ROOT/git.log"
mkdir -p "$TEST_CONFIG/hypr"
mkdir -p "$TEST_BIN"
printf 'old hyprland config\n' >"$TEST_CONFIG/hypr/hyprland.lua"
printf 'keep this file\n' >"$TEST_CONFIG/hypr/local.lua"
cat >"$TEST_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

printf '%q ' "$@" >>"${TEST_GIT_LOG:?}"
printf '\n' >>"$TEST_GIT_LOG"

if [[ $1 == clone ]]; then
    destination=${!#}
    mkdir -p -- "$destination/.git"
    exit 0
fi

if [[ $1 == init ]]; then
    destination=${!#}
    mkdir -p -- "$destination/.git"
    exit 0
fi

if [[ $1 != -C ]]; then
    exit 0
fi

destination=$2
operation=$3
shift 3

case "$operation" in
    init)
        mkdir -p -- "$destination/.git"
        ;;
    remote)
        if [[ ${1:-} == add && ${2:-} == origin ]]; then
            printf '%s\n' "$3" >"$destination/.git/origin"
        elif [[ ${1:-} == get-url && ${2:-} == origin ]]; then
            cat "$destination/.git/origin"
        fi
        ;;
    status)
        [[ ! -f "$destination/.git/dirty" ]] || printf ' M managed-file\n'
        ;;
    fetch)
        revision=${!#}
        printf '%s\n' "${TEST_GIT_FETCH_REVISION:-$revision}" >"$destination/.git/FETCH_HEAD"
        ;;
    checkout)
        revision=${!#}
        printf '%s\n' "$revision" >"$destination/.git/HEAD"
        ;;
    rev-parse)
        case "${1:-}" in
            FETCH_HEAD) cat "$destination/.git/FETCH_HEAD" ;;
            HEAD) cat "$destination/.git/HEAD" ;;
        esac
        ;;
esac
EOF
chmod +x "$TEST_BIN/git"

cat >"$TEST_BIN/id" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -un ]] || exit 1
printf 'path-spoofed-user\n'
EOF
chmod +x "$TEST_BIN/id"

cat >"$TEST_BIN/getent" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == passwd ]] || exit 1
printf '%s:x:1000:1000::/home/%s:/usr/bin/zsh\n' "$2" "$2"
EOF
chmod +x "$TEST_BIN/getent"

cat >"$TEST_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TEST_BIN/pacman"

cat >"$TEST_BIN/date" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
    +%Y%m%d-%H%M%S) printf '20260917-000000\n' ;;
    --iso-8601=seconds) printf '2026-09-17T00:00:00-03:00\n' ;;
    *) exec /usr/bin/date "$@" ;;
esac
EOF
chmod +x "$TEST_BIN/date"

env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null

assert_link_to "$TEST_CONFIG/hypr/hyprland.lua" "$REPO_DIR/configs/hypr/hyprland.lua"
assert_link_to "$TEST_CONFIG/hypr/hypridle.conf" "$REPO_DIR/configs/hypr/hypridle.conf"
assert_link_to "$TEST_CONFIG/hypr/hyprlock.conf" "$REPO_DIR/configs/hypr/hyprlock.conf"
assert_link_to "$TEST_CONFIG/hypr/hyprpaper.conf" "$REPO_DIR/configs/hypr/hyprpaper.conf"
assert_link_to "$TEST_CONFIG/waybar/config.jsonc" "$REPO_DIR/configs/waybar/config.jsonc"
assert_link_to "$TEST_CONFIG/waybar/style.css" "$REPO_DIR/configs/waybar/style.css"
assert_link_to "$TEST_CONFIG/dunst/dunstrc" "$REPO_DIR/configs/dunst/dunstrc"
assert_link_to "$TEST_CONFIG/foot/foot.ini" "$REPO_DIR/configs/foot/foot.ini"
assert_link_to "$TEST_HOME/.zshrc" "$REPO_DIR/configs/zsh/zshrc"
assert_link_to "$TEST_HOME/.zprofile" "$REPO_DIR/configs/zsh/zprofile"
assert_link_to "$TEST_HOME/.oh-my-zsh/custom/themes/ziggy.zsh-theme" \
    "$REPO_DIR/configs/zsh/ziggy.zsh-theme"
assert_link_to "$TEST_CONFIG/git/config" "$REPO_DIR/configs/git/config"
assert_absent "$TEST_HOME/.p10k.zsh"
assert_link_to "$TEST_CONFIG/fuzzel/fuzzel.ini" "$REPO_DIR/configs/fuzzel/fuzzel.ini"
assert_link_to "$TEST_CONFIG/rofi/config.rasi" "$REPO_DIR/configs/rofi/config.rasi"
assert_link_to "$TEST_CONFIG/rofi/ziggy.rasi" "$REPO_DIR/configs/rofi/ziggy.rasi"
assert_link_to "$TEST_CONFIG/gtk-3.0/settings.ini" "$REPO_DIR/configs/gtk-3.0/settings.ini"
assert_link_to "$TEST_CONFIG/gtk-4.0/settings.ini" "$REPO_DIR/configs/gtk-4.0/settings.ini"
assert_link_to "$TEST_CONFIG/gtk-3.0/gtk.css" "$REPO_DIR/configs/gtk-3.0/gtk.css"
assert_link_to "$TEST_CONFIG/gtk-4.0/gtk.css" "$REPO_DIR/configs/gtk-4.0/gtk.css"
assert_link_to "$TEST_CONFIG/qt6ct/colors/ziggy.conf" "$REPO_DIR/configs/qt6ct/colors/ziggy.conf"
assert_link_to "$TEST_CONFIG/nvim/colors/ziggy.vim" "$REPO_DIR/configs/nvim/colors/ziggy.vim"
assert_link_to "$TEST_CONFIG/nvim/lua/colors/ziggy.lua" "$REPO_DIR/configs/nvim/lua/colors/ziggy.lua"
assert_link_to "$TEST_CONFIG/nvim/plugin/simple-hyprland-ziggy.lua" "$REPO_DIR/configs/nvim/plugin/simple-hyprland-ziggy.lua"
assert_file "$TEST_CONFIG/hypr/hyprpaper.d/simple-hyprland.conf"
assert_contains "$TEST_CONFIG/hypr/hyprpaper.d/simple-hyprland.conf" "$TEST_DATA/simple-hyprland/backgrounds/dark-cat-rosewater.png"
assert_file "$TEST_CONFIG/qt6ct/qt6ct.conf"
assert_contains "$TEST_CONFIG/qt6ct/qt6ct.conf" "$TEST_CONFIG/qt6ct/colors/ziggy.conf"
assert_directory "$TEST_HOME/.oh-my-zsh/.git"
assert_directory "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/.git"
assert_directory "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/.git"
assert_directory "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-completions/.git"
assert_directory "$TEST_HOME/.oh-my-zsh/custom/plugins/zsh-history-substring-search/.git"
assert_contains "$TEST_GIT_LOG" '0ee67f042872d1dfab74270c31867771ca35aef4'
assert_not_contains "$TEST_GIT_LOG" 'd05a1b00f9a61f9578bf9dc19b8451942dde8734'
assert_contains "$TEST_GIT_LOG" '85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5'
assert_contains "$TEST_GIT_LOG" 'de02bb84ab0af51e328c6ae85ab5555397c31277'
assert_contains "$TEST_GIT_LOG" '14c8d2e0ffaee98f2df9850b19944f32546fdea5'
assert_contains "$TEST_GIT_LOG" '2fc57d63067c18b1100ecdbf684fa5baf49459d1'
assert_not_contains "$TEST_GIT_LOG" 'pull'
pass 'managed files link directly to the repository and shell dependencies are pinned'

ln -s -- "$REPO_DIR/configs/zsh/p10k.zsh" "$TEST_HOME/.p10k.zsh"
env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null
assert_absent "$TEST_HOME/.p10k.zsh"
assert_link_to "$TEST_HOME/.oh-my-zsh/custom/themes/ziggy.zsh-theme" \
    "$REPO_DIR/configs/zsh/ziggy.zsh-theme"

printf 'keep personal prompt config\n' >"$TEST_HOME/.p10k.zsh"
unlink -- "$TEST_HOME/.oh-my-zsh/custom/themes/ziggy.zsh-theme"
printf 'keep personal theme backup\n' >"$TEST_HOME/.oh-my-zsh/custom/themes/ziggy.zsh-theme"
env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null
assert_contains "$TEST_HOME/.p10k.zsh" 'keep personal prompt config'
assert_link_to "$TEST_HOME/.oh-my-zsh/custom/themes/ziggy.zsh-theme" \
    "$REPO_DIR/configs/zsh/ziggy.zsh-theme"
THEME_BACKUP=$(find "$TEST_STATE/simple-hyprland/backups" -type f \
    -path '*/.oh-my-zsh/custom/themes/ziggy.zsh-theme' -print -quit)
assert_file "$THEME_BACKUP"
assert_contains "$THEME_BACKUP" 'keep personal theme backup'
pass 'legacy prompt cleanup preserves personal files and backs up a conflicting theme'

printf 'https://example.invalid/hostile.git\n' >"$TEST_HOME/.oh-my-zsh/.git/origin"
if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null 2>&1; then
    fail 'installer accepted a shell dependency with an unexpected origin'
fi
printf 'https://github.com/ohmyzsh/ohmyzsh.git\n' >"$TEST_HOME/.oh-my-zsh/.git/origin"
touch "$TEST_HOME/.oh-my-zsh/.git/dirty"
if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null 2>&1; then
    fail 'installer overwrote local changes in a shell dependency checkout'
fi
rm -f -- "$TEST_HOME/.oh-my-zsh/.git/dirty"
pass 'shell dependency updates reject unexpected origins and local changes'

printf '%040d\n' 0 >"$TEST_HOME/.oh-my-zsh/.git/HEAD"
if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    TEST_GIT_FETCH_REVISION='1111111111111111111111111111111111111111' \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null 2>&1; then
    fail 'installer accepted fetched content that did not match the pinned revision'
fi
env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null
assert_contains "$TEST_HOME/.oh-my-zsh/.git/HEAD" '0ee67f042872d1dfab74270c31867771ca35aef4'
pass 'shell dependency verification rejects a mismatched fetch and repairs an outdated checkout'

assert_file "$TEST_CONFIG/hypr/local.lua"
[[ $(<"$TEST_CONFIG/hypr/local.lua") == 'keep this file' ]] ||
    fail 'unmanaged neighboring config was modified'
[[ ! -L "$TEST_CONFIG/hypr" ]] || fail 'application config directory was replaced by a symlink'
pass 'application directories and unmanaged files are preserved'

BACKUP_FILE=$(find "$TEST_STATE/simple-hyprland/backups" -type f -path '*/.config/hypr/hyprland.lua' -print -quit)
assert_file "$BACKUP_FILE"
[[ $(<"$BACKUP_FILE") == 'old hyprland config' ]] || fail 'backup content is incorrect'

unlink -- "$TEST_CONFIG/hypr/hyprland.lua"
printf 'second hyprland conflict\n' >"$TEST_CONFIG/hypr/hyprland.lua"
env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null
mapfile -t HYPR_BACKUPS < <(find "$TEST_STATE/simple-hyprland/backups" -type f \
    -path '*/.config/hypr/hyprland.lua' -print)
[[ ${#HYPR_BACKUPS[@]} -eq 2 ]] || fail 'same-second backups did not get unique directories'
grep -Flq -- 'old hyprland config' "${HYPR_BACKUPS[@]}" || fail 'first backup was overwritten'
grep -Flq -- 'second hyprland conflict' "${HYPR_BACKUPS[@]}" || fail 'second backup was not retained'
assert_link_to "$TEST_CONFIG/hypr/hyprland.lua" "$REPO_DIR/configs/hypr/hyprland.lua"
pass 'conflicting managed files receive collision-proof backups'

assert_file "$TEST_DATA/simple-hyprland/backgrounds/cat_leaves.png"
assert_file "$TEST_DATA/simple-hyprland/backgrounds/cat_leaves_blurred.png"
assert_file "$TEST_DATA/simple-hyprland/backgrounds/cat_pacman.png"
[[ ! -e "$TEST_DATA/simple-hyprland/wlogout" ]] || fail 'unused wlogout assets were deployed'
pass 'runtime assets are copied to the XDG data directory'

BACKUPS_BEFORE=$(find "$TEST_STATE/simple-hyprland/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
FETCHES_BEFORE=$(grep -c ' fetch ' "$TEST_GIT_LOG")
env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$TEST_HOME" \
    XDG_CONFIG_HOME="$TEST_CONFIG" \
    XDG_DATA_HOME="$TEST_DATA" \
    XDG_STATE_HOME="$TEST_STATE" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --yes >/dev/null
BACKUPS_AFTER=$(find "$TEST_STATE/simple-hyprland/backups" -mindepth 1 -maxdepth 1 -type d | wc -l)
FETCHES_AFTER=$(grep -c ' fetch ' "$TEST_GIT_LOG")
[[ "$BACKUPS_BEFORE" -eq "$BACKUPS_AFTER" ]] || fail 'idempotent rerun created another backup'
[[ "$FETCHES_BEFORE" -eq "$FETCHES_AFTER" ]] || fail 'pinned dependencies were fetched again unnecessarily'
pass 'rerunning with correct links and dependency pins is idempotent'

DRY_HOME="$TEST_ROOT/dry-home"
DRY_OUTPUT=$(env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$DRY_HOME" \
    XDG_CONFIG_HOME="$DRY_HOME/.config" \
    XDG_DATA_HOME="$DRY_HOME/.local/share" \
    XDG_STATE_HOME="$DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --dry-run --yes)
[[ ! -e "$DRY_HOME/.config/hypr/hyprland.lua" ]] || fail 'dry-run changed the filesystem'
[[ "$DRY_OUTPUT" == *'hyprland.lua'* ]] || fail 'dry-run did not describe managed files'
[[ "$DRY_OUTPUT" == *'ziggy.zsh-theme'* ]] || fail 'dry-run did not describe the managed Zsh theme'
[[ "$DRY_OUTPUT" == *'Dry run complete. No changes were made.'* ]] || fail 'dry-run completion message is misleading'
[[ "$DRY_OUTPUT" != *'setup complete'* ]] || fail 'dry-run claimed the setup was applied'
pass 'dry-run reports operations without changing state'

SYSTEM_DRY_HOME="$TEST_ROOT/system-dry-home"
DEFAULT_SYSTEM_OUTPUT=$(env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$SYSTEM_DRY_HOME" \
    USER='spoofed-user' \
    XDG_CONFIG_HOME="$SYSTEM_DRY_HOME/.config" \
    XDG_DATA_HOME="$SYSTEM_DRY_HOME/.local/share" \
    XDG_STATE_HOME="$SYSTEM_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dry-run --yes)
[[ "$DEFAULT_SYSTEM_OUTPUT" != *'install tty1 auto-login'* ]] ||
    fail 'default installation still enables tty1 auto-login'
[[ "$DEFAULT_SYSTEM_OUTPUT" == *'remove legacy tty1 auto-login'* ]] ||
    fail 'default installation does not remove a legacy auto-login drop-in'

AUTOLOGIN_SYSTEM_OUTPUT=$(env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$SYSTEM_DRY_HOME" \
    USER='spoofed-user' \
    XDG_CONFIG_HOME="$SYSTEM_DRY_HOME/.config" \
    XDG_DATA_HOME="$SYSTEM_DRY_HOME/.local/share" \
    XDG_STATE_HOME="$SYSTEM_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dry-run --yes --autologin)
[[ "$AUTOLOGIN_SYSTEM_OUTPUT" == *"install tty1 auto-login for $REAL_TARGET_USER"* ]] ||
    fail 'explicit auto-login does not use the system-derived account'
[[ "$AUTOLOGIN_SYSTEM_OUTPUT" != *'spoofed-user'* && "$AUTOLOGIN_SYSTEM_OUTPUT" != *'path-spoofed-user'* ]] ||
    fail 'explicit auto-login trusts mutable environment or PATH identity data'
pass 'tty1 auto-login is explicit and uses the invoking account identity'

TEST_SUDO_LOG="$TEST_ROOT/sudo.log"
TEST_GETTY_DROPIN="$TEST_ROOT/simple-hyprland-getty.conf"

env \
    PATH="$TEST_BIN:$PATH" \
    TEST_SUDO_LOG="$TEST_SUDO_LOG" \
    TEST_GETTY_DROPIN="$TEST_GETTY_DROPIN" \
    bash -c '
        REPO_DIR=$1
        source "$REPO_DIR/scripts/lib/install.sh"
        run() {
            printf "%q " "$@" >>"${TEST_SUDO_LOG:?}"
            printf "\n" >>"$TEST_SUDO_LOG"
            if [[ ${1:-} == /usr/bin/sudo && ${3:-} == /usr/bin/install ]]; then
                source_path=${@: -2:1}
                /usr/bin/cp -- "$source_path" "${TEST_GETTY_DROPIN:?}"
            fi
        }
        AUTOLOGIN=true
        TARGET_USER=$2
        configure_getty
    ' \
    bash "$REPO_DIR" "$REAL_TARGET_USER" >/dev/null
assert_contains "$TEST_GETTY_DROPIN" "ExecStart=-/usr/bin/agetty --autologin $REAL_TARGET_USER --noclear %I \$TERM"
assert_not_contains "$TEST_GETTY_DROPIN" 'path-spoofed-user'

: >"$TEST_SUDO_LOG"
env \
    PATH="$TEST_BIN:$PATH" \
    TEST_SUDO_LOG="$TEST_SUDO_LOG" \
    TEST_GETTY_DROPIN="$TEST_GETTY_DROPIN" \
    bash -c '
        REPO_DIR=$1
        source "$REPO_DIR/scripts/lib/install.sh"
        run() {
            printf "%q " "$@" >>"${TEST_SUDO_LOG:?}"
            printf "\n" >>"$TEST_SUDO_LOG"
        }
        AUTOLOGIN=false
        configure_getty
    ' \
    bash "$REPO_DIR" >/dev/null
assert_contains "$TEST_SUDO_LOG" \
    '/usr/bin/sudo -- /usr/bin/rm -f -- /etc/systemd/system/getty@tty1.service.d/simple-hyprland.conf'
pass 'getty configuration installs the reviewed account or removes the managed override'

if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$SYSTEM_DRY_HOME" \
    XDG_CONFIG_HOME="$SYSTEM_DRY_HOME/.config" \
    XDG_DATA_HOME="$SYSTEM_DRY_HOME/.local/share" \
    XDG_STATE_HOME="$SYSTEM_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --autologin --yes >/dev/null 2>&1; then
    fail 'installer silently accepted --autologin with --dotfiles-only'
fi
pass 'dotfiles-only mode rejects system login changes'

if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$SYSTEM_DRY_HOME" \
    XDG_CONFIG_HOME="$SYSTEM_DRY_HOME/.config" \
    XDG_DATA_HOME='relative/data' \
    XDG_STATE_HOME="$SYSTEM_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --dry-run --yes >/dev/null 2>&1; then
    fail 'installer accepted a relative XDG data directory'
fi
pass 'installer rejects relative XDG base directories before writing files'

DOCKER_DRY_HOME="$TEST_ROOT/docker-dry-home"
DOCKER_DRY_OUTPUT=$(env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$DOCKER_DRY_HOME" \
    XDG_CONFIG_HOME="$DOCKER_DRY_HOME/.config" \
    XDG_DATA_HOME="$DOCKER_DRY_HOME/.local/share" \
    XDG_STATE_HOME="$DOCKER_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --with-hermes-agent --dry-run --yes)
[[ ! -e "$DOCKER_DRY_HOME/.local/share/simple-hyprland/sources/hermes-agent-docker" ]] ||
    fail 'Hermes Docker dry-run changed the filesystem'
[[ $DOCKER_DRY_OUTPUT == *'docker docker-buildx'* ]] ||
    fail 'Hermes Docker setup did not request its official Arch packages'
[[ $DOCKER_DRY_OUTPUT == *'https://github.com/xmbshwll/hermes-agent-docker.git'* ]] ||
    fail 'Hermes Docker setup did not use the requested upstream repository'
[[ $DOCKER_DRY_OUTPUT == *'c4bcbe2eb1cc92f36f74714f342fc1a5da4c3d9d'* ]] ||
    fail 'Hermes Docker setup did not pin the reviewed upstream revision'
[[ $DOCKER_DRY_OUTPUT == *'systemctl enable --now docker.socket'* ]] ||
    fail 'Hermes Docker setup did not use socket activation'
[[ $DOCKER_DRY_OUTPUT == *'systemctl restart docker.socket'* ]] ||
    fail 'Hermes Docker setup did not apply the socket policy to an already active socket'
[[ $DOCKER_DRY_OUTPUT == *'/etc/systemd/system/docker.socket.d/simple-hyprland.conf'* ]] ||
    fail 'Hermes Docker setup did not install the root-only socket policy'
[[ $DOCKER_DRY_OUTPUT == *'/usr/bin/docker --host unix:///run/docker.sock build --pull'* ]] ||
    fail 'Hermes Docker setup did not build the pinned local image'
[[ $DOCKER_DRY_OUTPUT == *'build --pull --network host'* ]] ||
    fail 'Hermes Docker build did not reuse the host network for working DNS resolution'
[[ $DOCKER_DRY_OUTPUT == *'run --rm --pull=never --network none --entrypoint /bin/sh'* ]] ||
    fail 'Hermes Docker setup did not verify the hardened image offline'
[[ $DOCKER_DRY_OUTPUT == *'simple-hyprland/hermes-agent:v2026.9.14'* ]] ||
    fail 'Hermes Docker setup did not use the versioned local image tag'
[[ $DOCKER_DRY_OUTPUT == *'/usr/local/bin/hermes-docker'* ]] ||
    fail 'Hermes Docker setup did not install the root-owned launcher'
pass 'Hermes Docker setup is explicit, pinned, socket-activated, and dry-run safe'

if env \
    PATH="$TEST_BIN:$PATH" \
    HOME="$SYSTEM_DRY_HOME" \
    XDG_CONFIG_HOME="$SYSTEM_DRY_HOME/.config" \
    XDG_DATA_HOME="$SYSTEM_DRY_HOME/.local/share" \
    XDG_STATE_HOME="$SYSTEM_DRY_HOME/.local/state" \
    TEST_GIT_LOG="$TEST_GIT_LOG" \
    "$REPO_DIR/install.sh" --dotfiles-only --with-hermes-agent --yes >/dev/null 2>&1; then
    fail 'installer silently accepted --with-hermes-agent with --dotfiles-only'
fi
pass 'dotfiles-only mode rejects the system-level Hermes Docker setup'

HERMES_WORKSPACE="$TEST_ROOT/hermes workspace"
HERMES_DATA="$TEST_ROOT/hermes-data"
mkdir -p "$HERMES_WORKSPACE"

(
    cd "$HERMES_WORKSPACE"
    HOME="$TEST_ROOT/hermes-home"
    XDG_DATA_HOME="$HERMES_DATA"
    # shellcheck source=../scripts/hermes-docker
    source "$REPO_DIR/scripts/hermes-docker"
    prepare_runtime_paths
    build_docker_args 1234 5678 chat 'prompt with spaces'

    EXPECTED_HERMES_ARGS=(
        /usr/bin/sudo -- /usr/bin/docker --host unix:///run/docker.sock run
        --rm
        --init
        --pull=never
        --user=1234:5678
        --network=bridge
        --read-only
        '--tmpfs=/tmp:rw,nosuid,nodev,size=256m,mode=1777'
        '--tmpfs=/run:rw,nosuid,nodev,size=64m,mode=1777'
        '--tmpfs=/home/agent/.cache:rw,nosuid,nodev,size=512m,mode=0700,uid=1234,gid=5678'
        --security-opt=no-new-privileges:true
        --cap-drop=ALL
        --pids-limit=512
        --memory=4g
        --memory-swap=4g
        --cpus=2
        --ulimit=nofile=4096:4096
        --log-driver=none
        --env=HERMES_HOME=/home/agent/.hermes
        --env=PYTHONDONTWRITEBYTECODE=1
        --env=XDG_CACHE_HOME=/home/agent/.cache
        --mount "type=bind,src=$HERMES_WORKSPACE,dst=/home/agent/workspace,bind-recursive=disabled"
        --mount "type=bind,src=$HERMES_DATA/simple-hyprland/hermes,dst=/home/agent/.hermes,bind-recursive=disabled"
        --workdir=/home/agent/workspace
        simple-hyprland/hermes-agent:v2026.9.14
        hermes chat 'prompt with spaces'
    )
    [[ ${#docker_args[@]} -eq ${#EXPECTED_HERMES_ARGS[@]} ]] ||
        fail 'Hermes Docker launcher emitted an unexpected argument count'
    for index in "${!EXPECTED_HERMES_ARGS[@]}"; do
        [[ ${docker_args[$index]} == "${EXPECTED_HERMES_ARGS[$index]}" ]] ||
            fail "Hermes Docker launcher argument $index is '${docker_args[$index]}', expected '${EXPECTED_HERMES_ARGS[$index]}'"
    done
)
[[ $(stat -c '%a' "$HERMES_DATA/simple-hyprland/hermes") == 700 ]] ||
    fail 'Hermes state directory is not private'
pass 'Hermes Docker launcher applies the intended isolation and preserves arguments'

HERMES_COMMA_WORKSPACE="$TEST_ROOT/hermes,workspace"
mkdir -p "$HERMES_COMMA_WORKSPACE"
if (
    cd "$HERMES_COMMA_WORKSPACE"
    # shellcheck source=../scripts/hermes-docker
    source "$REPO_DIR/scripts/hermes-docker"
    validate_mount_source 'Workspace' "$HERMES_COMMA_WORKSPACE"
) >/dev/null 2>&1; then
    fail 'Hermes Docker launcher accepted an ambiguous comma in a mount source'
fi
pass 'Hermes Docker launcher rejects ambiguous bind-mount paths'

if "$REPO_DIR/install.sh" --definitely-invalid >/dev/null 2>&1; then
    fail 'unknown option was accepted'
fi
pass 'unknown options fail'

printf '1..%d\n' "$pass_count"
