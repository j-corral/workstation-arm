#!/usr/bin/env bash
kde_install() {
    # SDDM's default greeter uses X11 even when the selected desktop is Wayland.
    # apt_install disables Recommends, so install its server/input driver explicitly.
    apt_install kde-plasma-desktop plasma-session-wayland sddm sddm-theme-breeze xserver-xorg-core xserver-xorg-input-libinput konsole dolphin plasma-nm xdg-desktop-portal-kde libkf6config-bin
    need_commands plasmashell startplasma-wayland
    [[ -x /usr/bin/X ]] || { fail 'SDDM X11 server /usr/bin/X is missing; display manager unchanged.'; return 1; }
    /usr/bin/X -version
    [[ -f /usr/share/sddm/themes/breeze/Main.qml ]] || { fail 'SDDM Breeze theme is missing'; return 1; }
    [[ ! -L /etc/sddm.conf ]] || { fail 'Refusing symlink SDDM configuration'; return 1; }
    # Use the highest-precedence local file; preserve its other settings.
    sudo kwriteconfig6 --file /etc/sddm.conf --group Theme --key Current breeze
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
    # The greeter has its own X server; user Plasma preferences do not apply.
    sudo install -d -m 0755 /etc/X11/xorg.conf.d
    [[ ! -L /etc/X11/xorg.conf.d/90-workstation-keyboard.conf ]] || { fail 'Refusing symlink Xorg keyboard configuration'; return 1; }
    sudo install -m 0644 "$WS_ROOT/config/90-workstation-keyboard.conf" /etc/X11/xorg.conf.d/90-workstation-keyboard.conf

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
    sudo kwriteconfig6 --file /etc/sddm.conf --group General --key Numlock on
    [[ $(kreadconfig6 --file kxkbrc --group Layout --key LayoutList) == fr ]]
    [[ $(kreadconfig6 --file kxkbrc --group Layout --key Model) == pc105 ]]
    [[ $(kreadconfig6 --file kcminputrc --group Keyboard --key NumLock) == 0 ]]
    manual Keyboard 'After reboot, sign in to the preselected Plasma session: French PC AZERTY (fr/pc105) and NumLock on. Existing GNOME input sources are separate. SDDM Numlock applies to its X11 greeter; a Wayland greeter needs compositor-specific settings. /etc/sddm.conf can override the drop-in.'
}
main() {
    component required KDE kde_install 'Minimal Plasma desktop; select SDDM and Plasma Wayland for the next boot, preserving the running session.'
    component required Keyboard keyboard_install 'French PC AZERTY by default; enable NumLock at Plasma startup and for the SDDM X11 greeter.'
    component optional MacTahoe mactahoe_install 'Pinned Plasma 6 desktop/SDDM theme; retain Breeze for recovery.'
}

mactahoe_install() {
    local source icons_source share icon_share config_dir
    apt_install qml6-module-qt5compat-graphicaleffects qml6-module-org-kde-plasma-plasma5support kwin-style-aurorae qt-style-kvantum libgtk-3-bin
    need_commands plasma-apply-lookandfeel kvantummanager gtk-update-icon-cache
    locked_download mactahoe "$WS_TMP/mactahoe.tar.gz"
    locked_download mactahoe_icons "$WS_TMP/mactahoe-icons.tar.gz"
    extract_archive "$WS_TMP/mactahoe.tar.gz" "$WS_TMP/theme"
    extract_archive "$WS_TMP/mactahoe-icons.tar.gz" "$WS_TMP/icon-theme"
    source="$WS_TMP/theme/MacTahoe-kde-cbf6a1f71b591d143184855d62f6272ce533e7c3"
    icons_source="$WS_TMP/icon-theme/MacTahoe-icon-theme-839848b9a8a38a92a6936e30c4abe35cc6f2546d"
    share=${XDG_DATA_HOME:-$HOME/.local/share}
    icon_share="$share/icons"
    config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
    python3 "$WS_ROOT/tools/theme_assets.py" prepare "$source" "$share" "$WS_TMP/greeter" "$config_dir"
    # The pinned upstream installer builds the icon/cursor links in private
    # staging only; our helper validates them before replacing managed themes.
    bash "$icons_source/install.sh" --dest "$WS_TMP/icons"
    python3 "$WS_ROOT/tools/theme_assets.py" icons "$WS_TMP/icons" "$icon_share"
    sudo python3 "$WS_ROOT/tools/theme_assets.py" copy "$WS_TMP/greeter" /usr/share/sddm/themes/MacTahoe
    [[ -f $share/plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light/contents/layouts/org.kde.plasma.desktop-layout.js ]]
    [[ -f $share/aurorae/themes/MacTahoe-Light/close.svg ]]
    [[ -f $icon_share/MacTahoe-light/index.theme ]]
    [[ -f $config_dir/Kvantum/MacTahoe/MacTahoe.kvconfig ]]
    kwriteconfig6 --file plasmarc --group Theme --key name MacTahoe-Light
    QT_QPA_PLATFORM=offscreen plasma-apply-colorscheme MacTahoeLight
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle kvantum
    kwriteconfig6 --file kdeglobals --group Icons --key Theme MacTahoe-light
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme MacTahoe-light
    kwriteconfig6 --file Kvantum/kvantum.kvconfig --group General --key theme MacTahoe
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme __aurorae__svg__MacTahoe-Light
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XAI
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ''
    install -d -m 0700 "$HOME/.local/bin" "$config_dir/autostart"
    install -m 0755 "$WS_ROOT/config/mactahoe-first-login.sh" "$HOME/.local/bin/workstation-mactahoe-apply"
    sed "s|Exec=PLACEHOLDER|Exec=$HOME/.local/bin/workstation-mactahoe-apply|" "$WS_ROOT/config/mactahoe-first-login.desktop" > "$WS_TMP/mactahoe.desktop"
    install -m 0644 "$WS_TMP/mactahoe.desktop" "$config_dir/autostart/workstation-mactahoe.desktop"
    "$HOME/.local/bin/workstation-mactahoe-apply"
    # Activate last: a download or staging failure leaves the installed Breeze greeter.
    sudo kwriteconfig6 --file /etc/sddm.conf --group Theme --key Current MacTahoe
    manual MacTahoe 'Reboot to apply. Breeze remains installed. For login-theme recovery: sudo kwriteconfig6 --file /etc/sddm.conf --group Theme --key Current breeze, then reboot. Runtime theme failures do not automatically switch to Breeze.'
}
