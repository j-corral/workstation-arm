# Compatibility and source evidence

Reviewed **2026-09-21**. Official instructions and actual ARM64 artifact/package
metadata were checked. This is source/packaging evidence, not a live VM support
certification. Recheck these decisions when updating this repository.

| Component | Official evidence | Decision |
| --- | --- | --- |
| Ubuntu base/KDE/Ghostty/KeePassXC/gh/glab/OpenSnitch | [Ubuntu resolute ARM64 universe index](https://ports.ubuntu.com/ubuntu-ports/dists/resolute/universe/binary-arm64/) | Native packages confirmed; signed Ubuntu APT at runtime. Plasma 6.6.4 Wayland and X11 session packages exist; prefer Wayland. |
| .NET 10 | [Microsoft Ubuntu guidance](https://learn.microsoft.com/en-us/dotnet/core/install/linux-ubuntu-install), [Ubuntu main ARM64 index](https://ports.ubuntu.com/ubuntu-ports/dists/resolute/main/binary-arm64/) | Ubuntu `dotnet-sdk-10.0`, ARM64 package confirmed. No Microsoft .NET feed. |
| Docker | [Official Ubuntu install](https://docs.docker.com/engine/install/ubuntu/) | Resolute and ARM64 explicitly listed; scoped keyring and official APT source. |
| mise | [Official installation](https://mise.jdx.dev/installing-mise.html) | Preferred upstream binary distribution. We pin/extract its official ARM64 release instead of running the mutable mise.run script, preserving its single-binary layout. No PPA. |
| uv | [Installation](https://docs.astral.sh/uv/getting-started/installation/), [platforms](https://docs.astral.sh/uv/reference/policies/platforms/) | Official pinned GNU/Linux aarch64 uv/uvx release; no project Python downloaded. |
| Bun | [Official installation](https://bun.com/docs/installation) | Official pinned Linux aarch64 archive, matching upstream installer payload. No mutable script or shell modification. |
| lazydocker | [Upstream README](https://github.com/jesseduffield/lazydocker), [release](https://github.com/jesseduffield/lazydocker/releases/tag/v0.25.2) | Official pinned Linux ARM64 archive; no source compiler or server needed. |
| VS Code | [Official Linux instructions](https://code.visualstudio.com/docs/setup/linux) | Official Microsoft APT feed with ARM64-only source constraint. Ubuntu-based installation documented; runtime GUI still needs testing. |
| Zed | [Linux](https://zed.dev/docs/linux), [requirements](https://zed.dev/docs/installation) | Stable official aarch64 archive; glibc minimum met by 26.04. Vulkan 1.3/portal behavior in Parallels unverified. |
| Toolbox | [JetBrains requirements](https://www.jetbrains.com/help/toolbox-app/installation.html), [official release API](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release) | Official ARM64 archive exists. Install with explicit limitation: vendor lists Ubuntu 22.04/24.04 LTS, not 26.04. User chooses IDEs. |
| Bruno | [Official install](https://docs.usebruno.com/get-started/bruno-basics/download), [stable release](https://github.com/usebruno/bruno/releases/tag/v4.1.0) | ARM64 DEB exists. Documented APT stanza is amd64-only; do not invent arm64 repository support. Pin official ARM64 DEB and its vendor-published digest instead. This is HTTPS/digest integrity, not a claimed detached DEB signature. Exact 26.04 GUI operation unverified. |
| Obsidian | [Official download](https://obsidian.md/download) | Page links a stable ARM64 AppImage. Install that pinned artifact; Ubuntu sandbox/FUSE behavior needs GUI validation. Not marked architecture-unsupported. |
| Proton Mail | [Official desktop instructions](https://proton.me/support/mail-desktop-app) | Official linked DEB downloaded and inspected: package `proton-mail`, version 1.14.0, **amd64**. No official Linux ARM64 download verified. Skip; web app is the manual alternative. |
| Proton VPN | [Official Debian/Ubuntu install](https://protonvpn.com/support/linux-vpn-debian-ubuntu), [official repository](https://repo.protonvpn.com/debian/dists/stable/Release) | ARM64 index exists; do not call ARM64 unavailable. Official support is GNOME on current Debian/Ubuntu, so automatic installation on this KDE target is deferred. |
| Tailscale | [Official package instructions](https://pkgs.tailscale.com/stable/#ubuntu), [Linux installation](https://tailscale.com/docs/install/linux) | Resolute feed/key published; scoped ARM64 APT source. Package/daemon only, no join. |
| OpenSnitch | [Upstream installation](https://github.com/evilsocket/opensnitch/wiki/Installation), Ubuntu index above | Upstream acknowledges Ubuntu packaging. Ubuntu 26.04 provides daemon 1.6.9-3ubuntu1 for ARM64, UI for all architectures and ARM64 eBPF modules. Install these official distro packages, defer activation. |
| AppArmor / updates | [Ubuntu AppArmor](https://documentation.ubuntu.com/server/how-to/security/apparmor/), [automatic updates](https://documentation.ubuntu.com/server/how-to/software/automatic-updates/) | Preserve normal security mechanisms; check effective state. No alternate update service. |
| LM Studio / LM Link | [Headless setup](https://lmstudio.ai/docs/developer/core/headless), [add device](https://lmstudio.ai/docs/lmlink/basics/add-device), [status](https://lmstudio.ai/docs/cli/link/link-status) | Linux ARM64 installer exists, but the current full bundle includes a model. Automatic download conflicts with the mission; blocked pending an official model-free method. |

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
