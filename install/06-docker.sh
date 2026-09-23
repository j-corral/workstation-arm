#!/usr/bin/env bash
docker_check_systemd() {
    local units unit _state _rest command_line rc
    # A name-filtered list can return 1 when Docker is simply not installed.
    # List services first; distinguish absence from an actual systemctl failure.
    if units=$(systemctl list-unit-files --type=service --no-legend --no-pager); then
        while read -r unit _state _rest; do
            if [[ $unit == docker.service ]]; then
                command_line=$(systemctl show docker.service -p ExecStart --value)
                if [[ $command_line == *tcp://* ]]; then
                    fail 'Existing Docker systemd TCP listener found; review with IT.'
                    return 1
                fi
            fi
        done <<< "$units"
    else
        rc=$?
        log ERROR "Cannot inspect systemd service units (exit $rc); Docker installation stopped."
        return "$rc"
    fi
}
docker_install() {
    local conflict
    for conflict in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
        if package_installed "$conflict"; then fail "Docker conflict: $conflict is installed. Review/remove it yourself; no automatic destructive migration."; return 1; fi
    done
    # Refuse existing TCP listeners instead of starting an unsafe configuration.
    if [[ -e /etc/docker/daemon.json ]]; then
        sudo python3 - <<'PYTHON'
import json
with open('/etc/docker/daemon.json') as stream:
    settings = json.load(stream)
if any(str(host).startswith('tcp:') for host in settings.get('hosts', [])):
    raise SystemExit('Existing Docker TCP host configured; review with IT before continuing')
PYTHON
    fi
    docker_check_systemd
    repository docker https://download.docker.com/linux/ubuntu resolute stable https://download.docker.com/linux/ubuntu/gpg asc
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo systemctl is-active --quiet docker
    sudo docker --host unix:///var/run/docker.sock version
    docker compose version
    docker buildx version
    sudo usermod -aG docker "$(id -un)"
    id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker
    # shellcheck disable=SC2016 # Keep command substitutions for future Zsh sessions.
    managed_block "$HOME/.zshrc" docker-identity 'export DOCKER_UID="$(id -u)"
export DOCKER_GID="$(id -g)"'
    log WARN 'The daily developer account was added to docker for Docker CLI/lazydocker. Docker group membership is root-equivalent; log out and back in before using the socket without sudo.'
    manual Docker 'Run ./verify.sh --docker-hello for an explicit network test. Docker may publish containers beyond UFW rules; bind development ports to loopback.'
}
lazydocker_install() { install_binary_archive lazydocker lazydocker lazydocker; }
main() {
    component required Docker docker_install 'Official signed ARM64 Docker APT feed; Engine, CLI, containerd, Compose and Buildx; Unix socket only.'
    component optional lazydocker lazydocker_install 'Pinned official ARM64 TUI archive; does not alter Docker access permissions.'
}
