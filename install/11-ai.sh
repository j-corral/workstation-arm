#!/usr/bin/env bash
# Host inference needs only an HTTP client in the VM. LM Studio and models run
# on macOS; network address/authentication are configured interactively.
codex_install() {
    if ! command -v codex >/dev/null; then
        download https://chatgpt.com/codex/install.sh "$WS_TMP/codex-install.sh"
        CODEX_NON_INTERACTIVE=1 sh "$WS_TMP/codex-install.sh"
    fi
    need_commands codex
    codex --version
    manual 'Codex CLI' 'Launch codex in a project and sign in interactively. No account or API key is configured by bootstrap.'
}
claude_install() {
    repository claude-code https://downloads.claude.ai/claude-code/apt/stable stable main https://downloads.claude.ai/keys/claude-code.asc asc 31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
    apt_install claude-code
    need_commands claude
    claude --version
    manual 'Claude Code' 'Launch claude in a project and authenticate interactively. No account or API key is configured by bootstrap.'
}
main() {
    component optional 'Codex CLI' codex_install 'Official standalone installer for Linux ARM64; user-level CLI, no login.'
    component optional 'Claude Code' claude_install 'Official signed stable APT repository; native ARM64 CLI, no login.'
    record SKIPPED 'Guest inference runtime' 'LM Studio and all models stay on macOS; no guest daemon or model download is needed for HTTP API access.'
    manual 'Mac LM Studio API' 'On macOS, start the LM Studio server with Serve on Local Network and authentication. Use the Mac address reachable from Parallels in guest applications; verify with ./verify.sh --lm-host http://HOST_IP:1234.'
}
