#!/usr/bin/env bash
# Host inference needs only an HTTP client in the VM. LM Studio and models run
# on macOS; network address/authentication are configured interactively.
lightpanda_install() {
    local binary="$WS_TMP/lightpanda"
    if command -v lightpanda >/dev/null; then
        LIGHTPANDA_DISABLE_TELEMETRY=true lightpanda version
        return
    fi
    locked_download lightpanda "$binary"
    elf_arm64 "$binary"
    install -d -m 0755 "$HOME/.local/bin"
    install -m 0755 "$binary" "$HOME/.local/bin/lightpanda"
    LIGHTPANDA_DISABLE_TELEMETRY=true "$HOME/.local/bin/lightpanda" version
}
rtk_install() {
    install_binary_archive rtk rtk rtk
    rtk telemetry disable
    rtk config recall sqlite
    rtk init --global --codex
    [[ -f ${CODEX_HOME:-$HOME/.codex}/hooks.json ]]
    grep -q 'rtk hook codex' "${CODEX_HOME:-$HOME/.codex}/hooks.json"
}
codex_install() {
    local config_state
    # Playwright MCP is run by npx from the user's Codex configuration. Keep
    # Node.js from Ubuntu's signed repository instead of installing a global
    # package that would bypass the user's selected @latest MCP version.
    apt_install nodejs npm
    need_commands npx
    lightpanda_install
    rtk_install
    if ! command -v codex >/dev/null; then
        download https://chatgpt.com/codex/install.sh "$WS_TMP/codex-install.sh"
        CODEX_NON_INTERACTIVE=1 sh "$WS_TMP/codex-install.sh"
    fi
    need_commands codex
    codex --version
    config_state=$(ensure_codex_lmstudio_config)
    if [[ $config_state == created ]]; then
        manual 'Codex CLI' 'Created ~/.codex/config.toml for the Mac LM Studio endpoint and installed the Qwen 27B Code / Qwen 4B Quotidien model catalog, plus Playwright, Local RAG, Lightpanda, GitLab and Plane MCP. Local RAG is confined to ~/Documents/Local-RAG. RTK is configured globally for Codex with telemetry disabled. Run codex mcp login gitlab and codex mcp login plane to authorize the remote services; no API key is stored.'
    else
        manual 'Codex CLI' 'Retained existing ~/.codex/config.toml and refreshed the workstation model catalog and managed Playwright, Local RAG, Lightpanda, GitLab and Plane MCP block. RTK is configured globally for Codex with telemetry disabled. Run codex mcp login gitlab and codex mcp login plane to authorize the remote services.'
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
