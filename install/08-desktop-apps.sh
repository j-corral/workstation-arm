#!/usr/bin/env bash
konsole_install() {
    apt_install konsole libkf6config-bin fonts-jetbrains-mono
    need_commands konsole kwriteconfig6 kreadconfig6
    local directory="$HOME/.local/share/konsole" scheme="$HOME/.local/share/konsole/Workstation.colorscheme" profile="$HOME/.local/share/konsole/Workstation.profile"
    install -d -m 0755 "$directory"
    cat > "$WS_TMP/Workstation.colorscheme" <<'EOF'
[Background]
Color=17,24,39

[Foreground]
Color=248,250,252

[Color0]
Color=69,71,90

[Color1]
Color=243,139,168

[Color2]
Color=166,227,161

[Color3]
Color=249,226,175

[Color4]
Color=137,180,250

[Color5]
Color=203,166,247

[Color6]
Color=148,226,213

[Color7]
Color=186,194,222

[Color8]
Color=88,91,112

[Color9]
Color=243,139,168

[Color10]
Color=166,227,161

[Color11]
Color=249,226,175

[Color12]
Color=137,180,250

[Color13]
Color=203,166,247

[Color14]
Color=148,226,213

[Color15]
Color=205,214,244

[Cursor]
Color=137,180,250

[General]
Description=Workstation translucent 40%
Opacity=0.60
Blur=true
EOF
    install -m 0644 "$WS_TMP/Workstation.colorscheme" "$scheme"
    cat > "$WS_TMP/Workstation.profile" <<'EOF'
[Appearance]
ColorScheme=Workstation
Font=JetBrains Mono,12,-1,5,50,0,0,0,0,0

[General]
Name=Workstation
Parent=FALLBACK/
EOF
    install -m 0644 "$WS_TMP/Workstation.profile" "$profile"
    local current_profile
    current_profile=$(kreadconfig6 --file konsolerc --group 'Desktop Entry' --key DefaultProfile)
    if [[ -z $current_profile || $current_profile == Workstation.profile || $current_profile == 'Profile 1.profile' || $current_profile == Shell.profile ]]; then
        kwriteconfig6 --file konsolerc --group 'Desktop Entry' --key DefaultProfile Workstation.profile
    else
        manual Konsole "Existing default profile $current_profile retained; select Workstation in Konsole if desired."
    fi
    [[ -f /usr/share/applications/org.kde.konsole.desktop ]] || { fail 'Konsole desktop service is missing.'; return 1; }
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication konsole
    kwriteconfig6 --file kdeglobals --group General --key TerminalService org.kde.konsole.desktop
    manual Konsole 'The Workstation profile uses 40% transparency, JetBrains Mono 12pt and a high-contrast colour palette; verify compositor rendering in the guest.'
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
chatgpt_install() {
    local package="$WS_TMP/chatgpt_arm64.deb"
    if package_installed chatgpt; then
        [[ $(dpkg-query -W -f='${Architecture}' chatgpt) == arm64 ]]
        need_commands chatgpt
        manual ChatGPT 'Official ARM64 ChatGPT desktop app already installed; APT handles future updates.'
        return
    fi
    # This is the official current ARM64 .deb URL documented by OpenAI. Its
    # post-install setup adds the signed APT source used for later updates.
    download https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_arm64.deb "$package"
    [[ $(dpkg-deb -f "$package" Package) == chatgpt ]]
    [[ $(dpkg-deb -f "$package" Architecture) == arm64 ]]
    chmod 0711 "$WS_TMP"
    chmod 0644 "$package"
    apt_wait_for_locks
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 --no-remove --no-install-recommends install -y "$package"
    package_installed chatgpt
    [[ $(dpkg-query -W -f='${Architecture}' chatgpt) == arm64 ]]
    need_commands chatgpt
    manual ChatGPT 'Official ARM64 ChatGPT desktop preview installed. Launch ChatGPT from Plasma or run chatgpt, then sign in interactively. The package configures signed APT updates.'
}
solaar_install() {
    apt_install solaar libkf6config-bin
    need_commands solaar kwriteconfig6 kreadconfig6
    # These are the generic side-button names Plasma uses for HID mice. They
    # work independently of Solaar, including when an MX Anywhere is paired
    # by Bluetooth instead of through a Logitech receiver.
    kwriteconfig6 --file kcminputrc --group ButtonRebinds --group Mouse --key ExtraButton1 'Key,Meta+Ctrl+Right'
    kwriteconfig6 --file kcminputrc --group ButtonRebinds --group Mouse --key ExtraButton2 'Key,Meta+Ctrl+Left'
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Switch One Desktop to the Right' 'Meta+Ctrl+Right,Meta+Ctrl+Right,Switch One Desktop to the Right'
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key 'Switch One Desktop to the Left' 'Meta+Ctrl+Left,Meta+Ctrl+Left,Switch One Desktop to the Left'
    [[ $(kreadconfig6 --file kcminputrc --group ButtonRebinds --group Mouse --key ExtraButton1) == 'Key,Meta+Ctrl+Right' ]]
    [[ $(kreadconfig6 --file kcminputrc --group ButtonRebinds --group Mouse --key ExtraButton2) == 'Key,Meta+Ctrl+Left' ]]
    manual Solaar 'Attach the Logitech receiver to the guest (or pair via Bluetooth), then run solaar show. MX Anywhere side buttons are mapped to next/previous Plasma virtual desktop; log out/in after this configuration. If they do not react, run xev -event button in Plasma X11 while pressing each button: Parallels must forward the button events to the guest.'
}
bitwarden_install() {
    apt_install flatpak
    need_commands flatpak
    as_workstation_user flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    as_workstation_user flatpak install --user --noninteractive --assumeyes --arch=aarch64 flathub com.bitwarden.desktop
    # --show-arch is not available in Flatpak 1.16 shipped by Ubuntu 26.04.
    as_workstation_user flatpak info --user --show-ref com.bitwarden.desktop | grep -Fxq 'app/com.bitwarden.desktop/aarch64/stable' || { fail 'Bitwarden Flatpak is not aarch64.'; return 1; }
    manual Bitwarden 'Open the desktop app and sign in interactively; no vault credentials are handled by bootstrap.'
}
keepassxc_install() { apt_install keepassxc; need_commands keepassxc; }
obsidian_install() {
    apt_install flatpak
    need_commands flatpak
    as_workstation_user flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    as_workstation_user flatpak install --user --noninteractive --assumeyes --arch=aarch64 flathub md.obsidian.Obsidian
    as_workstation_user flatpak info --user --show-ref md.obsidian.Obsidian | grep -Fxq 'app/md.obsidian.Obsidian/aarch64/stable' || { fail 'Obsidian Flatpak is not aarch64.'; return 1; }
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
    if selected desktop_chatgpt; then component optional ChatGPT chatgpt_install 'Selected official ARM64 desktop preview; its package configures signed APT updates.'; else record SKIPPED ChatGPT 'Not selected in configurator.'; fi
    if selected desktop_obsidian; then component optional Obsidian obsidian_install 'Selected ARM64 Flatpak.'; else record SKIPPED Obsidian 'Not selected in configurator.'; fi
    if selected desktop_onlyoffice; then component optional ONLYOFFICE onlyoffice_install 'Selected local Office editor.'; else record SKIPPED ONLYOFFICE 'Not selected in configurator.'; fi
    if selected desktop_solaar; then component optional Solaar solaar_install 'Selected Logitech manager.'; else record SKIPPED Solaar 'Not selected in configurator.'; fi
    if selected desktop_bitwarden; then component optional Bitwarden bitwarden_install 'Selected aarch64 Flatpak.'; else record SKIPPED Bitwarden 'Not selected in configurator.'; fi
    manual 'Proton Mail' 'Unsupported for automatic ARM64 installation: official Linux .deb inspected is amd64 (1.14.0). Use the web app manually.'
}
