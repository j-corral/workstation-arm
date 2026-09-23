#!/usr/bin/env bash
# Infrastructure shared by modules. Policy/order remain in bootstrap.sh and modules.
# shellcheck source=lib/logging.sh
source "$WS_ROOT/lib/logging.sh"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.lmstudio/bin:/usr/sbin:$PATH"
fail() { log ERROR "$*"; return 1; }
apt_update() { sudo apt-get -o APT::Update::Error-Mode=any update; }
package_installed() { [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]; }
apt_install() {
    local package architecture candidate
    for package in "$@"; do
        candidate=$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}')
        [[ -n $candidate && $candidate != '(none)' ]] || { fail "No signed APT candidate for $package; check Ubuntu universe and source configuration."; return 1; }
        architecture=$(apt-cache show "$package=$candidate" | awk '/^Architecture:/ {value=$2} END {print value}')
        [[ $architecture == arm64 || $architecture == all ]] || { fail "Rejected $package architecture: $architecture"; return 1; }
    done
    sudo env DEBIAN_FRONTEND=noninteractive apt-get --no-remove --no-install-recommends install -y "$@"
    for package in "$@"; do
        package_installed "$package" || return 1
        architecture=$(dpkg-query -W -f='${Architecture}' "$package")
        [[ $architecture == arm64 || $architecture == all ]] || { fail "Installed $package is not ARM64/all."; return 1; }
    done
}
need_commands() { local cmd; for cmd in "$@"; do command -v "$cmd" >/dev/null || { fail "Missing executable: $cmd"; return 1; }; done; }
download() {
    curl --fail --show-error --silent --location --proto '=https' --proto-redir '=https' \
        --tlsv1.2 --connect-timeout 20 --max-time 900 --retry 2 --output "$2" "$1"
    [[ -s $2 ]]
}
locked_download() {
    local id=$1 output=$2 url algorithm digest
    IFS=$'\t' read -r url algorithm digest < <(python3 "$WS_ROOT/tools/artifacts.py" lookup "$WS_ROOT/config/downloads.json" "$id")
    [[ $url == https://* && $digest =~ ^[a-f0-9]+$ ]] || { fail "Invalid download lock: $id"; return 1; }
    download "$url" "$output"
    if ! printf '%s  %s\n' "$digest" "$output" | "${algorithm}sum" --check --status; then
        fail "Checksum mismatch for $id; downloaded payload will not be executed."; return 1
    fi
}
elf_arm64() { python3 "$WS_ROOT/tools/artifacts.py" elf "$1"; }
extract_archive() { python3 "$WS_ROOT/tools/artifacts.py" extract "$1" "$2"; }
managed_block() { python3 "$WS_ROOT/tools/managed_block.py" "$1" "$2" "$3"; }
configure_optional_components() {
    local config="$HOME/.config/workstation/components.conf" choices tag
    [[ -f $config && ${WS_CONFIGURE:-0} != 1 ]] && { WS_COMPONENTS=$config; export WS_COMPONENTS; return; }
    install -d -m 0700 "$(dirname "$config")"
    if [[ -t 0 && -t 1 ]] && command -v whiptail >/dev/null; then
        choices=$(whiptail --title 'Workstation configuration' --checklist 'Select optional components' 20 78 10 \
          desktop_onlyoffice 'ONLYOFFICE' ON desktop_obsidian 'Obsidian' ON desktop_bruno 'Bruno' ON desktop_solaar 'Solaar' ON desktop_bitwarden 'Bitwarden' ON ai_codex 'Codex CLI' ON ai_claude 'Claude Code' ON git_github 'GitHub CLI' ON git_gitlab 'GitLab CLI' ON 3>&1 1>&2 2>&3) || choices=''
    else choices='desktop_onlyoffice desktop_obsidian desktop_bruno desktop_solaar desktop_bitwarden ai_codex ai_claude git_github git_gitlab'; fi
    for tag in desktop_onlyoffice desktop_obsidian desktop_bruno desktop_solaar desktop_bitwarden ai_codex ai_claude git_github git_gitlab; do
        if tr -d '"' <<< "$choices" | grep -Fqx "$tag"; then printf '%s=1\n' "$tag"; else printf '%s=0\n' "$tag"; fi
    done > "$config"
    chmod 0600 "$config"; WS_COMPONENTS=$config; export WS_COMPONENTS
}
selected() { [[ -f ${WS_COMPONENTS:-} ]] && grep -qx "$1=1" "$WS_COMPONENTS"; }
# Each action runs in a fresh Bash process: optional-error handling cannot disable
# errexit inside action functions (Bash's `if function` pitfall).
component() {
    local importance=$1 label=$2 action=$3 description=$4 rc
    if [[ $WS_DRY_RUN == 1 ]]; then record PLANNED "$label" "$description"; return; fi
    log START "$label — $description"
    if bash "$WS_ROOT/lib/runner.sh" "$WS_MODULE" "$action"; then
        record INSTALLED "$label" 'Present; component checks passed (GUI/pairing may remain manual).'
    else
        rc=$?
        record FAILED "$label" "Action failed (exit $rc); inspect terminal output."
        if [[ $importance == required ]]; then return "$rc"; fi
    fi
}
repository() {
    local name=$1 uri=$2 suite=$3 section=$4 key_url=$5
    local path="/etc/apt/sources.list.d/workstation-$1.list" key="/etc/apt/keyrings/workstation-$1.$6" existing fingerprint
    [[ ! -L $path && ! -L $key ]] || { fail "Refusing symlink repository/key for $name"; return 1; }
    install -d -m 0700 "$WS_TMP/gnupg"
    # Refuse ambiguous existing repositories; never overwrite an administrator's entry.
    while IFS= read -r existing; do
        [[ $existing == "$path" ]] || { fail "Existing $name repository in $existing; consolidate it before rerunning."; return 1; }
    done < <(grep -rlF -- "${uri#https://}" /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources 2>/dev/null || true)
    printf 'deb [arch=arm64 signed-by=%s] %s %s %s\n' "$key" "$uri" "$suite" "$section" > "$WS_TMP/source.list"
    if [[ -e $path ]] && ! cmp -s "$path" "$WS_TMP/source.list"; then
        fail "Managed repository $path was modified; reconcile it manually."; return 1
    fi
    if [[ ! -e $key ]]; then
        download "$key_url" "$WS_TMP/key"
        gpg --homedir "$WS_TMP/gnupg" --batch --show-keys "$WS_TMP/key" >/dev/null
        if [[ -n ${7:-} ]]; then
            fingerprint=$(gpg --homedir "$WS_TMP/gnupg" --batch --show-keys --with-colons "$WS_TMP/key" | awk -F: '$1 == "fpr" {print $10; exit}')
            [[ $fingerprint == "$7" ]] || { fail "Repository key fingerprint mismatch for $name."; return 1; }
        fi
        sudo install -d -m 0755 /etc/apt/keyrings
        sudo install -m 0644 "$WS_TMP/key" "$key"
    else
        gpg --homedir "$WS_TMP/gnupg" --batch --show-keys "$key" >/dev/null
        if [[ -n ${7:-} ]]; then
            fingerprint=$(gpg --homedir "$WS_TMP/gnupg" --batch --show-keys --with-colons "$key" | awk -F: '$1 == "fpr" {print $10; exit}')
            [[ $fingerprint == "$7" ]] || { fail "Repository key fingerprint mismatch for $name."; return 1; }
        fi
    fi
    sudo install -m 0644 "$WS_TMP/source.list" "$path"
    apt_update
}
install_binary_archive() {
    local id=$1 relative=$2 command_name=$3
    if command -v "$command_name" >/dev/null; then "$command_name" --version; return; fi
    locked_download "$id" "$WS_TMP/archive"
    extract_archive "$WS_TMP/archive" "$WS_TMP/extracted"
    elf_arm64 "$WS_TMP/extracted/$relative"
    install -d -m 0755 "$HOME/.local/bin"
    install -m 0755 "$WS_TMP/extracted/$relative" "$HOME/.local/bin/$command_name"
    "$HOME/.local/bin/$command_name" --version
}
