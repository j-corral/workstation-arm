#!/usr/bin/env bash
python_install() { apt_install python3 python3-venv; python3 --version; }
mise_install() { install_binary_archive mise mise/bin/mise mise; }
uv_install() {
    if command -v uv >/dev/null; then uv --version; return; fi
    locked_download uv "$WS_TMP/archive"
    extract_archive "$WS_TMP/archive" "$WS_TMP/extracted"
    install -d -m 0755 "$HOME/.local/bin"
    local binary
    for binary in uv uvx; do
        elf_arm64 "$WS_TMP/extracted/uv-aarch64-unknown-linux-gnu/$binary"
        install -m 0755 "$WS_TMP/extracted/uv-aarch64-unknown-linux-gnu/$binary" "$HOME/.local/bin/$binary"
    done
    uv --version
}
bun_install() {
    install_binary_archive bun bun-linux-aarch64/bun bun
    install -d -m 0755 "$HOME/.local/bin"
    if [[ ! -e $HOME/.local/bin/bunx && ! -L $HOME/.local/bin/bunx ]]; then
        ln -s "$(command -v bun)" "$HOME/.local/bin/bunx"
    fi
}
dotnet_install() {
    apt_install dotnet-sdk-10.0
    dotnet --info
    dotnet --list-sdks | grep -q '^10\.'
}
main() {
    component required 'System Python' python_install 'Ubuntu python3 and venv; preserve system Python.'
    component required mise mise_install 'Pinned official Linux ARM64 single binary; no toolchains downloaded.'
    component required uv uv_install 'Pinned official ARM64 uv/uvx binaries; no Python downloads.'
    component required Bun bun_install 'Pinned official Linux aarch64 Bun binary; no global Node.js.'
    component required '.NET 10 SDK' dotnet_install 'Ubuntu dotnet-sdk-10.0; verify dotnet --info and SDK major.'
}
