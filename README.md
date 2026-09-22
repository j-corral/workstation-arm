# Isolated Ubuntu ARM64 development workstation

A modular bootstrap for **Ubuntu 26.04 LTS, native ARM64/aarch64**, running in
Parallels Desktop Pro on an Apple Silicon Mac. KDE Plasma and Zsh are the target
user environment. Installation runs inside the guest, as its normal desktop user.

**Read the [compatibility decisions](docs/compatibility.md) before installing.**
The current official LM Studio headless bundle includes a model, so its automatic
installation is deliberately blocked. Proton Mail's inspected Linux package is
amd64. Proton VPN setup is manual because its official support targets GNOME.
Toolbox has an ARM64 build, but does not list Ubuntu 26.04 among tested releases.

This repository has been statically checked and tested offline on macOS. A user
run on Ubuntu 26.04 ARM64 passed through .NET installation, then exposed a Docker
preflight bug now corrected locally. **End-to-end guest validation is pending.**
Do not interpret a package/binary check as GUI, graphics, VPN or inference proof.
See the [validation record and guest acceptance procedure](docs/validation.md).

## Start here

1. Review the isolation checklist below and take a **Parallels snapshot** before
   installation. Check client policy: snapshots can contain credentials after enrollment.
2. Use a normal Ubuntu 26.04 ARM64 desktop installation with system Python 3,
   sudo access, systemd, working DNS/HTTPS and the official Ubuntu `main` and
   `universe` components enabled. Review existing APT sources; the bootstrap
   trusts the guest's configured signed repositories. Do not run on a valuable
   existing system without reviewing its configuration.
3. Copy/clone this repository **inside the VM's own disk**. Do not run the real
   installer on macOS or keep client files in shared host folders.
4. From the repository directory:

   ```bash
   ./bootstrap.sh --dry-run
   ./bootstrap.sh
   ./verify.sh
   ```

The first command is safe on macOS too: it prints an offline plan and makes no
changes. It does not test APT availability or vendor endpoints. Real installation
refuses the wrong OS/architecture and refuses root execution. Do **not** prefix
`bootstrap.sh` with `sudo`.

Allow at least 20 GiB free as a planning estimate, plus project/build/container
space. The script displays `df -h /` before and after and warns below that level;
it does not promise this estimate is sufficient. No full KDE suite, Docker
Desktop, Portainer, Ollama, LLM models or global Node.js is installed.

## Options and behavior

```bash
./bootstrap.sh --only docker
./bootstrap.sh --only shell
./bootstrap.sh --only desktop
./bootstrap.sh --only network
./bootstrap.sh --only security
./bootstrap.sh --only ai
./bootstrap.sh --skip desktop
./bootstrap.sh --dry-run --only dev
```

One `--only` or `--skip` filter is accepted; unknown/ambiguous options fail before
changes. `desktop` selects desktop applications; `kde` selects the desktop
session; `dev` selects development GUI applications. `--only shell` installs the
shell hooks; use `--only runtimes` to install mise itself.

Each real run first checks sudo, HTTPS access to Ubuntu's archive and disk space,
updates APT metadata and installs a small common transport/tooling prerequisite
set. This also happens with `--only`. Module order is fixed:

| Module | Automatic work | Failure policy |
| --- | --- | --- |
| `system` | Build essentials, certificates, curl/wget, git/GPG, zip/unzip, lsof, vim, jq, rg, bat, fzf, btop, direnv, zsh, ncdu, SSH client | Required |
| `kde` | `kde-plasma-desktop`, Wayland session, SDDM, Konsole, Dolphin, Plasma NetworkManager UI, KDE portal; French PC keyboard and NumLock | Required |
| `shell` | Zsh login shell, managed `.zshrc` section, direnv/mise/fzf hooks | Required |
| `git` | Ubuntu git, OpenSSH client, gh, glab; secure `.ssh` directory/config | Required |
| `runtimes` | System Python/venv, pinned uv/uvx, mise, Bun, Ubuntu .NET 10 SDK | Required |
| `docker` | Official Docker Engine/CLI/containerd/Compose/Buildx; pinned lazydocker | Docker required; TUI optional |
| `dev` | VS Code, Zed, Toolbox, Bruno ARM64 | Optional |
| `desktop` | Ubuntu Ghostty/KeePassXC, Obsidian ARM64 AppImage | Optional; Proton Mail skipped |
| `network` | Tailscale package and daemon | Optional; Proton VPN manual |
| `security` | AppArmor checks, normal unattended updates, OpenSnitch packages | AppArmor/updates required; OpenSnitch optional |
| `ai` | Reports current model-free tooling blocker; **no download** | Manual |

“Required” means failure stops the selected run. It does not override `--skip`.
An optional failure is recorded, later components run, and the overall exit code
is still nonzero. Manual/unsupported decisions are not installation failures.
Exit codes: `0` completed plan/run (possibly manual gaps), `1` or another nonzero
action code on failure, `2` invalid arguments, `130`/`143` interrupted.

The final report lists Installed, Skipped, Manual action required, Failed and
Reboot required. “Installed” includes a previously installed component whose
checks passed; it is not a claim that it was newly installed or authenticated.
After a critical stop, later components are **not attempted**.

Private reports live outside the repository in
`${XDG_STATE_HOME:-$HOME/.local/state}/workstation/run-*` (mode 0700). They contain
status messages and a package/version/architecture manifest, not a raw terminal
transcript. Installation errors remain visible in the terminal. Authentication
commands are never run or captured. Do not attach client-specific logs or
configuration to this repository.

## Reproducibility, reruns and updates

Standalone artifacts are pinned by version, HTTPS URL and SHA-256 in
[`config/downloads.json`](config/downloads.json). Digests were obtained from
vendor release metadata/published checksum files and checked against downloaded
bytes. They provide integrity/repeatability; a digest from the same vendor is
not an independent code-signing certificate. No release scraping happens at
bootstrap time. Wrong ELF architecture is rejected before executing a newly
downloaded binary; Bruno's DEB architecture/name are checked before installation.

APT uses signed repositories and their current candidates, so security updates
remain available. **This is a repeatable bootstrap, not a bit-for-bit OS image.**
APT versions/dependencies can change or disappear, and app self-updates can
change user installations. The package manifest records what actually existed;
use an approved snapshot or controlled APT mirror for exact image reproduction.
The bootstrap does not install global APT version holds.

Reruns preserve working user-level tools, existing SSH content, other `.zshrc`
content and existing OpenSnitch rules. APT can upgrade requested packages.
Shell markers are replaced atomically; malformed markers or symlinked target
configs fail instead of overwriting them. A per-user lock prevents overlapping
runs. Do not run simultaneous bootstraps as different users or edit the same
configuration during a run.

The scripts own only `workstation-*` APT source/key files. If another entry for
the same vendor is found, installation stops for that component until you
consolidate it. Existing modified managed source files are not overwritten.
Key rotation requires deliberate review. No `apt-key`, unofficial PPA, insecure
TLS, disabled signature check or amd64 emulation is used.

To update standalone tools, review the current official instructions and
compatibility first, update the lock with authentic vendor digests, and test on
a snapshot. Existing commands are preserved, so changing the lock does not
silently downgrade/replace a user installation; uninstall that particular tool
or use its approved updater before reinstalling. Avoid duplicate Snap/Flatpak/
APT/manual installations. Pre-existing tools outside PATH may require manual
reconciliation; the bootstrap cannot inventory every custom installation.

## Security architecture and Parallels isolation

The guest is a dedicated client workstation. No keys are generated, accounts
joined, credentials supplied, or external services authenticated. SSH is
**client only**. AppArmor remains enabled. GravityZone installation/enrollment
belongs to client IT; no competing realtime antivirus is installed.

Docker uses its local Unix socket. **Membership of the `docker` group grants
root-equivalent control of this VM.** No group membership is added automatically.
Use `sudo docker …`; if client IT approves unprivileged convenience, the explicit
manual choice is `sudo usermod -aG docker "$(id -un)"`, followed by a full logout.
The same access constraint applies to lazydocker. Never expose Docker over TCP.
Docker's own packet forwarding/NAT can bypass expectations of host firewall
frontends; bind development ports to `127.0.0.1` unless deliberate exposure is
approved. No extra firewall rules are created here.

Review in Parallels, with the VM stopped where necessary:

- Disable unnecessary shared macOS folders, shared home/profile and Mac volumes.
- Disable unnecessary drag and drop, shared applications and automatic host mounts.
- Decide explicitly whether clipboard sharing is acceptable for this client.
- Review USB/device sharing, backup access and snapshot retention.
- Keep client credentials and project data on the guest disk; do not import host
  SSH agents, private keys or password stores implicitly.
- Have IT approve any host inference path before sending client prompts/data.

LM Link and the optional future Ollama path deliberately connect VM and host;
this is **not an air-gapped architecture**. LM Link also involves vendor
account/control-plane connectivity. The repository does not configure Parallels
host settings, host firewall rules, bridged interfaces or host networking.

## Manual setup after installation

Use the full [post-install checklist](docs/post-install.md), also printed at the
end of a real run. In particular:

- Reboot after the KDE module: SDDM is automatically selected as the boot
  display manager and Plasma Wayland is preselected at login. Sign in normally.
  The running session is not restarted; GNOME remains available as another session.
  Each rerun of the KDE module restores this boot/session preference.
- Test resolution, scaling, suspend and Vulkan under Parallels. If necessary,
  Ubuntu's `plasma-session-x11` is an available manual fallback:
  `sudo apt-get install plasma-session-x11`. No unsupported graphics stack is added.
- Open Toolbox, test its GUI on 26.04, authenticate, and install only the required
  PhpStorm/PyCharm/Rider/etc. IDEs. Test Zed and Electron apps separately.

Create a client-specific SSH key **manually**, entering a passphrase interactively:

```bash
ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_client"
ssh-add "$HOME/.ssh/id_ed25519_client"
gh auth login
glab auth login
```

Use the desktop SSH agent or start one interactively if needed. Register only
the public key with the intended service. Configure `IdentityFile` and
`IdentitiesOnly yes` for that service in `~/.ssh/config`; review host key
fingerprints normally. Set Git name/email per client repository. Never commit
private keys or host-specific enrollment material. The sample key name is a
suggestion, not an instruction to overwrite an existing key.

Tailscale is installed but does not join any tailnet. With IT approval, run:

```bash
sudo tailscale up --accept-routes=false --accept-dns=false
```

No exit node, advertised subnet or Tailscale SSH is requested. Existing joined
Tailscale configurations are preserved, not reset; starting its daemon may
resume their existing connectivity. Proton VPN offers ARM64 packages, but this
KDE target is outside its documented GNOME support. Arrange a tested setup with
IT using the [official instructions](https://protonvpn.com/support/linux-vpn-debian-ubuntu).
Do not stack VPNs blindly: test DNS, private routes, kill switches and client VPN
requirements. No alternative VPN or manual tunnel configuration is applied here.

OpenSnitch is installed from Ubuntu. On a **new** installation its service is
masked before package installation, so it cannot disrupt the bootstrap. After
rule review, from a VM console with the GUI available:

```bash
opensnitch-ui
# In another terminal, when ready to configure application prompts:
sudo systemctl unmask opensnitch
sudo systemctl enable --now opensnitch
```

Review application-specific rules for Docker, Tailscale, Proton/client VPNs and
LM Link. Do not create a blanket allow rule. If installation fails after masking,
the mask remains deliberately; check package state before unmasking. Existing
OpenSnitch services/rules are preserved. Verify AppArmor with `sudo aa-status`.
Standard Ubuntu unattended-upgrades and APT timers are enabled; existing disabled
policies fail for review instead of being silently overwritten. Review allowed
security origins and third-party update policy with IT.

## LM Link: preferred architecture, currently blocked bootstrap

```text
Ubuntu VM (model-free client tooling)
    └─ LM Link → macOS LM Studio → models / Metal inference on M3 Max
```

The inspected current Linux ARM64 `llmster` full bundle contains an embedded
GGUF embedding model. To respect the no-model-download rule, `--only ai` reports
this blocker and does not fetch/install it. Do not work around this by running
the full official installer or by downloading then deleting its model. We have
not verified a current official model-free bootstrap. See the exact evidence in
[compatibility.md](docs/compatibility.md).

Once official compliant tooling is available and approved (or on an existing
compliant installation), the documented pairing steps are:

```bash
lms login
lms link enable
./verify.sh --lm-link
```

Enable LM Link on macOS LM Studio, connect the approved account/devices and keep
all model downloads on macOS. The status report must show the host peer. In a
manual inference test, explicitly select a **remote host model**, send a
non-sensitive test prompt and confirm in macOS LM Studio that the host handled
it. Repeat with the client's VPN enabled. A zero status-command exit is not
proof of pairing, model placement or inference. Verification never loads a
model, starts an inference server, authenticates or stores output on disk.

Fallback only, **not configured**:

```text
Ubuntu VM → private Parallels Host-Only network → macOS Ollama API → host model
```

If LM Link cannot coexist with the client VPN, have IT design a narrow private
VM-to-host API path. Bind the host service to the specific private interface and
restrict access to the VM; do not expose it to the LAN/public internet or use a
wildcard bind without appropriate controls. Ollama stays on macOS. This repo
installs no Ollama, model or secondary inference service inside Ubuntu and makes
no host networking changes.

## Verification and maintenance

```bash
./verify.sh                    # local inventory/status; no sudo prompt
./verify.sh --docker-hello     # explicit pull/run of ARM64 hello-world
./verify.sh --lm-link          # explicit read-only LM Link status after pairing
./tests/run.sh                 # offline regression tests + bash -n + ShellCheck
sudo docker system df         # disk inventory, not cleanup
ncdu "$HOME"                  # inspect guest home usage
```

Verification uses ✓ present/checked, ○ manual, ⚠ optional missing/unsupported,
and ✗ failure. It exits nonzero for missing required tools or failed operational
checks. It checks the complete desired workstation even if bootstrap used a
filter. Local Docker permission problems are reported as unresolved/manual,
not as a healthy daemon. GUI presence is not functional verification.
The hello-world option contacts Docker Hub, leaves a small cached image and
removes only its own test container. It explicitly targets the local Unix socket
and ARM64, with no container network or host mounts. No Docker cleanup is run.

## Troubleshooting, rollback and removal

- If Rosetta reports `unhandled auxillary vector type 29` while running `awk`,
  inspect `file -L /usr/bin/awk /usr/bin/python3` and
  `readlink -f /usr/bin/awk`. An ARM64 kernel and native dpkg architecture do not
  guarantee that every executable is ARM64. The bootstrap now probes `awk`
  before sudo or APT, so this failure cannot also break its final report.
  Identify the actual executable/package before repairing alternatives or
  reinstalling a native package; no automatic Rosetta/kernel changes are made.
- On package errors, inspect the visible APT error and the report's component.
  Check `apt-cache policy PACKAGE`, Ubuntu `universe`, disk space, DNS and locks.
  Do not substitute a different Ubuntu codename or force an amd64 package.
- Existing Docker/containerd packages are not automatically removed; review
  workloads and conflicts with IT first. Do not delete `/var/lib/docker` to fix
  an installation error. A daemon failing to start is a real failure.
- If an app is not found, open a fresh Zsh session. GUI launcher and shell PATH
  behavior differ. Normal tooling paths are included in the managed shell block.
- If Zed fails, inspect `vulkaninfo --summary` in the desktop session. If Obsidian
  or Bruno hits an AppArmor/Electron sandbox restriction, use vendor/IT guidance
  for a scoped policy; do not disable AppArmor or pass `--no-sandbox` globally.
- A checksum mismatch stops installation. Investigate changed vendor bytes,
  corruption or proxy behavior; never bypass the check. No downloaded binary is
  committed to this repository.
- Failed actions are not transactional. Reconcile partial tool directories or
  use the pre-bootstrap snapshot; rerun the relevant module after fixing the
  cause. Temporary downloads are removed on normal/error/signal exit; an abrupt
  VM power loss may leave a temporary directory.
- For reliable rollback, restore the approved snapshot. Package removal is not
  a full rollback of dependencies, data, services or user configuration.
- Remove a chosen APT application with `sudo apt-get remove PACKAGE` after
  reviewing the proposed transaction. Review autoremove separately. Remove its
  `workstation-*.list` and key only when no remaining package needs that feed.
- User tools installed here live under `~/.local/bin`; Zed also uses
  `~/.local/zed.app`, Toolbox `~/.local/share/workstation-toolbox`. Remove only
  the intended payload/symlink and its `workstation-*.desktop` launcher, after
  checking for user updates/data. Keep projects and app settings unless you
  explicitly intend to erase them. Remove only the delimited workstation block
  from `.zshrc` to undo hooks; choose another login shell with `chsh` if desired.

Architecture is intentionally small: bootstrap orchestrates policy/order,
modules declare component actions, `lib` handles system operations/reporting,
and Python helpers handle structured data and atomic text updates. Modules are
internal, not standalone entry points. No framework or secret configuration is
required.

### French PC keyboard and NumLock

The `kde` module installs `keyboard-configuration`, `console-setup` and
`libkf6config-bin`. It sets `/etc/default/keyboard` to model `pc105`, layout `fr`
and an empty variant (standard French AZERTY), preserving unrelated settings,
then regenerates the console keymap cache without changing the active console.
For the invoking user it sets Plasma's `kxkbrc` layout and `kcminputrc` NumLock
preference. NumLock is enabled when the next Plasma session starts, including
Wayland; no `numlockx` autostart is needed.

After updating the repository in the guest, run `./bootstrap.sh --only kde`,
then reboot and sign in to the preselected Plasma session. The same configuration is included in a full run.
Existing GNOME input-source preferences are separate and are not configured.
SDDM gets `/etc/sddm.conf.d/90-workstation-keyboard.conf` with `Numlock=on` for
its X11 greeter. A Wayland greeter needs compositor-specific configuration;
`/etc/sddm.conf` or a later drop-in may override this setting. The script selects SDDM for the next boot without restarting the running
display manager. It updates the Debian display-manager selection, enables the
SDDM systemd alias and graphical boot target, and seeds SDDM’s last-session
preference with the installed Plasma Wayland session filename. It does not
enable automatic login. Later manual session choices are remembered by SDDM.

References: [Plasma keyboard schema](https://raw.githubusercontent.com/KDE/plasma-desktop/Plasma/6.6/kcms/keyboard/keyboardsettings.kcfg),
[KWin NumLock handling](https://raw.githubusercontent.com/KDE/kwin/Plasma/6.6/src/xkb.cpp),
[SDDM configuration](https://github.com/sddm/sddm/blob/develop/data/man/sddm.conf.rst.in).

The KDE module explicitly installs `sddm-theme-breeze` and initially selects
`breeze` in `/etc/sddm.conf`, preserving other keys. The optional MacTahoe step
then selects MacTahoe after installing its assets. The X11 greeter receives French PC
keyboard defaults from `/etc/X11/xorg.conf.d/90-workstation-keyboard.conf`;
Plasma's user keyboard settings alone do not configure the login screen.
Apply with `./bootstrap.sh --only kde` after updating the repository, then save
work and reboot. Do not restart SDDM from an active desktop: it ends that session.

### MacTahoe and Breeze recovery

The KDE module installs the light variant from
[MacTahoe-kde](https://github.com/vinceliuice/MacTahoe-kde), pinned to commit
`cbf6a1f71b591d143184855d62f6272ce533e7c3` in `config/downloads.json` with a verified
SHA-256. Only static assets are copied; upstream installers are not executed.
The Plasma style, color scheme and window decorations are applied for the invoking
user, and the Plasma 6 SDDM theme is selected system-wide. Panel layout stays as
configured. Application widgets and icons use Breeze; separate MacTahoe icon,
cursor and Kvantum projects are not downloaded. Reboot to apply all changes.

The base KDE step selects Breeze first. If the optional MacTahoe download or
asset preparation fails, Breeze remains the login theme and the failure appears
in the report. Breeze stays installed after success. This is NOT an automatic
runtime fallback if MacTahoe encounters a QML or graphics error at login.
From a console, restore the login theme with:

```bash
sudo kwriteconfig6 --file /etc/sddm.conf --group Theme --key Current breeze
sudo reboot
```

For the desktop, choose Breeze under System Settings → Colors & Themes, or run
as your normal user and then log out/in:

```bash
plasma-apply-lookandfeel -a org.kde.breeze.desktop
```

A KDE-module rerun selects MacTahoe again. French PC keyboard settings are
independent of the theme: `/etc/default/keyboard`, the Xorg InputClass for SDDM,
and the user's `kxkbrc` are all configured with `fr` and `pc105`; NumLock is set
for SDDM and the next Plasma session. The installer reads back the Plasma keys.
