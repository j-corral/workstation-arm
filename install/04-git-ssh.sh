#!/usr/bin/env bash
git_install() {
    apt_install git openssh-client
    need_commands git ssh ssh-keygen ssh-agent ssh-add scp sftp
    [[ ! -L $HOME/.ssh && ! -L $HOME/.ssh/config ]] || { fail 'Refusing symlinked SSH directory/config.'; return 1; }
    install -d -m 0700 "$HOME/.ssh"
    if [[ ! -e $HOME/.ssh/config ]]; then install -m 0600 /dev/null "$HOME/.ssh/config"; fi
    chmod 0600 "$HOME/.ssh/config"
    manual 'Git/SSH' 'Create a dedicated passphrase-protected key manually.'
}
github_install() { apt_install gh; gh --version; manual GitHub 'Run gh auth login outside bootstrap logs.'; }
gitlab_install() { apt_install glab; glab --version; manual GitLab 'Run glab auth login outside bootstrap logs.'; }
main() {
    component required 'Git and SSH' git_install 'Ubuntu git and OpenSSH client; protect ~/.ssh, no keys.'
    if selected git_github; then component optional 'GitHub CLI' github_install 'Selected in configurator.'; else record SKIPPED 'GitHub CLI' 'Not selected in configurator.'; fi
    if selected git_gitlab; then component optional 'GitLab CLI' gitlab_install 'Selected in configurator.'; else record SKIPPED 'GitLab CLI' 'Not selected in configurator.'; fi
}
