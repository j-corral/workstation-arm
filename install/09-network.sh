#!/usr/bin/env bash
tailscale_install() {
    repository tailscale https://pkgs.tailscale.com/stable/ubuntu resolute main https://pkgs.tailscale.com/stable/ubuntu/resolute.noarmor.gpg gpg
    apt_install tailscale
    sudo systemctl enable --now tailscaled
    sudo systemctl is-active --quiet tailscaled
    tailscale version
    manual Tailscale 'Only if authorized by client IT: sudo tailscale up --accept-routes=false --accept-dns=false. No authentication or routes configured by bootstrap.'
}
quad9_dot_install() {
    # Ubuntu 26.04 exposes dnsutils as a virtual package; bind9-dnsutils owns dig.
    apt_install bind9-dnsutils python3-yaml
    need_commands resolvectl dig ss ip
    locked_download adguard_home "$WS_TMP/adguard.tar.gz"
    extract_archive "$WS_TMP/adguard.tar.gz" "$WS_TMP/adguard"
    elf_arm64 "$WS_TMP/adguard/AdGuardHome/AdGuardHome"
    sudo bash "$WS_ROOT/tools/install_local_dns.sh" install "$WS_ROOT" "$WS_TMP/adguard/AdGuardHome/AdGuardHome"
    local directory="$HOME/.local/share/applications" launcher="$HOME/.local/share/applications/workstation-adguard-home.desktop"
    install -d -m 0755 "$directory"
    [[ ! -L $launcher ]] || { fail 'Refusing symlinked AdGuard Home launcher.'; return 1; }
    cat > "$WS_TMP/adguard-home.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=AdGuard Home (local)
Comment=Local DNS filtering dashboard
Exec=xdg-open http://127.0.0.1:3000/
Icon=network-server
Terminal=false
Categories=Settings;Network;
EOF
    install -m 0644 "$WS_TMP/adguard-home.desktop" "$launcher"
    manual 'VPN and browser DNS' 'Confirm client VPN split domains after connection. Disable third-party browser Secure DNS/DoH if it bypasses the system resolver.'
}
main() {
    component optional Tailscale tailscale_install 'Official signed resolute ARM64 repository; daemon starts but does not join a tailnet.'
    manual 'Proton VPN' 'ARM64 packages exist, but official support requires GNOME; this Plasma workstation needs manual IT-reviewed setup. No login or routing changes.'
    component optional 'Local AdGuard Home + Quad9 Secure DoT' quad9_dot_install 'Local ad/tracker filter, Quad9 threat protection and split-DNS-capable systemd-resolved.'
}
