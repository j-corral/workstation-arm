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
main() { component required KDE kde_install 'Minimal official Plasma desktop, Wayland and SDDM; preserve GNOME and active display manager.'; }
