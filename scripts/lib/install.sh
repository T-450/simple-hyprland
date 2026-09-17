#!/usr/bin/env bash

set -Eeuo pipefail

ASSUME_YES=false
DRY_RUN=false
DOTFILES_ONLY=false
AUTOLOGIN=false
WITH_HERMES_AGENT=false
BACKUP_ROOT=''
TARGET_USER=''

readonly CORE_PACKAGES=(
    hyprland
    uwsm
    xorg-xwayland
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    pipewire
    pipewire-pulse
    wireplumber
    qt5-wayland
    qt6-wayland
)

readonly DESKTOP_PACKAGES=(
    hypridle
    hyprlock
    hyprpaper
    hyprpicker
    hyprpolkitagent
    hyprshot
    hyprshutdown
    waybar
    dunst
    foot
    rofi
    thunar
    firefox
    cliphist
    fuzzel
    wl-clipboard
    brightnessctl
    playerctl
    ttf-jetbrains-mono-nerd
    ttf-sourcecodepro-nerd
    nwg-look
    qt6ct
    kvantum
    zsh
    git
    fzf
    pkgfile
    tuned
    tuned-ppd
)

readonly OH_MY_ZSH_REPOSITORY='https://github.com/ohmyzsh/ohmyzsh.git'
readonly OH_MY_ZSH_REVISION='0ee67f042872d1dfab74270c31867771ca35aef4'
readonly ZSH_PLUGIN_SOURCES=(
    'zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5'
    'zsh-completions|https://github.com/zsh-users/zsh-completions.git|de02bb84ab0af51e328c6ae85ab5555397c31277'
    'zsh-history-substring-search|https://github.com/zsh-users/zsh-history-substring-search.git|14c8d2e0ffaee98f2df9850b19944f32546fdea5'
    'zsh-syntax-highlighting|https://github.com/zsh-users/zsh-syntax-highlighting.git|2fc57d63067c18b1100ecdbf684fa5baf49459d1'
)
readonly DOCKER_PACKAGES=(
    docker
    docker-buildx
)
readonly HERMES_DOCKER_REPOSITORY='https://github.com/xmbshwll/hermes-agent-docker.git'
readonly HERMES_DOCKER_REVISION='c4bcbe2eb1cc92f36f74714f342fc1a5da4c3d9d'
readonly HERMES_DOCKER_IMAGE='simple-hyprland/hermes-agent:v2026.9.14'

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

Install a minimal Simple Hyprland desktop on Arch Linux and link the managed
configuration files from this repository into the current user's config tree.

Options:
  --yes             Accept the single setup confirmation.
  --dry-run         Print intended operations without changing state.
  --dotfiles-only   Skip package installation and system service changes.
  --autologin       Explicitly enable passwordless tty1 login for this user.
  --with-hermes-agent
                    Install Docker and the pinned Hermes Agent container.
  -h, --help        Show this help text.
EOF
}

info() {
    printf '[simple-hyprland] %s\n' "$*"
}

die() {
    printf '[simple-hyprland] ERROR: %s\n' "$*" >&2
    exit 1
}

quote_command() {
    printf '%q ' "$@"
    printf '\n'
}

run() {
    if [[ $DRY_RUN == true ]]; then
        printf '[dry-run] '
        quote_command "$@"
        return 0
    fi

    "$@"
}

parse_args() {
    while (($# > 0)); do
        case "$1" in
            --yes)
                ASSUME_YES=true
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --dotfiles-only)
                DOTFILES_ONLY=true
                ;;
            --autologin)
                AUTOLOGIN=true
                ;;
            --with-hermes-agent)
                WITH_HERMES_AGENT=true
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "Unknown option: $1"
                ;;
        esac
        shift
    done

    if [[ $DOTFILES_ONLY == true && $AUTOLOGIN == true ]]; then
        die '--autologin cannot be combined with --dotfiles-only.'
    fi
    if [[ $DOTFILES_ONLY == true && $WITH_HERMES_AGENT == true ]]; then
        die '--with-hermes-agent cannot be combined with --dotfiles-only.'
    fi
}

check_environment() {
    local target_uid xdg_variable xdg_value

    ((EUID != 0)) || die 'Run this installer as your regular desktop user, not as root.'

    [[ -x /usr/bin/id ]] || die '/usr/bin/id is required.'
    TARGET_USER=$(/usr/bin/id -un "$EUID") || die 'Cannot identify the current user.'
    [[ -n $TARGET_USER ]] || die 'Cannot identify the current user.'
    [[ $TARGET_USER =~ ^[[:alnum:]_.-]+$ && $TARGET_USER != -* ]] ||
        die 'The current account name contains unsupported characters.'
    target_uid=$(/usr/bin/id -u "$TARGET_USER") || die 'Cannot verify the current user.'
    [[ $target_uid == "$EUID" ]] || die 'The current account identity is inconsistent.'

    [[ -r /etc/os-release ]] || die 'Cannot identify the operating system.'
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ ${ID:-} == arch ]] || die 'This installer supports Arch Linux only.'

    [[ -n ${HOME:-} && $HOME == /* ]] || die 'HOME must be an absolute path.'
    for xdg_variable in XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME; do
        xdg_value=${!xdg_variable:-}
        [[ -z $xdg_value || $xdg_value == /* ]] ||
            die "$xdg_variable must be an absolute path."
    done
    command -v realpath >/dev/null || die 'realpath is required.'
    command -v tar >/dev/null || die 'tar is required.'
    command -v sha256sum >/dev/null || die 'sha256sum is required.'

    if [[ $DOTFILES_ONLY == false ]]; then
        [[ -x /usr/bin/getent ]] || die '/usr/bin/getent is required.'
        [[ -x /usr/bin/pacman ]] || die '/usr/bin/pacman is required.'
        [[ -x /usr/bin/sudo ]] || die '/usr/bin/sudo is required for package installation.'
        [[ -x /usr/bin/systemctl ]] || die '/usr/bin/systemctl is required.'
        [[ -x /usr/bin/install ]] || die '/usr/bin/install is required.'
        [[ -x /usr/bin/rm ]] || die '/usr/bin/rm is required.'
        [[ -x /usr/bin/udevadm ]] || die '/usr/bin/udevadm is required.'
        [[ -x /usr/bin/chsh ]] || die '/usr/bin/chsh is required.'
    fi
}

confirm_install() {
    [[ $ASSUME_YES == true ]] && return 0

    printf '\nThis will:\n'
    if [[ $DOTFILES_ONLY == false ]]; then
        printf '  - update Arch packages and install the Simple Hyprland package set\n'
        printf '  - replace SDDM with an authenticated tty1 login into Hyprland\n'
        if [[ $AUTOLOGIN == true ]]; then
            printf '  - enable passwordless tty1 auto-login for %s\n' "$TARGET_USER"
        fi
        if [[ $WITH_HERMES_AGENT == true ]]; then
            printf '  - install Docker with socket activation and build the pinned Hermes Agent image\n'
        fi
    fi
    printf '  - back up conflicting managed config files\n'
    printf '  - symlink individual managed config files to %s\n' "$REPO_DIR"
    printf '  - install Oh My Zsh with the custom Lambda-style Ziggy prompt\n'
    printf '  - install bundled assets and themes in your user data directory\n\n'

    read -r -p 'Continue? [y/N] ' reply
    [[ $reply == [Yy] || $reply == [Yy][Ee][Ss] ]] || die 'Setup cancelled.'
}

state_home() {
    printf '%s\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

config_home() {
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

data_home() {
    printf '%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

backup_relative_path() {
    local path=$1

    if [[ $path == "$HOME" ]]; then
        printf 'home\n'
    elif [[ $path == "$HOME/"* ]]; then
        printf '%s\n' "${path#"$HOME"/}"
    else
        printf 'external/%s\n' "${path#/}"
    fi
}

ensure_backup_root() {
    local backup_parent

    if [[ -n $BACKUP_ROOT ]]; then
        return 0
    fi

    backup_parent="$(state_home)/simple-hyprland/backups"
    if [[ $DRY_RUN == true ]]; then
        BACKUP_ROOT="$backup_parent/$(date +%Y%m%d-%H%M%S)-XXXXXX"
        info "Would create backup directory: $BACKUP_ROOT"
    else
        mkdir -p -- "$backup_parent"
        BACKUP_ROOT=$(mktemp -d -- "$backup_parent/$(date +%Y%m%d-%H%M%S)-XXXXXX") ||
            die 'Cannot create a unique backup directory.'
    fi
}

backup_path() {
    local path=$1
    local relative backup

    [[ -e $path || -L $path ]] || return 0
    ensure_backup_root
    relative=$(backup_relative_path "$path")
    backup="$BACKUP_ROOT/$relative"

    if [[ $DRY_RUN == true ]]; then
        info "Would back up: $path -> $backup"
        return 0
    fi

    mkdir -p -- "$(dirname "$backup")"
    mv -- "$path" "$backup"
    info "Backed up: $path -> $backup"
}

ensure_real_directory() {
    local directory=$1

    if [[ -L $directory ]]; then
        die "Parent config directory is a symlink: $directory. Replace it with a real directory before using file-level links."
    fi

    if [[ $DRY_RUN == true ]]; then
        [[ -d $directory ]] || info "Would create directory: $directory"
    else
        mkdir -p -- "$directory"
    fi
}

ensure_link() {
    local source=$1
    local destination=$2
    local source_real destination_real

    [[ -e $source ]] || die "Managed source does not exist: $source"
    source_real=$(realpath -- "$source")

    if [[ -L $destination ]]; then
        destination_real=$(readlink -f -- "$destination" 2>/dev/null || true)
        if [[ $destination_real == "$source_real" ]]; then
            info "Already linked: $destination"
            return 0
        fi
    fi

    ensure_real_directory "$(dirname "$destination")"
    backup_path "$destination"

    if [[ $DRY_RUN == true ]]; then
        info "Would link: $destination -> $source_real"
    else
        ln -s -- "$source_real" "$destination"
        info "Linked: $destination -> $source_real"
    fi
}

remove_managed_link() {
    local source=$1
    local destination=$2
    local current_target

    [[ -L $destination ]] || return 0
    current_target=$(readlink -- "$destination")
    [[ $current_target == "$source" ]] || return 0

    if [[ $DRY_RUN == true ]]; then
        info "Would remove obsolete managed link: $destination"
    else
        unlink -- "$destination"
        info "Removed obsolete managed link: $destination"
    fi
}

deploy_dotfiles() {
    local config_dir
    config_dir=$(config_home)

    ensure_link "$REPO_DIR/configs/hypr/hyprland.lua" "$config_dir/hypr/hyprland.lua"
    ensure_link "$REPO_DIR/configs/hypr/hypridle.conf" "$config_dir/hypr/hypridle.conf"
    ensure_link "$REPO_DIR/configs/hypr/hyprlock.conf" "$config_dir/hypr/hyprlock.conf"
    ensure_link "$REPO_DIR/configs/hypr/hyprpaper.conf" "$config_dir/hypr/hyprpaper.conf"
    ensure_link "$REPO_DIR/configs/waybar/config.jsonc" "$config_dir/waybar/config.jsonc"
    ensure_link "$REPO_DIR/configs/waybar/style.css" "$config_dir/waybar/style.css"
    ensure_link "$REPO_DIR/configs/dunst/dunstrc" "$config_dir/dunst/dunstrc"
    ensure_link "$REPO_DIR/configs/foot/foot.ini" "$config_dir/foot/foot.ini"
    ensure_link "$REPO_DIR/configs/fuzzel/fuzzel.ini" "$config_dir/fuzzel/fuzzel.ini"
    ensure_link "$REPO_DIR/configs/rofi/config.rasi" "$config_dir/rofi/config.rasi"
    ensure_link "$REPO_DIR/configs/rofi/ziggy.rasi" "$config_dir/rofi/ziggy.rasi"
    ensure_link "$REPO_DIR/configs/gtk-3.0/settings.ini" "$config_dir/gtk-3.0/settings.ini"
    ensure_link "$REPO_DIR/configs/gtk-4.0/settings.ini" "$config_dir/gtk-4.0/settings.ini"
    ensure_link "$REPO_DIR/configs/gtk-3.0/gtk.css" "$config_dir/gtk-3.0/gtk.css"
    ensure_link "$REPO_DIR/configs/gtk-4.0/gtk.css" "$config_dir/gtk-4.0/gtk.css"
    ensure_link "$REPO_DIR/configs/qt6ct/colors/ziggy.conf" "$config_dir/qt6ct/colors/ziggy.conf"
    ensure_link "$REPO_DIR/configs/git/config" "$config_dir/git/config"
    ensure_link "$REPO_DIR/configs/nvim/colors/ziggy.vim" "$config_dir/nvim/colors/ziggy.vim"
    ensure_link "$REPO_DIR/configs/nvim/lua/colors/ziggy.lua" "$config_dir/nvim/lua/colors/ziggy.lua"
    ensure_link "$REPO_DIR/configs/nvim/plugin/simple-hyprland-ziggy.lua" \
        "$config_dir/nvim/plugin/simple-hyprland-ziggy.lua"
}

ensure_git_checkout() {
    local repository=$1
    local revision=$2
    local destination=$3
    local current_origin current_revision fetched_revision status

    if [[ -d $destination/.git ]]; then
        current_origin=$(git -C "$destination" remote get-url origin 2>/dev/null || true)
        [[ $current_origin == "$repository" ]] ||
            die "Checkout has an unexpected origin: $destination"
        status=$(git -C "$destination" status --short --untracked-files=normal)
        [[ -z $status ]] || die "Checkout has local changes: $destination"
        current_revision=$(git -C "$destination" rev-parse HEAD 2>/dev/null || true)
        if [[ $current_revision == "$revision" ]]; then
            info "Pinned checkout is current: $destination"
            return 0
        fi
    else
        [[ ! -e $destination && ! -L $destination ]] ||
            die "Expected a Git checkout or an absent path: $destination"

        ensure_real_directory "$(dirname "$destination")"
        info "Creating pinned checkout: $repository"
        run mkdir -p -- "$destination"
        run git -C "$destination" init --quiet
        run git -C "$destination" remote add origin "$repository"
    fi

    info "Pinning checkout: $destination @ $revision"
    run git -C "$destination" fetch --depth 1 origin "$revision"
    if [[ $DRY_RUN == true ]]; then
        run git -C "$destination" checkout --detach "$revision"
        return 0
    fi

    fetched_revision=$(git -C "$destination" rev-parse FETCH_HEAD)
    [[ $fetched_revision == "$revision" ]] ||
        die "Fetched revision does not match the pin for $destination"
    git -C "$destination" checkout --detach "$revision"
    current_revision=$(git -C "$destination" rev-parse HEAD)
    [[ $current_revision == "$revision" ]] ||
        die "Checkout did not reach the pinned revision: $destination"
}

deploy_zsh() {
    local zsh_dir custom_dir plugin name repository revision

    zsh_dir="$HOME/.oh-my-zsh"
    custom_dir="$zsh_dir/custom"
    ensure_git_checkout "$OH_MY_ZSH_REPOSITORY" "$OH_MY_ZSH_REVISION" "$zsh_dir"

    for plugin in "${ZSH_PLUGIN_SOURCES[@]}"; do
        IFS='|' read -r name repository revision <<<"$plugin"
        ensure_git_checkout "$repository" "$revision" "$custom_dir/plugins/$name"
    done

    ensure_link "$REPO_DIR/configs/zsh/zshrc" "$HOME/.zshrc"
    ensure_link "$REPO_DIR/configs/zsh/zprofile" "$HOME/.zprofile"
    ensure_link "$REPO_DIR/configs/zsh/ziggy.zsh-theme" \
        "$custom_dir/themes/ziggy.zsh-theme"
    remove_managed_link "$REPO_DIR/configs/zsh/p10k.zsh" "$HOME/.p10k.zsh"
}

write_managed_file() {
    local destination=$1
    local content=$2
    local description=$3

    if [[ -f $destination ]] && [[ $(<"$destination") == "$content" ]]; then
        info "Already current: $destination"
        return 0
    fi

    ensure_real_directory "$(dirname "$destination")"
    backup_path "$destination"
    if [[ $DRY_RUN == true ]]; then
        info "Would write $description: $destination"
    else
        printf '%s\n' "$content" >"$destination"
        info "Wrote $description: $destination"
    fi
}

write_hyprpaper_source() {
    local config_dir wallpaper destination content
    config_dir=$(config_home)
    wallpaper="$(data_home)/simple-hyprland/backgrounds/dark-cat-rosewater.png"
    destination="$config_dir/hypr/hyprpaper.d/simple-hyprland.conf"
    content=$(printf 'wallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}' "$wallpaper")

    write_managed_file "$destination" "$content" 'Hyprpaper wallpaper source'
}

write_qt6ct_config() {
    local config_dir destination palette content
    config_dir=$(config_home)
    destination="$config_dir/qt6ct/qt6ct.conf"
    palette="$config_dir/qt6ct/colors/ziggy.conf"
    content=$(cat <<EOF
[Appearance]
color_scheme_path=$palette
custom_palette=true
icon_theme=Tela-circle-dracula
standard_dialogs=default
style=Fusion

[Fonts]
fixed="JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0,0,0,0,0,0,1"
general="JetBrainsMono Nerd Font,11,-1,5,50,0,0,0,0,0,0,0,0,0,0,1"

[Interface]
activate_item_on_single_click=1
dialog_buttons_have_icons=1
menus_have_icons=true
show_shortcuts_in_context_menus=true
toolbutton_style=4
EOF
)

    write_managed_file "$destination" "$content" 'qt6ct settings'
}

install_data_file() {
    local source=$1
    local destination=$2

    if [[ -f $destination ]] && cmp -s -- "$source" "$destination"; then
        return 0
    fi

    ensure_real_directory "$(dirname "$destination")"
    backup_path "$destination"
    if [[ $DRY_RUN == true ]]; then
        info "Would install asset: $destination"
    else
        install -m 0644 -- "$source" "$destination"
    fi
}

deploy_assets() {
    local asset_root source
    asset_root="$(data_home)/simple-hyprland"

    while IFS= read -r -d '' source; do
        install_data_file "$source" "$asset_root/backgrounds/${source##*/}"
    done < <(find "$REPO_DIR/assets/backgrounds" -maxdepth 1 -type f -print0)
}

deploy_theme_archive() {
    local archive=$1
    local destination_root=$2
    local directory_name=$3
    local destination marker digest temporary
    destination="$destination_root/$directory_name"
    marker="$destination/.simple-hyprland-source"
    digest=$(sha256sum -- "$archive")
    digest=${digest%% *}

    if [[ -f $marker ]] && [[ $(<"$marker") == "$digest" ]]; then
        info "Theme is current: $destination"
        return 0
    fi

    ensure_real_directory "$destination_root"
    backup_path "$destination"
    if [[ $DRY_RUN == true ]]; then
        info "Would extract theme: $archive -> $destination_root"
        return 0
    fi

    temporary=$(mktemp -d)
    tar -xJf "$archive" -C "$temporary"
    [[ -d $temporary/$directory_name ]] || die "Archive does not contain $directory_name: $archive"
    mv -- "$temporary/$directory_name" "$destination"
    rmdir -- "$temporary"
    printf '%s\n' "$digest" >"$marker"
    info "Installed theme: $destination"
}

deploy_themes() {
    local data_dir
    data_dir=$(data_home)
    deploy_theme_archive "$REPO_DIR/assets/icons/Tela-circle-dracula.tar.xz" "$data_dir/icons" 'Tela-circle-dracula'
}

install_packages() {
    local packages=("${CORE_PACKAGES[@]}" "${DESKTOP_PACKAGES[@]}")

    if [[ $WITH_HERMES_AGENT == true ]]; then
        packages+=("${DOCKER_PACKAGES[@]}")
    fi

    info 'Installing official Arch packages...'
    run /usr/bin/sudo -- /usr/bin/pacman -Syu --needed --noconfirm "${packages[@]}"
}

configure_hermes_agent_docker() {
    local source_dir state_dir group socket_path socket_state
    source_dir="$(data_home)/simple-hyprland/sources/hermes-agent-docker"
    state_dir="$(data_home)/simple-hyprland/hermes"

    for group in $(/usr/bin/id -Gn -- "$TARGET_USER"); do
        [[ $group != docker ]] ||
            die "$TARGET_USER belongs to the root-equivalent docker group. Remove that membership before installing Hermes Agent."
    done

    ensure_git_checkout "$HERMES_DOCKER_REPOSITORY" "$HERMES_DOCKER_REVISION" "$source_dir"

    info 'Installing the root-only Docker socket policy...'
    run /usr/bin/sudo -- /usr/bin/install -D -m 0644 \
        "$REPO_DIR/configs/systemd/docker.socket.d/simple-hyprland.conf" \
        /etc/systemd/system/docker.socket.d/simple-hyprland.conf
    run /usr/bin/sudo -- /usr/bin/systemctl daemon-reload
    run /usr/bin/sudo -- /usr/bin/systemctl disable docker.service

    info 'Enabling Docker socket activation...'
    run /usr/bin/sudo -- /usr/bin/systemctl enable --now docker.socket
    run /usr/bin/sudo -- /usr/bin/systemctl restart docker.socket

    if [[ $DRY_RUN == false ]]; then
        socket_path=/run/docker.sock
        socket_state=$(/usr/bin/stat -Lc '%a %u %g' -- "$socket_path") ||
            die "Cannot inspect the Docker socket: $socket_path"
        [[ $socket_state == '600 0 0' ]] ||
            die "Docker socket is not root-only: $socket_state"
    fi

    info "Building pinned Hermes Agent image: $HERMES_DOCKER_IMAGE"
    run /usr/bin/sudo -- /usr/bin/docker --host unix:///run/docker.sock build --pull --network host \
        --file "$REPO_DIR/configs/docker/hermes-agent.Dockerfile" \
        --tag "$HERMES_DOCKER_IMAGE" \
        "$source_dir"

    info 'Verifying the hardened Hermes Agent image without network access...'
    run /usr/bin/sudo -- /usr/bin/docker --host unix:///run/docker.sock run \
        --rm \
        --pull=never \
        --network none \
        --entrypoint /bin/sh \
        "$HERMES_DOCKER_IMAGE" \
        -euc 'groups=$(/usr/bin/id -nG)
case " $groups " in *" sudo "*|*" docker "*) exit 1 ;; esac
if /usr/bin/sudo -n /usr/bin/true 2>/dev/null; then exit 1; fi
hermes skills list >/dev/null'

    if [[ $DRY_RUN == true ]]; then
        info "Would create private Hermes state directory: $state_dir"
    else
        install -d -m 0700 -- "$state_dir"
    fi
    remove_managed_link "$REPO_DIR/scripts/hermes-docker" "$HOME/.local/bin/hermes-docker"
    info 'Installing the root-owned Hermes Docker launcher...'
    run /usr/bin/sudo -- /usr/bin/install -D -m 0755 \
        "$REPO_DIR/scripts/hermes-docker" /usr/local/bin/hermes-docker
}

configure_command_not_found() {
    info 'Enabling automatic pkgfile database updates...'
    run /usr/bin/sudo -- /usr/bin/systemctl enable --now pkgfile-update.timer
}

configure_getty() {
    local destination temporary content
    destination='/etc/systemd/system/getty@tty1.service.d/simple-hyprland.conf'

    if [[ $AUTOLOGIN == true ]]; then
        content=$(cat <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $TARGET_USER --noclear %I \$TERM
EOF
        )

        if [[ $DRY_RUN == true ]]; then
            info "Would install tty1 auto-login for $TARGET_USER: $destination"
        else
            temporary=$(mktemp)
            printf '%s\n' "$content" >"$temporary"
            run /usr/bin/sudo -- /usr/bin/install -D -m 0644 "$temporary" "$destination"
            rm -f -- "$temporary"
            info "Installed tty1 auto-login for $TARGET_USER: $destination"
        fi
    else
        if [[ $DRY_RUN == true ]]; then
            info "Would remove legacy tty1 auto-login drop-in: $destination"
        else
            info "Removing legacy tty1 auto-login drop-in: $destination"
        fi
        run /usr/bin/sudo -- /usr/bin/rm -f -- "$destination"
    fi

    info 'Reloading systemd units and enabling tty1 getty...'
    run /usr/bin/sudo -- /usr/bin/systemctl daemon-reload
    run /usr/bin/sudo -- /usr/bin/systemctl enable getty@tty1.service
    if /usr/bin/pacman -Q sddm >/dev/null 2>&1; then
        info 'Disabling SDDM...'
        run /usr/bin/sudo -- /usr/bin/systemctl disable sddm.service
        info 'Removing the unused SDDM package...'
        run /usr/bin/sudo -- /usr/bin/pacman -Rns --noconfirm sddm
    else
        info 'SDDM is not installed.'
    fi
}

configure_power_management() {
    local power_script service_file rule_file
    power_script='/usr/local/lib/simple-hyprland/apply-power-profile'
    service_file='/etc/systemd/system/simple-hyprland-power-profile.service'
    rule_file='/etc/udev/rules.d/99-simple-hyprland-power-profile.rules'

    info 'Installing TuneD AC and battery profile switching...'
    run /usr/bin/sudo -- /usr/bin/install -D -m 0755 \
        "$REPO_DIR/configs/tuned/simple-hyprland-power-profile.sh" "$power_script"
    run /usr/bin/sudo -- /usr/bin/install -D -m 0644 \
        "$REPO_DIR/configs/systemd/simple-hyprland-power-profile.service" "$service_file"
    run /usr/bin/sudo -- /usr/bin/install -D -m 0644 \
        "$REPO_DIR/configs/udev/99-simple-hyprland-power-profile.rules" "$rule_file"

    run /usr/bin/sudo -- /usr/bin/systemctl daemon-reload
    run /usr/bin/sudo -- /usr/bin/systemctl enable \
        tuned.service tuned-ppd.service simple-hyprland-power-profile.service
    run /usr/bin/sudo -- /usr/bin/systemctl start simple-hyprland-power-profile.service
    run /usr/bin/sudo -- /usr/bin/udevadm control --reload-rules
}

set_default_shell() {
    local current_shell passwd_entry
    passwd_entry=$(/usr/bin/getent passwd "$TARGET_USER") ||
        die "Cannot read the account record for $TARGET_USER."
    IFS=: read -r _ _ _ _ _ _ current_shell <<<"$passwd_entry"
    [[ -n $current_shell ]] || die "Cannot determine the login shell for $TARGET_USER."
    if [[ $current_shell == /usr/bin/zsh ]]; then
        info 'Zsh is already the default login shell.'
        return 0
    fi

    info 'Setting Zsh as the default login shell...'
    run /usr/bin/sudo -- /usr/bin/chsh -s /usr/bin/zsh "$TARGET_USER"
}

write_log() {
    local log_dir log_file
    [[ $DRY_RUN == false ]] || return 0
    log_dir="$(state_home)/simple-hyprland"
    log_file="$log_dir/install.log"
    mkdir -p -- "$log_dir"
    printf '%s setup completed from %s\n' "$(date --iso-8601=seconds)" "$REPO_DIR" >>"$log_file"
}

main() {
    parse_args "$@"
    check_environment
    confirm_install

    [[ $DOTFILES_ONLY == true ]] || install_packages
    deploy_dotfiles
    deploy_zsh
    deploy_assets
    write_hyprpaper_source
    write_qt6ct_config
    deploy_themes
    [[ $DOTFILES_ONLY == true ]] || set_default_shell
    [[ $DOTFILES_ONLY == true ]] || configure_getty
    [[ $DOTFILES_ONLY == true ]] || configure_power_management
    [[ $DOTFILES_ONLY == true ]] || configure_command_not_found
    [[ $WITH_HERMES_AGENT == true ]] && configure_hermes_agent_docker
    write_log

    if [[ $DRY_RUN == true ]]; then
        printf '\nDry run complete. No changes were made.\n'
        return 0
    fi

    printf '\nSimple Hyprland setup complete.\n'
    [[ -z $BACKUP_ROOT ]] || printf 'Backup: %s\n' "$BACKUP_ROOT"
    if [[ $AUTOLOGIN == true ]]; then
        printf 'Restart to enter the tty1 auto-login Hyprland session.\n'
    else
        printf 'Restart, then log in on tty1 to enter the Hyprland session.\n'
    fi
    printf 'Add machine-specific overrides to %s/hypr/local.lua.\n' "$(config_home)"
}
