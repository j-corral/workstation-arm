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
        'applications:onlyoffice-desktopeditors.desktop'
        'applications:md.obsidian.Obsidian.desktop'
        'applications:bruno.desktop'
        'applications:solaar.desktop'
        'applications:com.bitwarden.desktop'
    ) selected_launchers=() current_launchers=() retained=()
    selected desktop_onlyoffice && selected_launchers+=('applications:onlyoffice-desktopeditors.desktop')
    selected desktop_obsidian && selected_launchers+=('applications:md.obsidian.Obsidian.desktop')
    selected desktop_bruno && selected_launchers+=('applications:bruno.desktop')
    selected desktop_solaar && selected_launchers+=('applications:solaar.desktop')
    selected desktop_bitwarden && selected_launchers+=('applications:com.bitwarden.desktop')

    local current launcher known
    current=$(kreadconfig6 --file "$applets" --group Containments --group "$dock_containment" --group Applets --group "$dock_applet" --group Configuration --group General --key launchers 2>/dev/null || true)
    IFS=',' read -ra current_launchers <<< "$current"
    for launcher in "${current_launchers[@]}"; do
        [[ -n $launcher ]] || continue
        known=0
        for managed_launcher in "${managed[@]}"; do
            [[ $launcher == "$managed_launcher" ]] && { known=1; break; }
        done
        (( known )) || retained+=("$launcher")
    done
    retained+=("${selected_launchers[@]}")
    local joined
    joined=$(IFS=,; printf '%s' "${retained[*]}")
    kwriteconfig6 --file "$applets" --group Containments --group "$dock_containment" --group Applets --group "$dock_applet" --group Configuration --group General --key launchers "$joined"
}

# The layout is applied once; the selected launchers are reconciled at each
# Plasma login so rerunning the configurator changes the dock without a reset.
configure_selected_dock_launchers
