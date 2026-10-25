#!/usr/bin/env bash
# Apply the upstream Plasma layout once in a real Plasma session.
set -Eeuo pipefail
[[ ${XDG_CURRENT_DESKTOP:-} == *KDE* ]] || exit 0
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
share=${XDG_DATA_HOME:-$HOME/.local/share}
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/workstation/theme-backup"
marker="$backup_dir/mactahoe-layout-applied"
[[ -f "$share/plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/layouts/org.kde.plasma.desktop-layout.js" ]]
[[ -f "$share/wallpapers/MacTahoe-Light/contents/images/3840x2160.jpeg" ]]
if [[ ! -e $marker ]]; then
    mkdir -p -m 0700 "$backup_dir"
    if [[ -f $config_dir/plasma-org.kde.plasma.desktop-appletsrc ]]; then
        cp -p "$config_dir/plasma-org.kde.plasma.desktop-appletsrc" "$backup_dir/plasma-org.kde.plasma.desktop-appletsrc.before-mactahoe"
    fi
    plasma-apply-lookandfeel --apply com.github.vinceliuice.MacTahoe-Light --resetLayout
    plasma-apply-wallpaperimage "$share/wallpapers/MacTahoe-Light/contents/images/3840x2160.jpeg"
    plasma-apply-cursortheme MacTahoe-light
    : > "$marker"
fi

selected() {
    local name=$1 choices="$config_dir/workstation/components.conf"
    [[ -r $choices ]] && grep -Fxq "$name=1" "$choices"
}

disable_unsafe_gtk_appmenu() {
    local sanitizer=${WORKSTATION_GTK_SETTINGS:-/usr/local/lib/workstation/gtk-settings}
    local gtk_settings="$config_dir/gtk-3.0/settings.ini"
    [[ -x $sanitizer && -f $gtk_settings ]] || return 0
    "$sanitizer" "$gtk_settings"
}

enabled_output_count() {
    command -v kscreen-doctor >/dev/null 2>&1 || return 1
    local line output_seen=0 count=0
    while IFS= read -r line; do
        if [[ $line == Output:* ]]; then
            output_seen=1
        elif (( output_seen )) && [[ $line =~ ^[[:space:]]+enabled$ ]]; then
            ((count += 1))
            output_seen=0
        fi
    done < <(kscreen-doctor -o 2>/dev/null)
    printf '%s\n' "$count"
}

configure_selected_dock_launchers() {
    local applets="$config_dir/plasma-org.kde.plasma.desktop-appletsrc"
    [[ -r $applets ]] || return 0

    local containment='' applet='' line dock_containment='' dock_applet=''
    while IFS= read -r line; do
        if [[ $line =~ ^\[Containments\]\[([0-9]+)\]\[Applets\]\[([0-9]+)\]$ ]]; then
            containment=${BASH_REMATCH[1]}
            applet=${BASH_REMATCH[2]}
        elif [[ $line == 'plugin=org.kde.plasma.icontasks' || $line == 'plugin=org.kde.plasma.taskmanager' ]]; then
            dock_containment=$containment
            dock_applet=$applet
            break
        fi
    done < "$applets"
    [[ -n $dock_containment && -n $dock_applet ]] || return 0

    local -a managed=(
        'applications:chatgpt.desktop'
        'applications:onlyoffice-desktopeditors.desktop'
        'applications:md.obsidian.Obsidian.desktop'
        'applications:bruno.desktop'
        'applications:solaar.desktop'
        'applications:com.bitwarden.desktop'
    ) selected_launchers=() current_launchers=() retained=()
    selected desktop_chatgpt && selected_launchers+=('applications:chatgpt.desktop')
    selected desktop_onlyoffice && selected_launchers+=('applications:onlyoffice-desktopeditors.desktop')
    selected desktop_obsidian && selected_launchers+=('applications:md.obsidian.Obsidian.desktop')
    selected desktop_bruno && selected_launchers+=('applications:bruno.desktop')
    selected desktop_solaar && selected_launchers+=('applications:solaar.desktop')
    selected desktop_bitwarden && selected_launchers+=('applications:com.bitwarden.desktop')

    local current launcher known
    current=$(kreadconfig6 --file "$applets" --group Containments --group "$dock_containment" --group Applets --group "$dock_applet" --group Configuration --group General --key launchers 2>/dev/null || true)
    IFS=',' read -ra current_launchers <<< "$current"
    for launcher in "${current_launchers[@]:-}"; do
        [[ -n $launcher ]] || continue
        known=0
        for managed_launcher in "${managed[@]}"; do
            [[ $launcher == "$managed_launcher" ]] && { known=1; break; }
        done
        (( known )) || retained+=("$launcher")
    done
    if [[ ${selected_launchers[0]+set} ]]; then
        retained+=("${selected_launchers[@]}")
    fi
    local joined=''
    if [[ ${retained[0]+set} ]]; then
        joined=$(IFS=,; printf '%s' "${retained[*]}")
    fi
    kwriteconfig6 --file "$applets" --group Containments --group "$dock_containment" --group Applets --group "$dock_applet" --group Configuration --group General --key launchers "$joined"
    # Plasma visibility 1 is Auto Hide.  KWin/Wayland with Parallels virtual
    # multi-display connectors can leave an auto-hidden panel above the pointer
    # input surface.  Keep the macOS-style dock on one display, but use an
    # always-visible panel when more than one output is enabled.
    local outputs
    outputs=$(enabled_output_count || true)
    if [[ ${outputs:-0} -gt 1 ]]; then
        kwriteconfig6 --file "$applets" --group Containments --group "$dock_containment" --key visibility 0
    else
        kwriteconfig6 --file "$applets" --group Containments --group "$dock_containment" --key visibility 1
    fi
}

configure_start_launcher_icon() {
    local applets="$config_dir/plasma-org.kde.plasma.desktop-appletsrc"
    [[ -r $applets ]] || return 0

    local containment='' applet='' line launcher_containment='' launcher_applet=''
    while IFS= read -r line; do
        if [[ $line =~ ^\[Containments\]\[([0-9]+)\]\[Applets\]\[([0-9]+)\]$ ]]; then
            containment=${BASH_REMATCH[1]}
            applet=${BASH_REMATCH[2]}
        elif [[ $line == 'plugin=org.kde.plasma.kickoff' || $line == 'plugin=org.kde.plasma.kicker' || $line == 'plugin=org.kde.plasma.applicationlauncher' ]]; then
            launcher_containment=$containment
            launcher_applet=$applet
            break
        fi
    done < "$applets"
    [[ -n $launcher_containment && -n $launcher_applet ]] || return 0

    # view-grid is a neutral, bundled symbol.  It does not imitate a vendor
    # logo and remains available when the icon theme falls back to Breeze.
    kwriteconfig6 --file "$applets" --group Containments --group "$launcher_containment" --group Applets --group "$launcher_applet" --group Configuration --group General --key icon view-grid
}

# The layout is applied once; the selected launchers are reconciled at each
# Plasma login so rerunning the configurator changes the dock without a reset.
configure_selected_dock_launchers
configure_start_launcher_icon
# Ubuntu 26.04's GTK3 global-menu module can crash Chromium-based browsers.
# Keep the Plasma top panel but let GTK applications render their own menus.
disable_unsafe_gtk_appmenu
