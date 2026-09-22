#!/usr/bin/env bash
system_base() {
    apt_install build-essential ca-certificates curl wget git gnupg unzip zip lsof vim jq ripgrep bat fzf btop direnv zsh ncdu openssh-client
    need_commands cc make curl wget git gpg unzip zip lsof vim jq rg batcat fzf btop direnv zsh ncdu
}
main() { component required 'Base system' system_base 'Ubuntu build tools, CLI utilities and ncdu; no server daemons.'; }
