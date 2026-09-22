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
    need_commands resolvectl
    bash "$WS_ROOT/tools/install_quad9_dot.sh" "$WS_ROOT/config/quad9-resolved.conf"
    manual 'Quad9 Secure DoT' 'Confirm VPN private DNS and browser DNS settings after connecting the client VPN. Quad9 filters malicious domains; it does not provide child protection or ad blocking.'
}
main() {
    component optional Tailscale tailscale_install 'Official signed resolute ARM64 repository; daemon starts but does not join a tailnet.'
    manual 'Proton VPN' 'ARM64 packages exist, but official support requires GNOME; this Plasma workstation needs manual IT-reviewed setup. No login or routing changes.'
    component optional 'Quad9 Secure DoT' quad9_dot_install 'System-level authenticated DNS-over-TLS with Quad9 threat blocking.'
}
