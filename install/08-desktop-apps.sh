#!/usr/bin/env bash
konsole_install() {
    apt_install konsole libkf6config-bin
    need_commands konsole kwriteconfig6 kreadconfig6
    local directory="$HOME/.local/share/konsole" scheme="$HOME/.local/share/konsole/Workstation.colorscheme" profile="$HOME/.local/share/konsole/Workstation.profile"
    install -d -m 0755 "$directory"
    if [[ ! -e $scheme ]]; then
        cat > "$scheme" <<'EOF'
[Background]
Color=22,27,35

[Foreground]
Color=231,238,247

[General]
Description=Workstation translucent
Opacity=0.86
Blur=true
EOF
    fi
    if [[ ! -e $profile ]]; then
        cat > "$profile" <<'EOF'
[Appearance]
ColorScheme=Workstation

[General]
Name=Workstation
Parent=FALLBACK/
EOF
    fi
    local current_profile
    current_profile=$(kreadconfig6 --file konsolerc --group 'Desktop Entry' --key DefaultProfile)
    if [[ -z $current_profile || $current_profile == Workstation.profile ]]; then
        kwriteconfig6 --file konsolerc --group 'Desktop Entry' --key DefaultProfile Workstation.profile
    else
        manual Konsole "Existing default profile $current_profile retained; select Workstation in Konsole if desired."
    fi
    [[ -f /usr/share/applications/org.kde.konsole.desktop ]] || { fail 'Konsole desktop service is missing.'; return 1; }
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication konsole
    kwriteconfig6 --file kdeglobals --group General --key TerminalService org.kde.konsole.desktop
    manual Konsole 'Default Workstation profile enables a translucent background in Plasma; verify compositor rendering in the guest.'
}
foot_install() {
    apt_install foot fonts-jetbrains-mono
    need_commands foot
    local directory="$HOME/.config/foot" settings="$HOME/.config/foot/foot.ini"
    install -d -m 0755 "$directory"
    [[ ! -L $settings ]] || { fail 'Refusing symlink Foot configuration.'; return 1; }
    if [[ ! -e $settings ]]; then
        install -m 0644 "$WS_ROOT/config/foot.ini" "$settings"
    fi
    foot --check-config --config="$settings"
    manual Foot 'Optional Wayland terminal with translucent background and JetBrains Mono; launch with foot in Plasma Wayland. Konsole remains the default.'
}
onlyoffice_install() {
    repository onlyoffice https://download.onlyoffice.com/repo/debian squeeze main https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE asc
    apt_install onlyoffice-desktopeditors
    need_commands desktopeditors
    manual ONLYOFFICE 'Open a local DOCX, XLSX and PPTX in Plasma to validate the GUI and file associations.'
}
solaar_install() {
    apt_install solaar
    need_commands solaar
    manual Solaar 'Attach the Logitech receiver to the guest (or pair via Bluetooth), then run solaar show. MX Keys S and MX Anywhere 2 settings depend on the detected HID++ features.'
}
bitwarden_install() {
    apt_install flatpak
    need_commands flatpak
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user --noninteractive --assumeyes --arch=aarch64 flathub com.bitwarden.desktop
    # --show-arch is not available in Flatpak 1.16 shipped by Ubuntu 26.04.
    flatpak info --user --show-ref com.bitwarden.desktop | grep -Fxq 'app/com.bitwarden.desktop/aarch64/stable' || { fail 'Bitwarden Flatpak is not aarch64.'; return 1; }
    manual Bitwarden 'Open the desktop app and sign in interactively; no vault credentials are handled by bootstrap.'
}
keepassxc_install() { apt_install keepassxc; need_commands keepassxc; }
kwallet_install() {
    apt_install kwalletmanager
    manual KWallet 'On first prompt, choose Classic (Blowfish encrypted file) and set a private wallet password. GPG mode requires an existing encryption-capable GPG key; bootstrap does not create one or store a password.'
}
obsidian_install() {
    apt_install flatpak
    need_commands flatpak
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user --noninteractive --assumeyes --arch=aarch64 flathub md.obsidian.Obsidian
    flatpak info --user --show-ref md.obsidian.Obsidian | grep -Fxq 'app/md.obsidian.Obsidian/aarch64/stable' || { fail 'Obsidian Flatpak is not aarch64.'; return 1; }
    # Replace only the old launcher this bootstrap created; do not touch vaults
    # or the extracted AppImage payload, which may be useful for rollback.
    local legacy="$HOME/.local/share/applications/workstation-obsidian.desktop"
    if [[ -f $legacy ]] && grep -Fq "$HOME/.local/bin/workstation-obsidian" "$legacy"; then rm -f -- "$legacy"; fi
    manual Obsidian 'Official verified aarch64 Flatpak installed. Log out/in if its icon is not yet visible; disable GPU in Flatseal if Parallels rendering is unstable. Existing vaults are untouched.'
}
main() {
    component optional 'Konsole translucent terminal' konsole_install 'Default KDE terminal with a user-owned translucent profile.'
    component optional 'Foot terminal' foot_install 'Optional native ARM64 Wayland terminal with translucent color theme; Konsole remains default.'
    component optional KeePassXC keepassxc_install 'Native ARM64 Ubuntu package.'
    component optional 'KWallet Manager' kwallet_install 'Manage Plasma secrets interactively; no automatic wallet/password creation.'
    if selected desktop_obsidian; then component optional Obsidian obsidian_install 'Selected ARM64 Flatpak.'; else record SKIPPED Obsidian 'Not selected in configurator.'; fi
    if selected desktop_onlyoffice; then component optional ONLYOFFICE onlyoffice_install 'Selected local Office editor.'; else record SKIPPED ONLYOFFICE 'Not selected in configurator.'; fi
    if selected desktop_solaar; then component optional Solaar solaar_install 'Selected Logitech manager.'; else record SKIPPED Solaar 'Not selected in configurator.'; fi
    if selected desktop_bitwarden; then component optional Bitwarden bitwarden_install 'Selected aarch64 Flatpak.'; else record SKIPPED Bitwarden 'Not selected in configurator.'; fi
    manual 'Proton Mail' 'Unsupported for automatic ARM64 installation: official Linux .deb inspected is amd64 (1.14.0). Use the web app manually.'
}
