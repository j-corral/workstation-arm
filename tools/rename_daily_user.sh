#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
config=/etc/workstation/rename-daily-user.env
[[ -f $config ]] || exit 0
# shellcheck disable=SC1090
source "$config"
valid() { [[ ${1:-} =~ ^[a-z_][a-z0-9_-]{0,30}$ && ${1:-} != root ]]; }
valid "$OLD_USER" && valid "$NEW_USER" && [[ $OLD_USER != "$NEW_USER" ]] || exit 1
id "$OLD_USER" >/dev/null 2>&1 && ! id "$NEW_USER" >/dev/null 2>&1 || exit 1
old_home=$(getent passwd "$OLD_USER" | awk -F: '{print $6}')
new_home=/home/$NEW_USER
[[ $old_home == /home/* && -d $old_home && ! -e $new_home ]] || exit 1
usermod -l "$NEW_USER" "$OLD_USER"
if getent group "$OLD_USER" >/dev/null; then groupmod -n "$NEW_USER" "$OLD_USER"; fi
usermod -d "$new_home" -m "$NEW_USER"
# Repair layouts installed by an earlier bootstrap revision that embedded the
# old home directory in a Plasma autostart entry.
desktop="$new_home/.config/autostart/workstation-mactahoe.desktop"
if [[ -f $desktop ]]; then
    sed -i "s|Exec=/home/$OLD_USER/.local/bin/workstation-mactahoe-apply|Exec=/usr/local/lib/workstation/mactahoe-first-login|" "$desktop"
fi
gpasswd -d "$NEW_USER" sudo 2>/dev/null || true
rm -f "$config"
