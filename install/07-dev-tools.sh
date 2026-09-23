#!/usr/bin/env bash
code_install() {
    repository vscode https://packages.microsoft.com/repos/code stable main https://packages.microsoft.com/keys/microsoft.asc asc
    # Prevent code's maintainer script from creating a second vendor source.
    printf 'code code/add-microsoft-repo boolean false\n' | sudo debconf-set-selections
    apt_install code
    code --version
}
zed_install() {
    apt_install libvulkan1 mesa-vulkan-drivers vulkan-tools xdg-desktop-portal-kde
    if [[ ! -x $HOME/.local/zed.app/bin/zed ]]; then
        if command -v zed >/dev/null; then zed --version; manual Zed 'External installation retained; check its desktop icon and Vulkan support.'; return; fi
        locked_download zed "$WS_TMP/archive"
        extract_archive "$WS_TMP/archive" "$WS_TMP/extracted"
        elf_arm64 "$WS_TMP/extracted/zed.app/bin/zed"
        [[ ! -e $HOME/.local/zed.app ]] || { fail 'Existing Zed directory without a working command; reconcile manually.'; return 1; }
        install -d -m 0755 "$HOME/.local" "$HOME/.local/bin"
        mv "$WS_TMP/extracted/zed.app" "$HOME/.local/zed.app"
        ln -s "$HOME/.local/zed.app/bin/zed" "$HOME/.local/bin/zed"
    fi
    if [[ ! -e $HOME/.local/bin/zed && ! -L $HOME/.local/bin/zed ]]; then
        install -d -m 0755 "$HOME/.local/bin"
        ln -s "$HOME/.local/zed.app/bin/zed" "$HOME/.local/bin/zed"
    fi
    local icon="$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png"
    [[ -f $icon ]] || { fail 'Zed archive is missing its desktop icon.'; return 1; }
    python3 "$WS_ROOT/tools/desktop_entry.py" zed Zed "$HOME/.local/zed.app/bin/zed" "$icon"
    "$HOME/.local/zed.app/bin/zed" --version
    manual Zed 'Desktop icon installed. Check vulkaninfo --summary and vkcube in the guest. If Parallels offers no compatible Vulkan GPU, use VS Code; installing Zed cannot fix that.'
}
toolbox_install() {
    log WARN 'Toolbox ARM64 exists, but JetBrains currently lists Ubuntu 22.04/24.04, not 26.04. GUI compatibility remains unverified.'
    apt_install libxi6 libxrender1 libxtst6 mesa-utils libfontconfig1 libgtk-3-bin dbus-user-session libxcb-keysyms1
    if command -v jetbrains-toolbox >/dev/null; then
        manual Toolbox 'Existing installation retained; open Toolbox, authenticate and choose IDEs manually.'; return
    fi
    locked_download toolbox "$WS_TMP/archive"
    extract_archive "$WS_TMP/archive" "$WS_TMP/extracted"
    local binary
    binary=$(find "$WS_TMP/extracted" -type f -name jetbrains-toolbox -print)
    [[ -n $binary && $binary != *$'\n'* ]]
    elf_arm64 "$binary"
    [[ ! -e $HOME/.local/share/workstation-toolbox ]] || { fail 'Existing Toolbox payload found; reconcile manually.'; return 1; }
    install -d -m 0755 "$HOME/.local/share" "$HOME/.local/bin"
    # Keep all bundled libraries alongside the executable, not just the ELF.
    local relative=${binary#"$WS_TMP/extracted/"}
    mv "$WS_TMP/extracted" "$HOME/.local/share/workstation-toolbox"
    ln -s "$HOME/.local/share/workstation-toolbox/$relative" "$HOME/.local/bin/jetbrains-toolbox"
    python3 "$WS_ROOT/tools/desktop_entry.py" jetbrains-toolbox 'JetBrains Toolbox' "$HOME/.local/bin/jetbrains-toolbox"
    [[ -x $HOME/.local/bin/jetbrains-toolbox ]]
    manual Toolbox 'ARM64 payload verified, GUI not launched. Open Toolbox, test on 26.04, authenticate and select only needed IDEs.'
}
bruno_install() {
    if package_installed bruno; then
        [[ $(dpkg-query -W -f='${Architecture}' bruno) == arm64 ]]
        need_commands bruno
        manual Bruno 'Existing ARM64 package retained; validate the GUI manually.'
        return
    fi
    locked_download bruno "$WS_TMP/bruno.deb"
    [[ $(dpkg-deb -f "$WS_TMP/bruno.deb" Architecture) == arm64 ]]
    [[ $(dpkg-deb -f "$WS_TMP/bruno.deb" Package) == bruno ]]
    # Only public, checksum-verified payloads live here; allow _apt traversal.
    chmod 0711 "$WS_TMP"
    chmod 0644 "$WS_TMP/bruno.deb"
    sudo env DEBIAN_FRONTEND=noninteractive apt-get --no-remove --no-install-recommends install -y "$WS_TMP/bruno.deb"
    package_installed bruno
    need_commands bruno
    manual Bruno 'Launch from Plasma to validate Electron on Ubuntu 26.04; bootstrap does not disable its sandbox.'
}
main() {
    component optional 'Visual Studio Code' code_install 'Official signed Microsoft ARM64 APT repository.'
    component optional Zed zed_install 'Pinned stable official ARM64 archive; Parallels Vulkan remains a manual check.'
    component optional 'JetBrains Toolbox' toolbox_install 'Official ARM64 archive; Ubuntu 26.04 is outside the currently listed tested distributions.'
    if selected desktop_bruno; then component optional Bruno bruno_install 'Selected stable ARM64 .deb with pinned SHA-256.'; else record SKIPPED Bruno 'Not selected in configurator.'; fi
}
