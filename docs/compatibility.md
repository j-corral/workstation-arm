# Compatibility and source evidence

Reviewed **2026-09-22**. Official instructions and actual ARM64 artifact/package
metadata were checked. This is source/packaging evidence, not a live VM support
certification. Recheck these decisions when updating this repository.

| Component | Official evidence | Decision |
| --- | --- | --- |
| Ubuntu base/KDE/Konsole/KeePassXC/Solaar/gh/glab/OpenSnitch | [Ubuntu resolute ARM64 universe index](https://ports.ubuntu.com/ubuntu-ports/dists/resolute/universe/binary-arm64/) | Native packages checked by signed Ubuntu APT at runtime. Plasma Wayland is preferred. Konsole remains the default terminal with a user-owned translucent profile. |
| .NET 10 | [Microsoft Ubuntu guidance](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-install), [Ubuntu main ARM64 index](https://ports.ubuntu.com/ubuntu-ports/dists/resolute/main/binary-arm64/) | Ubuntu `dotnet-sdk-10.0`, ARM64 package confirmed. No Microsoft .NET feed. |
| Docker | [Official Ubuntu install](https://docs.docker.com/engine/install/ubuntu/) | Resolute and ARM64 explicitly listed; scoped keyring and official APT source. |
| mise | [Official installation](https://mise.jdx.dev/installing-mise.html) | Preferred upstream binary distribution. We pin/extract its official ARM64 release instead of running the mutable mise.run script, preserving its single-binary layout. No PPA. |
| uv | [Installation](https://docs.astral.sh/uv/getting-started/installation/), [platforms](https://docs.astral.sh/uv/reference/policies/platforms/) | Official pinned GNU/Linux aarch64 uv/uvx release; no project Python downloaded. |
| Bun | [Official installation](https://bun.com/docs/installation) | Official pinned Linux aarch64 archive, matching upstream installer payload. No mutable script or shell modification. |
| lazydocker | [Upstream README](https://github.com/jesseduffield/lazydocker), [release](https://github.com/jesseduffield/lazydocker/releases/tag/v0.25.2) | Official pinned Linux ARM64 archive; no source compiler or server needed. |
| VS Code | [Official Linux instructions](https://code.visualstudio.com/docs/setup/linux) | Official Microsoft APT feed with ARM64-only source constraint. Ubuntu-based installation documented; runtime GUI still needs testing. |
| Zed | [Linux](https://zed.dev/docs/linux), [requirements](https://zed.dev/docs/installation) | Stable official aarch64 archive. Bundled icon is installed in the desktop launcher. Zed needs a compatible Vulkan GPU; a Parallels guest without one remains unsupported. VS Code is the fallback. |
| Toolbox | [JetBrains requirements](https://www.jetbrains.com/help/toolbox-app/installation.html), [official release API](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release) | Official ARM64 archive exists. Install with explicit limitation: vendor lists Ubuntu 22.04/24.04 LTS, not 26.04. User chooses IDEs. |
| Bruno | [Official install](https://docs.usebruno.com/get-started/bruno-basics/download), [stable release](https://github.com/usebruno/bruno/releases/tag/v4.1.0) | ARM64 DEB exists. Documented APT stanza is amd64-only; do not invent arm64 repository support. Pin official ARM64 DEB and its vendor-published digest instead. This is HTTPS/digest integrity, not a claimed detached DEB signature. Exact 26.04 GUI operation unverified. |
| Obsidian | [Official download](https://obsidian.md/download), [AppImage extraction](https://docs.appimage.org/user-guide/troubleshooting/fuse.html), [Ubuntu zlib](https://packages.ubuntu.com/resolute/zlib1g-dev) | The installed ARM64 AppImage requested unversioned `libz.so`, supplied by Ubuntu `zlib1g-dev`; the runtime package alone supplies `libz.so.1`. Extract the pinned AppImage to avoid FUSE at launch and disable Electron GPU acceleration only in VMs. The earlier pinned `obsidian` executable is backed up and redirected. Live GUI validation is still required. |
| KWallet | [KDE handbook](https://docs.kde.org/trunk_kf6/en/kwalletmanager/kwalletmanager/introduction.html), [Ubuntu package](https://packages.ubuntu.com/resolute/kwalletmanager) | The exact “no keys suitable for encryption” prompt is KWallet's GPG option without a suitable key. Install KWallet Manager and let the user choose the Classic password-protected wallet interactively; do not fabricate a GPG identity or wallet password. |
| Foot | [Ubuntu 26.04 ARM64 package](https://packages.ubuntu.com/resolute/arm64/foot), [configuration reference](https://manpages.ubuntu.com/manpages/resolute/man5/foot.ini.5.html) | Optional Wayland terminal with a translucent palette and JetBrains Mono. Ubuntu package depends on Wayland and pixman, with no OpenGL dependency in its package metadata. Its actual appearance in the Parallels guest needs validation; Konsole remains default. |
| Ghostty | [Official 1.2 requirements](https://ghostty.org/docs/install/release-notes/1-2-0) | Removed from bootstrap installation. Guest log reports OpenGL below Ghostty's 4.3 minimum. An older installed package is left untouched; it cannot render on this virtual GPU. |
| ONLYOFFICE Desktop Editors | [Official Ubuntu installation](https://helpcenter.onlyoffice.com/desktop/installation/desktop-install-ubuntu.aspx), [Linux ARM announcement](https://www.onlyoffice.com/blog/2026/01/onlyoffice-desktop-editors-available-for-linux-arm) | Official signed APT repository, ARM64 candidate checked before installation. Edits local DOCX, XLSX and PPTX; live GUI remains to test. |
| Solaar | [Supported devices](https://pwr-solaar.github.io/Solaar/devices/) | Linux equivalent for Logitech HID++ devices. MX Anywhere 2 is listed; MX Keys S support depends on firmware/connection. Pairing and available controls require a live receiver/Bluetooth test. |
| Bitwarden | [Bitwarden Flatpak instructions](https://bitwarden.com/help/cli/), [Flathub listing](https://flathub.org/en/apps/com.bitwarden.desktop) | Bitwarden's Flathub app provides an aarch64 build. Install for the current user from Flathub; verify installed architecture. Vault login is interactive. |
| Spotify | [Spotify Linux downloads](https://www.spotify.com/download/linux/), [Flathub architectures](https://flathub.org/en/apps/com.spotify.Client) | Reviewed Linux Flatpak offers x86_64 only. Install a launcher for the official web player on this ARM64 guest; browser playback and account login require manual validation. |
| Proton Mail | [Official desktop instructions](https://proton.me/support/mail-desktop-app) | Official linked DEB downloaded and inspected: package `proton-mail`, version 1.14.0, **amd64**. No official Linux ARM64 download verified. Skip; web app is the manual alternative. |
| Proton VPN | [Official Debian/Ubuntu install](https://protonvpn.com/support/linux-vpn-debian-ubuntu), [official repository](https://repo.protonvpn.com/debian/dists/stable/Release) | ARM64 index exists; do not call ARM64 unavailable. Official support is GNOME on current Debian/Ubuntu, so automatic installation on this KDE target is deferred. |
| Quad9 Secure DoT | [Official service addresses](https://quad9.net/service/service-addresses-and-features/), [Ubuntu encrypted setup](https://docs.quad9.net/Setup_Guides/Linux_and_BSD/Ubuntu_22.04_%28Encrypted%29/), [Ubuntu 26.04 resolved.conf](https://manpages.ubuntu.com/manpages/resolute/man5/resolved.conf.5.html) | `dns.quad9.net` with both primary/secondary IPv4 and IPv6 addresses, strict `DNSOverTLS=yes`, and root-domain routing via systemd-resolved. Installer requires the resolved stub, verifies Quad9 reports `dot.`, and rolls back a failed first install. VPN-provided private DNS and browser-specific DNS need a guest check. Quad9 Secure blocks known malicious domains; it does not add child or ad blocking. |
| Tailscale | [Official package instructions](https://pkgs.tailscale.com/stable/#ubuntu), [Linux installation](https://tailscale.com/docs/install/linux) | Resolute feed/key published; scoped ARM64 APT source. Package/daemon only, no join. |
| OpenSnitch | [Upstream installation](https://github.com/evilsocket/opensnitch/wiki/Installation), Ubuntu index above | Upstream acknowledges Ubuntu packaging. Ubuntu 26.04 provides daemon 1.6.9-3ubuntu1 for ARM64, UI for all architectures and ARM64 eBPF modules. Install these official distro packages, defer activation. |
| AppArmor / updates | [Ubuntu AppArmor](https://documentation.ubuntu.com/server/how-to/security/apparmor/), [automatic updates](https://documentation.ubuntu.com/server/how-to/software/automatic-updates/) | Preserve normal security mechanisms; check effective state. No alternate update service. |
| Bitdefender GravityZone BEST | [Endpoint requirements](https://www.bitdefender.com/business/support/en/77212-376327-endpoint-protection.html), [BEST release notes](https://www.bitdefender.com/business/support/en/77212-77513-linux-agent.html), [installation procedure](https://www.bitdefender.com/business/support/en/77212-157497-install-security-agents---standard-procedure.html) | Current BEST supports Ubuntu 26.04 ARM64. Client-specific kit and enrollment are supplied by IT; no public generic installer is embedded. Do not install the separate GravityZone management appliance on this workstation. |
| LM Studio host API | [Serve on Local Network](https://lmstudio.ai/docs/developer/core/server/serve-on-network), [compatible API](https://lmstudio.ai/docs/developer/openai-compat), [headless setup](https://lmstudio.ai/docs/developer/core/headless) | LM Studio and models run on macOS; the Ubuntu guest uses the authenticated host HTTP API. `llmster` also exists on Linux, but is unnecessary for this client-only VM. Its current full ARM64 bundle includes a model and remains excluded. |
| Codex CLI | [Official OpenAI Codex CLI installation](https://developers.openai.com/codex/cli) | Use the official standalone Linux installer in the user account. It selects the platform build; login remains interactive. The installer is a vendor-managed moving release, not a checksum-pinned artifact. |
| Claude Code CLI | [Official Anthropic setup](https://code.claude.com/docs/en/setup) | Use Anthropic's signed stable APT repository with its documented key fingerprint; require a native ARM64 candidate. Login remains interactive. |

## Critical LM Studio packaging finding

The official `https://lmstudio.ai/install.sh` inspected on the review date sets
`APP_VERSION=0.0.25-1`, `APP_VARIANT=full`, explicitly recognizes Linux
`aarch64`/`arm64`, and selects:

```
https://llmster.lmstudio.ai/download/0.0.25-1-linux-arm64.full.tar.gz
```

Its [official SHA-512](https://llmster.lmstudio.ai/download/0.0.25-1-linux-arm64.full.sha512)
matched the inspected archive:

```
9743cfce0fd1e2b76f4fcbef6fbe4ed68f4e953781c0eba5c5db33308209f007939f3f946995618f22f8c4bb977919408c23a5cbbb369f530e2c92738f6891bc
```

The archive is **1,257,501,655 bytes** and contains this **84,106,624-byte model**:

```
.bundle/bin/bundled-models/nomic-ai/nomic-embed-text-v1.5-GGUF/nomic-embed-text-v1.5.Q4_K_M.gguf
```

Although this is an embedding model, it still violates the requested model-free
VM architecture and wastes guest disk. No such bundle is included in the runtime
download lock, and the AI module makes no download. We did not invent a `lite`
URL or modify/repackage the proprietary bootstrap. The downloaded audit archive
was inspected on the development host only, not installed/executed in a VM.

Once an official compliant bundle is verified, implement/pin it and repeat the
no-model audit before enabling AI installation. Until then, documented pairing
commands are conditional manual guidance, not a claim that bootstrap provides
working LM Link.

## Artifact verification

All eight automatic standalone downloads in `config/downloads.json` were fetched
from their official pinned URLs and their complete hashes checked during
implementation. ELF headers/archive paths were inspected without executing Linux
applications on macOS. Checksum evidence URLs are recorded per artifact.

Official APT source URLs and key locations follow vendor documentation; this
repository moves scoped key storage to `/etc/apt/keyrings` and uses `signed-by=`.
On the target, APT performs signature validation and the installer checks native
package architecture. No claim is made that a source package name alone proves
application usability or exact-distribution vendor support.

MacTahoe adds two architecture-independent pinned archives: the KDE theme at
`cbf6a1f71b591d143184855d62f6272ce533e7c3` and the icon/cursor theme at
`839848b9a8a38a92a6936e30c4abe35cc6f2546d`. Both SHA-256 digests were checked
against downloaded bytes. Plasma 6/Qt 6 assets are used. The user confirmed
that the earlier MacTahoe SDDM screen renders correctly on Ubuntu ARM64; the
expanded desktop layout, icons, cursor and Kvantum integration still need
guest validation. Breeze is retained for manual recovery.
