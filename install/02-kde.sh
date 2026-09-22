#!/usr/bin/env bash
kde_install() {
    apt_install kde-plasma-desktop plasma-session-wayland sddm konsole dolphin plasma-nm xdg-desktop-portal-kde
    need_commands plasmashell startplasma-wayland
    # Never restart a live display manager or remove an existing desktop.
    manual KDE 'Select Plasma Wayland at login. To choose SDDM, run sudo dpkg-reconfigure sddm, then reboot; test Parallels graphics.'
    if apt-cache show plasma-session-x11 >/dev/null 2>&1; then
        manual 'KDE X11 fallback' 'If Wayland is unusable, install the official plasma-session-x11 package after checking its candidate; existing GNOME sessions remain.'
    else
        manual 'KDE session fallback' 'No Plasma X11 package found; use another existing supported login session if Parallels graphics fail.'
    fi
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
    manual Keyboard 'Reboot and select Plasma: French PC AZERTY (fr/pc105) and NumLock on. Existing GNOME input sources are separate. SDDM Numlock applies to its X11 greeter; a Wayland greeter needs compositor-specific settings. /etc/sddm.conf can override the drop-in.'
}
main() {
    component required KDE kde_install 'Minimal official Plasma desktop, Wayland and SDDM; preserve GNOME and active display manager.'
    component required Keyboard keyboard_install 'French PC AZERTY by default; enable NumLock at Plasma startup and for the SDDM X11 greeter.'
}
