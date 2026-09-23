#!/usr/bin/env bash
# The initial Ubuntu account is renamed at the next boot, retaining its home.
valid_account_name() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,30}$ && $1 != root ]]; }
account_tui_available() { [[ -t 0 && -t 1 ]] && command -v whiptail >/dev/null 2>&1; }
prompt_daily_account() {
    local current=$1 answer
    if account_tui_available; then
        answer=$(whiptail --title 'Normal desktop account' --inputbox 'Choose the normal desktop account name. It will not have sudo access.' 10 78 "$current" 3>&1 1>&2 2>&3) || return 1
    else
        read -r -p "Normal desktop account [$current]: " answer
        answer=${answer:-$current}
    fi
    printf '%s' "$answer"
}
set_login_password() {
    local account=$1 title=$2 password confirmation
    if ! account_tui_available; then sudo passwd "$account"; return; fi
    password=$(whiptail --title "$title" --passwordbox "Set the password for $account." 10 78 3>&1 1>&2 2>&3) || return 1
    confirmation=$(whiptail --title "$title" --passwordbox "Confirm the password for $account." 10 78 3>&1 1>&2 2>&3) || { unset password; return 1; }
    if [[ -z $password || $password != "$confirmation" || $password == *:* || $password == *$'\n'* ]]; then
        unset password confirmation
        fail 'Passwords do not match, are empty, or contain an unsupported character.'
        return 1
    fi
    printf '%s:%s\n' "$account" "$password" | sudo chpasswd
    unset password confirmation
}
configure_password_keyboard() {
    # `--only accounts` must be safe too: configure the physical layout before
    # reading a secret, rather than depending on a previous KDE-module run.
    apt_install keyboard-configuration console-setup
    need_commands setupcon
    sudo python3 "$WS_ROOT/tools/keyboard_config.py" /etc/default/keyboard
    sudo setupcon
    if [[ ${XDG_SESSION_TYPE:-} == x11 ]] && command -v setxkbmap >/dev/null 2>&1; then
        setxkbmap -layout fr -model pc105
    fi
}
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
    local current daily answer
    [[ -t 0 && -t 1 ]] || { fail 'Account configuration needs an interactive terminal.'; return 1; }
    current=$(id -un)
    daily=$(prompt_daily_account "$current") || { fail 'Account configuration cancelled.'; return 1; }
    valid_account_name "$daily" || { fail 'Invalid daily account name.'; return 1; }
    if [[ $daily != "$current" ]]; then
        id "$daily" >/dev/null 2>&1 && { fail "Target account already exists: $daily. Reset or remove it before provisioning a fresh VM."; return 1; }
        if account_tui_available; then
            whiptail --title 'Confirm account rename' --yesno "The current account $current will be renamed to $daily at the next reboot." 10 78 || { fail 'Account rename cancelled.'; return 1; }
        else
            printf 'The current account %s will be renamed to %s at the next reboot. Type RENAME to continue: ' "$current" "$daily"
            read -r answer
            [[ $answer == RENAME ]] || { fail 'Account rename cancelled.'; return 1; }
        fi
    fi
    configure_password_keyboard
    printf '\nFrench PC AZERTY (fr/pc105) is configured. Set the root password now.\n'
    set_login_password root 'Root administrator password'
    set_login_password "$current" 'Normal desktop password'
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
main() { component required 'Root administrator and normal desktop account' accounts_harden 'Interactive root activation, Docker access, sudo removal and optional first-boot account rename.'; }
