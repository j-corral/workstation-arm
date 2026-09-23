#!/usr/bin/env bash
apparmor_check() {
    apt_install apparmor apparmor-utils
    [[ $(cat /sys/module/apparmor/parameters/enabled) == Y ]]
    sudo aa-status
    sudo systemctl is-active --quiet apparmor
}
updates_install() {
    apt_install unattended-upgrades
    # Preserve pre-existing policy; refuse a conflicting local file.
    local target=/etc/apt/apt.conf.d/20auto-upgrades
    if [[ -e $target ]] && ! cmp -s "$target" "$WS_ROOT/config/20auto-upgrades"; then
        local config
        config=$(apt-config dump)
        grep -q 'APT::Periodic::Update-Package-Lists "1";' <<< "$config"
        grep -q 'APT::Periodic::Unattended-Upgrade "1";' <<< "$config"
    else
        sudo install -m 0644 "$WS_ROOT/config/20auto-upgrades" "$target"
    fi
    # Check effective configuration, including later administrator overrides.
    local effective
    effective=$(apt-config dump)
    grep -q 'APT::Periodic::Update-Package-Lists "1";' <<< "$effective"
    grep -q 'APT::Periodic::Unattended-Upgrade "1";' <<< "$effective"
    grep -Eq 'Unattended-Upgrade::(Allowed-Origins|Origins-Pattern)::.*security' <<< "$effective" || {
        fail 'No security origin found in effective unattended-upgrades configuration; review with IT.'; return 1;
    }
    sudo systemctl enable --now apt-daily.timer apt-daily-upgrade.timer
    systemctl is-active --quiet apt-daily.timer
    systemctl is-active --quiet apt-daily-upgrade.timer
    manual Updates 'Review /etc/apt/apt.conf.d/50unattended-upgrades security origins with IT; third-party feeds are not automatically opted in.'
}
opensnitch_install() {
    apt_install opensnitch python3-opensnitch-ui opensnitch-ebpf-modules
    need_commands opensnitchd opensnitch-ui
    # Earlier bootstrap versions masked opensnitch.service. Remove that stale
    # mask and detect the unit installed by the current Ubuntu package instead
    # of assuming whether it is named opensnitch or opensnitchd.
    local candidate service=''
    for candidate in opensnitch.service opensnitchd.service; do
        sudo systemctl unmask "$candidate" >/dev/null 2>&1 || true
        if systemctl list-unit-files --type=service --all --no-legend "$candidate" 2>/dev/null | grep -Eq "^${candidate//./\\.}[[:space:]]"; then
            service=$candidate
            break
        fi
    done
    [[ -n $service ]] || { fail 'OpenSnitch installed without a recognized systemd service.'; return 1; }
    sudo systemctl enable --now "$service"
    systemctl is-active --quiet "$service" || { fail "OpenSnitch service $service did not start; run sudo journalctl -u $service -b --no-pager."; return 1; }

    # OpenSnitch upstream documents xcb as the stable UI backend when Wayland
    # rule dialogs misbehave. The wrapper keeps the daemon system-wide and the
    # UI in the normal desktop account.
    install -d -m 0755 "$HOME/.local/bin"
    cat > "$WS_TMP/workstation-opensnitch-ui" <<'EOF'
#!/usr/bin/env bash
exec env QT_QPA_PLATFORM=xcb /usr/bin/opensnitch-ui "$@"
EOF
    install -m 0755 "$WS_TMP/workstation-opensnitch-ui" "$HOME/.local/bin/workstation-opensnitch-ui"
    python3 "$WS_ROOT/tools/desktop_entry.py" opensnitch OpenSnitch "$HOME/.local/bin/workstation-opensnitch-ui" /usr/share/icons/hicolor/scalable/apps/opensnitch-ui.svg
    manual OpenSnitch "Active through $service. Open the Workstation launcher once after login and review specific rules for Docker, Tailscale, VPNs and the Mac LM Studio API; do not create a blanket allow rule."
}
main() {
    component required AppArmor apparmor_check 'Verify enabled kernel module, profiles and active service; never disable enforcement.'
    component required 'Automatic security updates' updates_install 'Ubuntu unattended-upgrades and APT timers; preserve existing policy or fail on disabled updates.'
    component optional OpenSnitch opensnitch_install 'Official Ubuntu ARM64 packages; defer first activation to avoid disrupting connectivity.'
    manual 'Bitdefender GravityZone BEST' 'Ubuntu 26.04 ARM64 is supported by current BEST releases, but the endpoint installer is unique to the client. Obtain the approved Linux ARM64 kit from client IT; IT installs/enrolls it. No enrollment data or antivirus is stored here.'
}
