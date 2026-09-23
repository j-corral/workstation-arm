#!/usr/bin/env bash
# SDDM runs this after its X11 server is ready and before the greeter starts.
# Keep the distribution hook, then select the requested Parallels resolution
# only on outputs that actually advertise it.
set -u

if [[ -x /usr/share/sddm/scripts/Xsetup ]]; then
    /usr/share/sddm/scripts/Xsetup || true
fi

command -v xrandr >/dev/null 2>&1 || exit 0
while read -r output state _; do
    [[ $state == connected ]] || continue
    xrandr --output "$output" --mode 1920x1080 >/dev/null 2>&1 || true
done < <(xrandr --query)
