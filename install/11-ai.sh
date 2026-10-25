#!/usr/bin/env bash
# Host inference needs only an HTTP client in the VM. LM Studio and models run
# on macOS; network address/authentication are configured interactively.
codex_install() {
    local config_state
    if ! command -v codex >/dev/null; then
        download https://chatgpt.com/codex/install.sh "$WS_TMP/codex-install.sh"
        CODEX_NON_INTERACTIVE=1 sh "$WS_TMP/codex-install.sh"
    fi
    need_commands codex
    codex --version
    config_state=$(ensure_codex_lmstudio_config)
    if [[ $config_state == created ]]; then
        manual 'Codex CLI' 'Created ~/.codex/config.toml for the Mac LM Studio endpoint. Launch codex in a project and sign in interactively; no API key is stored.'
    else
        manual 'Codex CLI' 'Existing ~/.codex/config.toml retained; launch codex in a project and sign in interactively.'
    fi
}
claude_install() {
    repository claude-code https://downloads.claude.ai/claude-code/apt/stable stable main https://downloads.claude.ai/keys/claude-code.asc asc 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
    apt_install claude-code
    need_commands claude
    claude --version
    manual 'Claude Code' 'Launch claude in a project and authenticate interactively. No account or API key is configured by bootstrap.'
}
main() {
    if selected ai_codex; then component optional 'Codex CLI' codex_install 'Selected official CLI.'; else record SKIPPED 'Codex CLI' 'Not selected in configurator.'; fi
    if selected ai_claude; then component optional 'Claude Code' claude_install 'Selected official CLI.'; else record SKIPPED 'Claude Code' 'Not selected in configurator.'; fi
    record SKIPPED 'Guest inference runtime' 'LM Studio and all models stay on macOS; no guest daemon or model download is needed for HTTP API access.'
    manual 'Mac LM Studio API' 'On macOS, start the LM Studio server with Serve on Local Network and authentication. Use the Mac address reachable from Parallels in guest applications; verify with ./verify.sh --lm-host http://HOST_IP:1234.'
}
