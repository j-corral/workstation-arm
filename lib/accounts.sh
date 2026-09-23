#!/usr/bin/env bash
# Account credentials are collected before installation; no secret is persisted.
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
prepare_login_keyboard() {
    apt_install keyboard-configuration console-setup
    need_commands setupcon
    sudo python3 "$WS_ROOT/tools/keyboard_config.py" /etc/default/keyboard
    sudo setupcon
    if [[ ${XDG_SESSION_TYPE:-} == x11 ]] && command -v setxkbmap >/dev/null 2>&1; then
        setxkbmap -layout fr -model pc105
    fi
}
configure_login_credentials() {
    local current daily
    [[ -t 0 && -t 1 ]] || { fail 'Account configuration needs an interactive terminal.'; return 1; }
    prepare_login_keyboard
    if account_tui_available; then
        whiptail --title 'Login keyboard' --msgbox 'Current keyboard: French PC (fr/pc105). NumLock will be enabled for the future Plasma login screen.' 10 78
    else
        printf '\nCurrent keyboard: French PC (fr/pc105).\n'
    fi
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
    set_login_password root 'Root administrator password'
    set_login_password "$current" 'Normal desktop password'
    WS_DAILY_ACCOUNT=$daily
    export WS_DAILY_ACCOUNT
}
