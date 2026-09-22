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
    [[ $(flatpak info --user --show-arch com.bitwarden.desktop) == aarch64 ]] || { fail 'Bitwarden Flatpak is not aarch64.'; return 1; }
    manual Bitwarden 'Open the desktop app and sign in interactively; no vault credentials are handled by bootstrap.'
}
spotify_web_install() {
    apt_install xdg-utils
    need_commands xdg-open
    local directory="$HOME/.local/share/applications" shortcut="$HOME/.local/share/applications/workstation-spotify-web.desktop"
    install -d -m 0755 "$directory"
    [[ ! -L $shortcut ]] || { fail 'Refusing symlink Spotify shortcut.'; return 1; }
    cat > "$WS_TMP/spotify-web.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Spotify (Web)
Comment=Spotify web player in the default browser
Exec=xdg-open https://open.spotify.com/
Icon=multimedia-player
Terminal=false
Categories=Audio;AudioVideo;Network;
EOF
    install -m 0644 "$WS_TMP/spotify-web.desktop" "$shortcut"
    manual Spotify 'Open Spotify (Web) from the application menu and sign in. Native Spotify Linux packages reviewed do not provide ARM64.'
}
keepassxc_install() { apt_install keepassxc; need_commands keepassxc; }
kwallet_install() {
    apt_install kwalletmanager
    manual KWallet 'On first prompt, choose Classic (Blowfish encrypted file) and set a private wallet password. GPG mode requires an existing encryption-capable GPG key; bootstrap does not create one or store a password.'
}
obsidian_install() {
    # The upstream ARM64 AppImage asks for the unversioned libz.so at load time.
    # Ubuntu provides it in zlib1g-dev; zlib1g alone provides only libz.so.1.
    apt_install zlib1g-dev
    local image="$WS_TMP/Obsidian.AppImage" destination="$HOME/.local/share/workstation-obsidian" launcher="$HOME/.local/bin/workstation-obsidian" old="$HOME/.local/bin/obsidian" digest
    if [[ -x $destination/AppRun ]]; then
        :
    else
        locked_download obsidian "$image"
        elf_arm64 "$image"
        # Extraction uses the checksum-locked upstream AppImage and avoids FUSE at startup.
        (cd "$WS_TMP" && "$image" --appimage-extract >/dev/null)
        [[ -x $WS_TMP/squashfs-root/AppRun ]] || { fail 'Obsidian AppImage extraction did not produce AppRun.'; return 1; }
        [[ ! -e $destination ]] || { fail 'Existing Obsidian payload needs reconciliation.'; return 1; }
        install -d -m 0755 "$HOME/.local/share" "$HOME/.local/bin"
        mv "$WS_TMP/squashfs-root" "$destination"
    fi
    cat > "$launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
app="$HOME/.local/share/workstation-obsidian/AppRun"
if command -v systemd-detect-virt >/dev/null && systemd-detect-virt --vm --quiet; then
    exec "$app" --disable-gpu "$@"
fi
exec "$app" "$@"
EOF
    chmod 0755 "$launcher"
    digest=$(python3 "$WS_ROOT/tools/artifacts.py" lookup "$WS_ROOT/config/downloads.json" obsidian | cut -f3)
    if [[ -f $old && ! -L $old ]] && printf '%s  %s\n' "$digest" "$old" | sha256sum --check --status; then
        [[ ! -e $destination/source.AppImage ]] || { fail 'Obsidian source backup already exists; reconcile manually.'; return 1; }
        mv "$old" "$destination/source.AppImage"
        ln -s "$launcher" "$old"
    elif [[ ! -e $old && ! -L $old ]]; then
        ln -s "$launcher" "$old"
    elif [[ ! -L $old || $(readlink "$old") != "$launcher" ]]; then
        manual Obsidian "Existing $old is not the bootstrap's pinned AppImage; it was retained. Use $launcher."
    fi
    python3 "$WS_ROOT/tools/desktop_entry.py" obsidian Obsidian "$launcher"
    manual Obsidian 'ARM64 libz.so supplied, AppImage extracted to avoid FUSE, and VM launcher disables Electron GPU. GUI compatibility still requires a live launch. Existing vaults are untouched.'
}
main() {
    component optional 'Konsole translucent terminal' konsole_install 'Default KDE terminal with a user-owned translucent profile.'
    component optional 'Foot terminal' foot_install 'Optional native ARM64 Wayland terminal with translucent color theme; Konsole remains default.'
    component optional KeePassXC keepassxc_install 'Native ARM64 Ubuntu package.'
    component optional 'KWallet Manager' kwallet_install 'Manage Plasma secrets interactively; no automatic wallet/password creation.'
    component optional Obsidian obsidian_install 'Extract pinned official ARM64 AppImage; use software rendering in a VM.'
    component optional ONLYOFFICE onlyoffice_install 'Official signed APT source, native ARM64 package, local Office files.'
    component optional Solaar solaar_install 'Native ARM64 Ubuntu package for supported Logitech HID++ devices.'
    component optional Bitwarden bitwarden_install 'Official Bitwarden Flatpak on Flathub for aarch64; account login remains interactive.'
    component optional 'Spotify Web' spotify_web_install 'Create a Spotify web-player launcher; no supported native ARM64 desktop package verified.'
    manual 'Proton Mail' 'Unsupported for automatic ARM64 installation: official Linux .deb inspected is amd64 (1.14.0). Use the web app manually.'
}
