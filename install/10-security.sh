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
    # Prevent a newly installed outbound firewall from activating before rule review.
    # Preserve an existing deployment (including service state/rules).
    if ! package_installed opensnitch; then sudo systemctl mask opensnitch.service; fi
    apt_install opensnitch python3-opensnitch-ui opensnitch-ebpf-modules
    need_commands opensnitchd opensnitch-ui
    manual OpenSnitch 'Installed; new installations are masked until review. In a VM console, open the GUI, then sudo systemctl unmask opensnitch && sudo systemctl enable --now opensnitch. Review Docker/VPN/Tailscale/Mac LM Studio API rules.'
}
main() {
    component required AppArmor apparmor_check 'Verify enabled kernel module, profiles and active service; never disable enforcement.'
    component required 'Automatic security updates' updates_install 'Ubuntu unattended-upgrades and APT timers; preserve existing policy or fail on disabled updates.'
    component optional OpenSnitch opensnitch_install 'Official Ubuntu ARM64 packages; defer first activation to avoid disrupting connectivity.'
    manual 'Bitdefender GravityZone BEST' 'Ubuntu 26.04 ARM64 is supported by current BEST releases, but the endpoint installer is unique to the client. Obtain the approved Linux ARM64 kit from client IT; IT installs/enrolls it. No enrollment data or antivirus is stored here.'
}
