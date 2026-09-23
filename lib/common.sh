#!/usr/bin/env bash
# Infrastructure shared by modules. Policy/order remain in bootstrap.sh and modules.
# shellcheck source=lib/logging.sh
source "$WS_ROOT/lib/logging.sh"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.lmstudio/bin:/usr/sbin:$PATH"
fail() { log ERROR "$*"; return 1; }
workstation_user() { printf '%s' "${WS_AS_USER:-$(id -un)}"; }
as_workstation_user() {
    local runtime_dir
    if [[ -n ${WS_AS_USER:-} ]]; then
        runtime_dir="/run/user/$(id -u "$WS_AS_USER")"
        runuser -u "$WS_AS_USER" -- env HOME="$HOME" XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}" XDG_RUNTIME_DIR="$runtime_dir" "$@"
    else
        "$@"
    fi
}
apt_wait_for_locks() {
    local deadline=$((SECONDS + 300))
    command -v fuser >/dev/null 2>&1 || return
    while sudo fuser -s /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock /var/lib/apt/lists/lock; do
        if (( SECONDS >= deadline )); then
            fail 'APT is still busy after five minutes; wait for the other package operation to finish, then rerun bootstrap.'
            return 1
        fi
        log WARN 'APT is busy with another package operation; waiting before continuing.'
        sleep 5
    done
}
apt_update() {
    apt_wait_for_locks
    sudo apt-get -o DPkg::Lock::Timeout=300 -o APT::Update::Error-Mode=any update
}
package_installed() { [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]; }
apt_install() {
    local package architecture candidate
    for package in "$@"; do
        candidate=$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}')
        [[ -n $candidate && $candidate != '(none)' ]] || { fail "No signed APT candidate for $package; check Ubuntu universe and source configuration."; return 1; }
        architecture=$(apt-cache show "$package=$candidate" | awk '/^Architecture:/ {value=$2} END {print value}')
        [[ $architecture == arm64 || $architecture == all ]] || { fail "Rejected $package architecture: $architecture"; return 1; }
    done
    apt_wait_for_locks
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 --no-remove --no-install-recommends install -y "$@"
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
    local scope=${1:-all} config="$HOME/.config/workstation/components.conf" areas='' choices='' tag
    [[ $scope == accounts ]] && return
    [[ -f $config && ${WS_CONFIGURE:-0} != 1 ]] && { WS_COMPONENTS=$config; export WS_COMPONENTS; return; }
    install -d -m 0700 "$(dirname "$config")"
    component_default() { [[ -f $config ]] && grep -qx "$1=1" "$config" && printf ON || printf OFF; }
    saved_value() { grep -E "^$1=" "$config" 2>/dev/null | tail -n 1 || printf '%s=0\n' "$1"; }
    category_default() {
        local prefix
        case $1 in desktop) prefix=desktop_ ;; ai) prefix=ai_ ;; git) prefix=git_ ;; esac
        [[ -f $config ]] && grep -Eq "^${prefix}.*=1$" "$config" && printf ON || printf OFF
    }
    if [[ -t 0 && -t 1 ]] && command -v whiptail >/dev/null; then
        if [[ $scope == all ]]; then
            whiptail --title 'Mandatory workstation plan' --msgbox 'These steps always run:\n\n• Base Ubuntu tooling and signed package updates\n• KDE Plasma, SDDM, French PC keyboard (fr/pc105) and NumLock\n• Zsh, Git and SSH baseline, Python, mise, uv, Bun and .NET\n• Docker Engine and developer Docker access\n• AppArmor and automatic security updates\n• Network protections configured by this workstation\n• Root password, normal desktop account password, then sudo removal\n\nThe next screens select only additional desktop, AI and Git-service tools.' 22 78
            if ! areas=$(whiptail --title 'Optional areas' --separate-output --checklist 'Choose optional areas' 18 78 8 desktop 'Desktop applications' "$(category_default desktop)" ai 'AI command-line tools' "$(category_default ai)" git 'Git service command-line tools' "$(category_default git)" 3>&1 1>&2 2>&3); then
                [[ -f $config ]] && { WS_COMPONENTS=$config; export WS_COMPONENTS; unset -f component_default category_default; return; }
                fail 'Configurator cancelled before an initial selection.'; return 1
            fi
        else
            areas=$scope
        fi
        if grep -Fqx desktop <<< "$areas"; then
            choices+=$(whiptail --title 'Desktop applications' --separate-output --checklist 'Choose desktop applications' 20 78 10 desktop_onlyoffice 'ONLYOFFICE' "$(component_default desktop_onlyoffice)" desktop_obsidian 'Obsidian' "$(component_default desktop_obsidian)" desktop_bruno 'Bruno' "$(component_default desktop_bruno)" desktop_solaar 'Solaar (Logitech)' "$(component_default desktop_solaar)" desktop_bitwarden 'Bitwarden' "$(component_default desktop_bitwarden)" 3>&1 1>&2 2>&3) || { unset -f component_default category_default; return 1; }
        fi
        if grep -Fqx ai <<< "$areas"; then
            choices+=$'\n'$(whiptail --title 'AI tools' --separate-output --checklist 'Choose AI command-line tools' 16 78 6 ai_codex 'Codex CLI' "$(component_default ai_codex)" ai_claude 'Claude Code' "$(component_default ai_claude)" 3>&1 1>&2 2>&3) || { unset -f component_default category_default; return 1; }
        fi
        if grep -Fqx git <<< "$areas"; then
            choices+=$'\n'$(whiptail --title 'Git services' --separate-output --checklist 'Choose Git service command-line tools' 16 78 6 git_github 'GitHub CLI' "$(component_default git_github)" git_gitlab 'GitLab CLI' "$(component_default git_gitlab)" 3>&1 1>&2 2>&3) || { unset -f component_default category_default; return 1; }
        fi
    else
        areas=$'desktop\nai\ngit'
        choices=$'desktop_onlyoffice\ndesktop_obsidian\ndesktop_bruno\ndesktop_solaar\ndesktop_bitwarden\nai_codex\nai_claude\ngit_github\ngit_gitlab'
    fi
    {
        printf 'area_accounts=1\n'
        for tag in desktop ai git; do
            if [[ $scope != all && $tag != "$scope" && -f $config ]]; then saved_value "area_$tag"
            elif grep -Fqx "$tag" <<< "$areas"; then printf 'area_%s=1\n' "$tag"; else printf 'area_%s=0\n' "$tag"; fi
        done
        for tag in desktop_onlyoffice desktop_obsidian desktop_bruno desktop_solaar desktop_bitwarden ai_codex ai_claude git_github git_gitlab; do
            if [[ $scope != all && $tag != "${scope}_"* && -f $config ]]; then saved_value "$tag"
            elif tr -d '"' <<< "$choices" | grep -Fqx "$tag"; then printf '%s=1\n' "$tag"; else printf '%s=0\n' "$tag"; fi
        done
    } > "$config"
    chmod 0600 "$config"; WS_COMPONENTS=$config; export WS_COMPONENTS
    unset -f component_default saved_value category_default
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
