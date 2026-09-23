#!/usr/bin/env bash
shell_install() {
    apt_install zsh direnv fzf zsh-syntax-highlighting
    [[ -z ${ZDOTDIR:-} || $ZDOTDIR == "$HOME" ]] || { fail 'Custom ZDOTDIR detected; integrate config/zshrc there manually.'; return 1; }
    [[ -r /usr/share/doc/fzf/examples/key-bindings.zsh && -r /usr/share/doc/fzf/examples/completion.zsh && -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] || {
        fail 'Ubuntu Zsh integration files missing; review the fzf or syntax-highlighting package layout before configuring shell.'; return 1;
    }
    managed_block "$HOME/.zshrc" shell "$WS_ROOT/config/zshrc"
    local shell_path
    shell_path=$(command -v zsh)
    if [[ $(getent passwd "$(workstation_user)" | cut -d: -f7) != "$shell_path" ]]; then
        grep -Fxq "$shell_path" /etc/shells
        sudo chsh -s "$shell_path" "$(workstation_user)"
    fi
    [[ $(getent passwd "$(workstation_user)" | cut -d: -f7) == "$shell_path" ]]
    manual Zsh 'Log out and back in. Review project .envrc/mise configuration before granting trust. mise itself is installed by runtimes.'
}
main() { component required Zsh shell_install 'Install Zsh, set login shell and merge one managed section with a current-directory prompt, syntax highlighting, direnv/mise and fzf hooks.'; }
