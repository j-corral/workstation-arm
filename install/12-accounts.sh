#!/usr/bin/env bash
# The initial Ubuntu account is renamed at the next boot, retaining its home.
# shellcheck source=lib/accounts.sh
source "$WS_ROOT/lib/accounts.sh"
schedule_rename() {
    local current=$1 daily=$2
    printf 'OLD_USER=%s\nNEW_USER=%s\n' "$current" "$daily" > "$WS_TMP/rename-daily-user.env"
    sudo install -d -m 0700 /etc/workstation /usr/local/lib/workstation
    sudo install -m 0600 "$WS_TMP/rename-daily-user.env" /etc/workstation/rename-daily-user.env
    sudo install -m 0755 "$WS_ROOT/tools/rename_daily_user.sh" /usr/local/lib/workstation/rename-daily-user.sh
    sudo install -m 0644 "$WS_ROOT/config/workstation-rename-daily-user.service" /etc/systemd/system/workstation-rename-daily-user.service
    sudo systemctl daemon-reload
    sudo systemctl enable workstation-rename-daily-user.service
}
accounts_harden() {
    local current daily
    current=$(id -un)
    daily=${WS_DAILY_ACCOUNT:-}
    [[ -n $daily ]] || { fail 'Account credentials were not configured during preflight.'; return 1; }
    [[ $(su - root -c 'id -u') == 0 ]] || { fail 'Could not verify root access; daily privileges were not changed.'; return 1; }
    getent group docker >/dev/null || { fail 'Docker must be installed before account configuration.'; return 1; }
    sudo usermod -aG docker "$current"
    printf '\nThe normal account keeps docker and lazydocker, then loses sudo.\n'
    # Install and enable the root-owned first-boot rename before revoking the
    # current account's sudo privilege.
    if [[ $daily != "$current" ]]; then schedule_rename "$current" "$daily"; fi
    sudo gpasswd -d "$current" sudo
    id -nG "$current" | tr ' ' '\n' | grep -qx sudo && { fail 'Could not remove the daily account from sudo.'; return 1; }
    printf '\nAccount configuration complete. Reboot now to apply the requested account name.\n'
}
main() { component required 'Root administrator and normal desktop account' accounts_harden 'Credentials were collected during preflight; retain Docker access, remove sudo and optionally rename at first boot.'; }
