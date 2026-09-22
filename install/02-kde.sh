#!/usr/bin/env bash
kde_install() {
    apt_install kde-plasma-desktop plasma-session-wayland sddm konsole dolphin plasma-nm xdg-desktop-portal-kde libkf6config-bin
    need_commands plasmashell startplasma-wayland
    kde_configure_login
    manual KDE 'Reboot to use SDDM with Plasma Wayland preselected, then sign in normally and test Parallels graphics. The current session has not been restarted.'
    if apt-cache show plasma-session-x11 >/dev/null 2>&1; then
        manual 'KDE X11 fallback' 'If Wayland is unusable, install the official plasma-session-x11 package after checking its candidate; existing GNOME sessions remain.'
    else
        manual 'KDE session fallback' 'No Plasma X11 package found; use another existing supported login session if Parallels graphics fail.'
    fi
}
kde_configure_login() {
    local session='' entry entries sddm_home
    need_commands kwriteconfig6 sddm debconf-set-selections systemctl
    entries=$(dpkg-query -L plasma-session-wayland)
    # Discover the packaged session name rather than assuming plasma/plasmawayland.
    while IFS= read -r entry; do
        case "$entry" in
            /usr/share/wayland-sessions/plasma*.desktop)
                [[ -f $entry ]] || continue
                [[ -z $session ]] || { fail 'Multiple Plasma Wayland session entries; cannot choose a default.'; return 1; }
                session=${entry##*/} ;;
        esac
    done <<< "$entries"
    [[ -n $session ]] || { fail 'Plasma Wayland session entry is missing; display manager unchanged.'; return 1; }
    sddm_home=$(getent passwd sddm | cut -d: -f6)
    [[ $sddm_home == /* && -d $sddm_home ]] || { fail 'SDDM home directory is missing'; return 1; }
    sudo test ! -L "$sddm_home/state.conf"
    sudo -u sddm kwriteconfig6 --file "$sddm_home/state.conf" --group Last --key Session "$session"

    # Keep Debian's selection and systemd's boot alias consistent. No --now:
    # switching the boot service must not stop the running GNOME session.
    [[ ! -L /etc/X11/default-display-manager ]] || { fail 'Refusing symlink default-display-manager'; return 1; }
    printf 'sddm shared/default-x-display-manager select sddm\n' | sudo debconf-set-selections
    printf '/usr/bin/sddm\n' > "$WS_TMP/default-display-manager"
    sudo install -m 0644 "$WS_TMP/default-display-manager" /etc/X11/default-display-manager
    sudo systemctl enable --force sddm.service
    sudo systemctl set-default graphical.target
    [[ $(readlink -f /etc/systemd/system/display-manager.service) == */sddm.service ]] || { fail 'SDDM boot service selection failed'; return 1; }
}
keyboard_install() {
    apt_install keyboard-configuration console-setup libkf6config-bin
    need_commands kwriteconfig6 setupcon
    sudo python3 "$WS_ROOT/tools/keyboard_config.py" /etc/default/keyboard
    sudo setupcon --save-only

    # Native KConfig writer preserves unrelated preferences. Run as the user.
    kwriteconfig6 --file kxkbrc --group Layout --key Model pc105
    kwriteconfig6 --file kxkbrc --group Layout --key LayoutList fr
    kwriteconfig6 --file kxkbrc --group Layout --key VariantList ''
    kwriteconfig6 --file kxkbrc --group Layout --key Use --type bool true
    # Plasma uses 0=on, 1=off, 2=unchanged (also for KWin Wayland).
    kwriteconfig6 --file kcminputrc --group Keyboard --key NumLock 0

    sudo install -d -m 0755 /etc/sddm.conf.d
    [[ ! -L /etc/sddm.conf.d/90-workstation-keyboard.conf ]] || { fail 'Refusing symlink SDDM keyboard configuration'; return 1; }
    printf '[General]\nNumlock=on\n' > "$WS_TMP/sddm-keyboard.conf"
    sudo install -m 0644 "$WS_TMP/sddm-keyboard.conf" /etc/sddm.conf.d/90-workstation-keyboard.conf
    manual Keyboard 'After reboot, sign in to the preselected Plasma session: French PC AZERTY (fr/pc105) and NumLock on. Existing GNOME input sources are separate. SDDM Numlock applies to its X11 greeter; a Wayland greeter needs compositor-specific settings. /etc/sddm.conf can override the drop-in.'
}
main() {
    component required KDE kde_install 'Minimal Plasma desktop; select SDDM and Plasma Wayland for the next boot, preserving the running session.'
    component required Keyboard keyboard_install 'French PC AZERTY by default; enable NumLock at Plasma startup and for the SDDM X11 greeter.'
}
