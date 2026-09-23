#!/usr/bin/env bash
# This module is deliberately opt-in: it changes who can administer the VM.
valid_account_name() {
    [[ $1 =~ ^[a-z_][a-z0-9_-]{0,30}$ && $1 != root ]]
}

accounts_harden() {
    local daily current answer account
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

    getent group docker >/dev/null || { fail 'Docker must be installed before account separation, so the daily account can be granted its development access.'; return 1; }
    sudo usermod -aG docker "$daily"
    id -nG "$daily" | tr ' ' '\n' | grep -qx docker || { fail "Could not add $daily to the docker group."; return 1; }

    printf '\nThis will remove sudo access from: %s' "$daily"
    [[ $current == "$daily" ]] || printf ', %s (and remove its Docker access)' "$current"
    printf '. %s keeps Docker access for Docker CLI and lazydocker; this group is root-equivalent. Type REMOVE to continue: ' "$daily"
    read -r answer
    [[ $answer == REMOVE ]] || { fail 'Account hardening cancelled; no daily-account privileges were removed.'; return 1; }
    accounts=("$daily")
    [[ $current == "$daily" ]] || accounts+=("$current")
    for account in "${accounts[@]}"; do
        if id -nG "$account" | tr ' ' '\n' | grep -qx sudo; then
            sudo gpasswd -d "$account" sudo
            if id -nG "$account" | tr ' ' '\n' | grep -qx sudo; then
                fail "Could not remove $account from the sudo group."
                return 1
            fi
        fi
        if [[ $account != "$daily" ]] && id -nG "$account" | tr ' ' '\n' | grep -qx docker; then
            sudo gpasswd -d "$account" docker
        fi
    done
    printf '\nAccount hardening complete. %s can use Docker/lazydocker after a full logout and login.\nUse: su - root for other administrative commands, then exit.\n' "$daily"
}

main() {
    component required 'Root administrator and normal desktop account' accounts_harden 'Interactive, opt-in root activation; daily account keeps Docker development access but loses sudo.'
}
