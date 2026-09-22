#!/usr/bin/env bash
git_install() {
    apt_install git openssh-client gh glab
    need_commands git ssh ssh-keygen ssh-agent ssh-add scp sftp gh glab
    [[ ! -L $HOME/.ssh && ! -L $HOME/.ssh/config ]] || { fail 'Refusing symlinked SSH directory/config.'; return 1; }
    install -d -m 0700 "$HOME/.ssh"
    if [[ ! -e $HOME/.ssh/config ]]; then install -m 0600 /dev/null "$HOME/.ssh/config"; fi
    chmod 0600 "$HOME/.ssh/config"
    gh --version
    glab --version
    manual 'Git/SSH' 'Create a dedicated passphrase-protected key manually; run gh auth login and glab auth login outside bootstrap logs.'
}
main() { component required 'Git and SSH' git_install 'Ubuntu git, OpenSSH client, gh and glab; protect ~/.ssh, no keys or authentication.'; }
