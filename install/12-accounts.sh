#!/usr/bin/env bash
# This module is deliberately opt-in: it changes who can administer the VM.
valid_account_name() {
    [[ $1 =~ ^[a-z_][a-z0-9_-]{0,30}$ && $1 != root ]]
}

accounts_harden() {
    local daily current answer group account
    local -a accounts
    [[ -t 0 && -t 1 ]] || { fail 'Account hardening needs an interactive terminal.'; return 1; }

    current=$(id -un)
    read -r -p "Normal desktop account [$current]: " answer
    daily=${answer:-$current}
    valid_account_name "$daily" || { fail 'Invalid daily account name.'; return 1; }
    if ! id "$daily" >/dev/null 2>&1; then
        log INFO "Creating the normal desktop account: $daily"
        sudo adduser --disabled-password --gecos '' "$daily"
        printf 'Choose a password for %s. It is used for the KDE session.\n' "$daily"
        sudo passwd "$daily"
    fi

    printf '\nroot is the dedicated administrator account. It is used only with su from a terminal.\n'
    printf 'Type ROOT to set or replace the root password: '
    read -r answer
    [[ $answer == ROOT ]] || { fail 'Account hardening cancelled; root remains unchanged.'; return 1; }
    sudo passwd root
    printf '\nVerify root now. Enter the new root password when requested.\n'
    [[ $(su - root -c 'id -u') == 0 ]] || { fail 'Could not verify root access; no daily-account privileges were removed.'; return 1; }

    printf '\nThis will remove sudo and Docker root-equivalent access from: %s' "$daily"
    [[ $current == "$daily" ]] || printf ', %s' "$current"
    printf '. Type REMOVE to continue: '
    read -r answer
    [[ $answer == REMOVE ]] || { fail 'Account hardening cancelled; no daily-account privileges were removed.'; return 1; }
    accounts=("$daily")
    [[ $current == "$daily" ]] || accounts+=("$current")
    for account in "${accounts[@]}"; do
        for group in sudo docker; do
            id -nG "$account" | tr ' ' '\n' | grep -qx "$group" || continue
            sudo gpasswd -d "$account" "$group"
            if id -nG "$account" | tr ' ' '\n' | grep -qx "$group"; then
                fail "Could not remove $account from the $group group."
                return 1
            fi
        done
    done
    printf '\nAccount hardening complete. Use: su - root\nRun administrative commands directly, then exit.\n'
}

main() {
    component required 'Root administrator and normal desktop account' accounts_harden 'Interactive, opt-in root activation and removal of daily sudo/Docker privileges.'
}
