#!/usr/bin/env bash
desktop_install() { apt_install ghostty keepassxc; need_commands ghostty keepassxc; }
obsidian_install() {
    apt_install libfuse2t64
    if command -v obsidian >/dev/null; then
        manual Obsidian 'Existing installation retained; validate the GUI and sandbox manually.'; return
    fi
    locked_download obsidian "$WS_TMP/Obsidian.AppImage"
    elf_arm64 "$WS_TMP/Obsidian.AppImage"
    install -d -m 0755 "$HOME/.local/bin"
    install -m 0755 "$WS_TMP/Obsidian.AppImage" "$HOME/.local/bin/obsidian"
    python3 "$WS_ROOT/tools/desktop_entry.py" obsidian Obsidian "$HOME/.local/bin/obsidian"
    manual Obsidian 'Official ARM64 AppImage installed; test GUI. If AppArmor blocks Electron, seek a scoped IT-reviewed profile; do not disable sandbox/AppArmor.'
}
main() {
    component optional 'Ghostty and KeePassXC' desktop_install 'Native ARM64 packages from Ubuntu universe.'
    component optional Obsidian obsidian_install 'Pinned official ARM64 AppImage and FUSE library; no alternate package format.'
    manual 'Proton Mail' 'Unsupported for automatic ARM64 installation: official Linux .deb inspected is amd64 (1.14.0). Use the web app manually.'
}
