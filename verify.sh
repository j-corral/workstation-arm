#!/usr/bin/env bash
set -uo pipefail
# Read-only by default. Explicit network tests are opt-in and never logged to disk.
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_GENERATE_ASPNET_CERTIFICATE=false
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.lmstudio/bin:/usr/sbin:$PATH"
hello=0 link=0 quad9=0 dns_status=0 lm_host='' failures=0
while (( $# )); do
    case $1 in
        --docker-hello) hello=1 ;;
        --quad9) quad9=1 ;;
        --dns-status) dns_status=1 ;;
        --lm-link) link=1 ;;
        --lm-host) [[ $# -ge 2 ]] || { printf 'Missing URL after --lm-host\n' >&2; exit 2; }; lm_host=$2; shift ;;
        --help|-h) printf 'Usage: ./verify.sh [--dns-status] [--docker-hello] [--quad9] [--lm-host http://HOST:1234] [--lm-link]\nDefault: local checks, no downloads, authentication or sudo prompt.\n'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done
ok() { printf '✓ %s: %s\n' "$1" "${2:-installed}"; }
manual() { printf '○ %s: %s\n' "$1" "$2"; }
warn() { printf '⚠ %s: %s\n' "$1" "$2"; }
bad() { printf '✗ %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }
section() { printf '\n%s\n' "$1"; }
command_check() {
    local importance=$1 label=$2 executable=$3
    if command -v "$executable" >/dev/null; then ok "$label" 'executable found';
    elif [[ $importance == required ]]; then bad "$label" 'not installed/on PATH';
    else warn "$label" 'unsupported/not installed/on PATH'; fi
}
package_check() {
    local label=$1 package=$2
    if command -v dpkg-query >/dev/null && [[ $(dpkg-query -W -f='${Status}' "$package" 2>/dev/null) == 'install ok installed' ]]; then
        local architecture
        architecture=$(dpkg-query -W -f='${Architecture}' "$package")
        if [[ $architecture == arm64 || $architecture == all ]]; then ok "$label" 'native package installed; GUI not tested';
        else bad "$label" "foreign package architecture: $architecture"; fi
    else warn "$label" 'not installed'; fi
}
probe() {
    local label=$1; shift
    if timeout 30 "$@" >/dev/null 2>&1; then ok "$label" 'command check passed'; else bad "$label" 'command failed or timed out'; fi
}
section SYSTEM
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 26.04 ]]; then ok 'Ubuntu 26.04'; else bad OS 'requires Ubuntu 26.04'; fi
else bad OS 'not a Linux target'; fi
if [[ $(uname -m) == aarch64 ]] && command -v dpkg >/dev/null && [[ $(dpkg --print-architecture) == arm64 ]]; then ok ARM64; else bad ARM64 'native aarch64/arm64 required'; fi
command_check required 'KDE Plasma' plasmashell
manual 'Wayland/X11 session' "Current session: ${XDG_SESSION_TYPE:-unknown}; desktop: ${XDG_CURRENT_DESKTOP:-unknown}. Test graphics interactively."
if [[ -r /sys/module/apparmor/parameters/enabled ]] && [[ $(cat /sys/module/apparmor/parameters/enabled) == Y ]]; then
    ok AppArmor 'kernel enforcement available'
    if command -v sudo >/dev/null && sudo -n aa-status >/dev/null 2>&1; then ok 'AppArmor profiles' 'aa-status succeeded'; else manual 'AppArmor profiles' 'Run sudo aa-status to inspect loaded/enforcing profiles'; fi
else bad AppArmor 'not enabled or status unavailable'; fi
if command -v apt-config >/dev/null && command -v systemctl >/dev/null; then
    apt_state=$(apt-config dump)
    if grep -q 'APT::Periodic::Update-Package-Lists "1";' <<< "$apt_state" &&
       grep -q 'APT::Periodic::Unattended-Upgrade "1";' <<< "$apt_state" &&
       grep -Eq 'Unattended-Upgrade::(Allowed-Origins|Origins-Pattern)::.*security' <<< "$apt_state" &&
       systemctl is-active --quiet apt-daily.timer && systemctl is-active --quiet apt-daily-upgrade.timer; then
        ok 'Automatic updates' 'enabled with active APT timers'
    else bad 'Automatic updates' 'effective APT periodic settings/timers require review'; fi
fi
section CLI
for executable in git ssh ssh-keygen ssh-agent ssh-add scp sftp vim curl wget jq rg fzf btop direnv mise zsh; do
    command_check required "$executable" "$executable"
done
if command -v bat >/dev/null; then ok bat; else command_check required 'bat (Ubuntu batcat)' batcat; fi
section RUNTIMES
for executable in python3 uv bun dotnet; do
    command_check required "$executable" "$executable"
    if command -v "$executable" >/dev/null && command -v timeout >/dev/null; then probe "$executable version" "$executable" --version; fi
done
if command -v dotnet >/dev/null && command -v timeout >/dev/null; then
    probe 'dotnet --info' dotnet --info
    if timeout 30 dotnet --list-sdks | grep -q '^10\.'; then ok '.NET 10 SDK'; else bad '.NET 10 SDK' '10.x SDK missing'; fi
fi
section CONTAINERS
command_check required docker docker
if command -v docker >/dev/null && command -v timeout >/dev/null; then
    probe 'docker compose' docker compose version
    probe 'docker buildx' docker buildx version
    # Avoid environment-supplied remote contexts and DOCKER_HOST.
    if timeout 30 docker --host unix:///var/run/docker.sock version >/dev/null 2>&1; then ok 'Docker client/server';
    elif command -v sudo >/dev/null && sudo -n timeout 30 docker --host unix:///var/run/docker.sock version >/dev/null 2>&1; then ok 'Docker client/server' 'available via sudo';
    else manual Docker 'Run sudo docker --host unix:///var/run/docker.sock version; permission or daemon state unresolved'; fi
fi
command_check optional lazydocker lazydocker
if (( hello )); then
    printf 'Explicit test: pull/run official hello-world for linux/arm64; --rm removes the test container, image remains cached.\n'
    if sudo timeout 180 docker --host unix:///var/run/docker.sock run --rm --network none --platform linux/arm64 hello-world; then
        ok 'Docker hello-world' 'ARM64 execution passed'
    else bad 'Docker hello-world' 'network pull, permissions or daemon execution failed'; fi
else manual 'Docker hello-world' 'Opt in with ./verify.sh --docker-hello'; fi
section 'GIT SERVICES'
command_check required gh gh
command_check required glab glab
manual 'GitHub/GitLab authentication' 'gh auth login / glab auth login; authentication state intentionally not queried'
section DEVELOPMENT
command_check optional Zed zed
manual 'Zed graphics' 'Zed requires a compatible Vulkan GPU. Run vulkaninfo --summary and vkcube in Plasma; use VS Code if the virtual GPU is unsupported.'
command_check optional 'Visual Studio Code' code
command_check optional 'JetBrains Toolbox' jetbrains-toolbox
package_check Bruno bruno
manual 'GUI compatibility' 'Open installed applications inside Plasma; command/package presence does not prove rendering or sandbox compatibility'
section DESKTOP
command_check optional Konsole konsole
command_check optional 'Foot (Wayland alternative)' foot
command_check optional KeePassXC keepassxc
package_check 'KWallet Manager' kwalletmanager
if command -v flatpak >/dev/null && flatpak info --user md.obsidian.Obsidian >/dev/null 2>&1 && [[ $(flatpak info --user --show-ref md.obsidian.Obsidian) == app/md.obsidian.Obsidian/aarch64/stable ]]; then
    ok Obsidian 'aarch64 Flatpak installed; GUI/vault access not tested'
else warn Obsidian 'aarch64 Flatpak not installed for this user'; fi
package_check ONLYOFFICE onlyoffice-desktopeditors
package_check Solaar solaar
if command -v flatpak >/dev/null && flatpak info --user com.bitwarden.desktop >/dev/null 2>&1; then
    bitwarden_ref=$(flatpak info --user --show-ref com.bitwarden.desktop)
    if [[ $bitwarden_ref == app/com.bitwarden.desktop/aarch64/stable ]]; then ok Bitwarden 'aarch64 Flatpak installed; GUI/login not tested';
    else bad Bitwarden "unexpected Flatpak ref: $bitwarden_ref"; fi
else warn Bitwarden 'aarch64 Flatpak not installed for this user'; fi
manual 'Logitech devices' 'Attach receiver to the guest or pair over Bluetooth, then run solaar show.'
package_check 'Proton Mail (automatic ARM64 install unsupported)' proton-mail
section NETWORK
if (( dns_status )); then bash "$(dirname -- "$0")/tools/dns_status.sh"; fi
if [[ -f /etc/systemd/resolved.conf.d/70-workstation-adguard.conf ]]; then
    if cmp -s /etc/systemd/resolved.conf.d/70-workstation-adguard.conf "$(dirname -- "$0")/config/adguard-resolved.conf"; then
        ok 'AdGuard Home + Quad9' 'managed local resolver configuration present; use --dns-status for live diagnostic'
    else bad 'AdGuard Home + Quad9' 'managed resolver configuration differs'; fi
else
if [[ -f /etc/systemd/resolved.conf.d/60-workstation-quad9.conf ]]; then
    if cmp -s /etc/systemd/resolved.conf.d/60-workstation-quad9.conf "$(dirname -- "$0")/config/quad9-resolved.conf"; then
        ok 'Quad9 Secure DoT' 'managed systemd-resolved configuration present; use --quad9 for a live check'
    else bad 'Quad9 Secure DoT' 'managed resolver configuration differs from repository'; fi
else warn 'Quad9 Secure DoT' 'not configured'; fi
fi
if [[ -f $HOME/.local/share/applications/workstation-adguard-home.desktop ]]; then ok 'AdGuard Home launcher' 'opens loopback-only dashboard'; else warn 'AdGuard Home launcher' 'absent'; fi
if (( quad9 )); then
    if command -v resolvectl >/dev/null && timeout 15 resolvectl query -t TXT proto.on.quad9.net 2>/dev/null | grep -Eq '(^|[^a-z])dot\.'; then
        ok 'Quad9 live protocol' 'Quad9 reports DNS-over-TLS'
    else bad 'Quad9 live protocol' 'Quad9 did not report DNS-over-TLS'; fi
fi
command_check optional Tailscale tailscale
package_check 'Proton VPN (KDE setup manual)' proton-vpn-gnome-desktop
command_check optional OpenSnitch opensnitchd
command_check optional 'OpenSnitch UI' opensnitch-ui
if command -v systemctl >/dev/null; then
    for service in tailscaled opensnitch; do
        if systemctl is-active --quiet "$service"; then ok "$service service" active; else manual "$service service" 'inactive/not installed; OpenSnitch first activation is deliberately deferred'; fi
    done
fi
manual 'Network enrollment/rules' 'Authenticate only with client approval; review VPN/Tailscale/client VPN coexistence and OpenSnitch rules'
manual 'Bitdefender GravityZone BEST' 'Client IT must supply/install/enroll its private Linux ARM64 kit; check systemctl status bdsec* after installation.'
section AI
command_check optional 'Codex CLI' codex
command_check optional 'Claude Code' claude
if [[ -n $lm_host ]]; then
    if [[ ! $lm_host =~ ^https?://[A-Za-z0-9.:-]+$ ]]; then
        bad 'Mac LM Studio API' 'Use http://HOST:PORT or https://HOST:PORT without credentials/path'
    else
        lm_status=$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 5 --max-time 10 "$lm_host/v1/models") || lm_status=000
        case $lm_status in
            200) ok 'Mac LM Studio API' 'model-list endpoint reachable; host inference still needs a live request' ;;
            401|403) ok 'Mac LM Studio API' 'server reachable and authentication required; provide token only to your chosen client' ;;
            *) bad 'Mac LM Studio API' "HTTP $lm_status; check Mac server, host address, firewall and authentication" ;;
        esac
    fi
else manual 'Mac LM Studio API' 'Use ./verify.sh --lm-host http://HOST_IP:1234 after enabling the server on macOS'; fi
manual 'Guest LM Studio runtime' 'Not required for macOS host inference via HTTP API.'
# Legacy LM Link status remains available for users who already installed lms.
command_check optional lms lms
# llmster is normally managed under ~/.lmstudio, not exposed as a PATH command.
if command -v llmster >/dev/null; then ok llmster 'executable found; daemon not started';
elif [[ -d $HOME/.lmstudio/llmster ]] && [[ -n $(find "$HOME/.lmstudio/llmster" -type f -name llmster -perm -u+x -print -quit) ]]; then
    ok llmster 'managed executable found; daemon not started'
else manual llmster 'Not required for the macOS LM Studio HTTP API; see docs/compatibility.md'; fi
if (( link )); then
    if command -v lms >/dev/null; then
        printf 'Read-only LM Link status (may include peer/device names; not saved):\n'
        if timeout 30 lms link status; then manual 'LM Link' 'Status command succeeded. Confirm macOS peer is connected and test host inference manually; exit zero alone is not pairing proof';
        else bad 'LM Link' 'Status failed; pair/login manually or check daemon/VPN connectivity'; fi
    else bad 'LM Link' 'lms not installed'; fi
else manual 'LM Link' 'After pairing: ./verify.sh --lm-link; no model loading/download in verification'; fi
printf '\nRequired/operational failures: %s. Manual and optional gaps are shown separately.\n' "$failures"
(( failures == 0 ))
