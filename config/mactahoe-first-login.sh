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
