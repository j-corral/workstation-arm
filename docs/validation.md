# Validation record — 2026-09-21

## Follow-up — 2026-09-22

The user supplied a native Ubuntu 26.04 ARM64 installation transcript. Base
system, KDE, Zsh, Git/SSH, system Python, mise, uv, Bun and .NET 10 passed their
component checks. This is partial guest evidence, not GUI or full-run acceptance.
Docker stopped before repository setup: the name-filtered
`systemctl list-unit-files docker.service --no-legend` returned 1 on this clean
guest. The strict runner correctly stopped, but the presence check was wrong.

The Docker guard now lists service units without a name filter and examines
Docker only if present. Actual listing/inspection errors still fail, and existing
TCP listeners remain rejected. Bash syntax, ShellCheck and all 11 offline tests
pass, including absent/existing Docker units, TCP rejection and systemctl errors.
The fix has not yet been rerun in the user's guest; later modules remain untested
there. The earlier Rosetta-triggered awk failure also has a prerequisite probe
and regression test.

## Original host validation

Validation ran on the development macOS host. No Linux installer or downloaded
Linux executable was executed there. Ubuntu/Parallels guest installation acceptance testing was not performed.

Completed:

- Inspected the generated Bash, Python and Zsh configuration code.
- `bash -n` on all 18 Bash files: passed.
- ShellCheck on all Bash files: passed, no findings.
- `zsh -n config/zshrc`: passed.
- Python syntax parsing: passed.
- Nine offline regression tests: passed. These cover managed-section reruns,
  content/mode preservation, malformed markers/symlinks, side-effect-free dry-run
  and filters, invalid arguments, required/optional failure boundaries with real
  Bash errexit behavior, ARM64 rejection, archive traversal rejection, checksum
  mismatch rejection, and download-lock format. Several tests cover multiple cases.
- Secret-pattern and hardcoded user/home-path scan: no findings. This is a source
  audit, not a guarantee that arbitrary future edits cannot contain secrets.
- All 54 referenced Ubuntu package names were found in official resolute ARM64
  main/universe indexes. Seven additional names belong to documented vendor APT
  feeds (Docker, VS Code, Tailscale).
- The [Ubuntu fzf file list](https://packages.ubuntu.com/resolute/arm64/fzf/filelist)
  confirms both Zsh integration file paths used by the shell module.
- All eight automatic standalone artifacts were downloaded temporarily and their
  complete digests matched `config/downloads.json`. Archive paths passed safe
  extraction checks; executable ARM64 headers and Bruno's DEB metadata were
  inspected. The host's `ar` naming difference required a direct AR-header reader
  for Bruno's control metadata; the installer uses Ubuntu's standard `dpkg-deb`.
- Proton Mail's official download was confirmed amd64. LM Studio's full ARM64
  bundle was inspected and found to contain a GGUF model; it was removed from
  automatic installation rather than claiming model-free support.

Not validated here:

- APT dependency resolution/install, maintainer-script effects, sudo and systemd
  behavior in a real Ubuntu 26.04 ARM64 guest.
- First/second full installation equivalence on a snapshot. Offline managed-file
  tests do not constitute an end-to-end idempotency test.
- Plasma/Parallels graphics, Zed Vulkan, GUI application startup and Electron
  sandbox compatibility.
- Docker daemon/Compose/Buildx operation or hello-world execution in the guest.
- VPN coexistence, OpenSnitch rule behavior, LM Link pairing or host inference.

Guest acceptance procedure:

1. Snapshot a clean Ubuntu 26.04 ARM64 guest and record Parallels sharing settings.
2. Run the dry-run, then bootstrap. Review the actual Installed/Manual/Failed
   report and package manifest. Resolve any real failure before continuing.
3. Reboot/select Plasma, test graphical applications and run `./verify.sh`.
4. Explicitly run `./verify.sh --docker-hello` when Docker Hub access is approved.
5. Rerun bootstrap, confirm one managed shell block/source per component and
   unchanged pre-existing user configuration outside managed sections.
6. Enroll services separately with IT, activate/review OpenSnitch from a console,
   test all VPN paths and complete the manual checklist. LM Link remains blocked
   until an official model-free bootstrap is verified.
7. Capture an approved post-bootstrap snapshot; do not commit enrollment data.

## French keyboard follow-up — 2026-09-22

The KDE module now configures system and user Plasma French PC AZERTY defaults
and Plasma startup NumLock, plus the SDDM X11 greeter Numlock preference.
`bash tests/run.sh` passes Bash syntax checks, ShellCheck and 13 offline tests.
New tests cover preservation of unrelated system keyboard settings and file
mode, duplicate-key removal, missing keys, idempotency and symlink refusal.
No guest execution was available: console cache generation, Plasma startup,
physical keypad behavior and SDDM must still be checked after a VM reboot.

## Automatic Plasma login selection — 2026-09-22

The KDE module selects SDDM for the next graphical boot and seeds the installed
Plasma Wayland session in SDDM's state file, without enabling autologin or issuing
service start/stop/restart commands. Bash syntax checks, ShellCheck and all 15
offline tests pass. New mocked-command tests check boot/session selection and
that a missing Plasma session prevents changes to the display manager.
Actual reboot, SDDM startup and Plasma login still require guest validation.

Implementation references:
- [Debian SDDM display-manager selection](https://sources.debian.org/src/sddm/0.21.0%2Bgit20250502.4fe234b-2/debian/sddm.postinst)
- [SDDM last-session state](https://github.com/sddm/sddm/blob/v0.21.0/src/common/Configuration.h)
- [SDDM session preselection](https://github.com/sddm/sddm/blob/v0.21.0/src/greeter/SessionModel.cpp)

## SDDM greeter follow-up — 2026-09-22

The user confirmed Plasma login works after installing the Xorg server and
libinput driver, but reported an unthemed greeter and US-only keyboard there.
The module now explicitly installs/selects the Ubuntu Breeze SDDM theme and
installs an Xorg InputClass for fr/pc105, independently of user Plasma settings.
The previous journal's empty theme configuration supports the missing-theme
hypothesis; the corrected greeter appearance and keyboard require guest testing.

## MacTahoe integration — 2026-09-22

Downloaded the official commit archive cbf6a1f71b591d143184855d62f6272ce533e7c3
and verified SHA-256 b8b427a036438100faeaf2204cde3e5b4e09efc1a06e7b620a072167bd6b4256.
Inspected the Plasma 6 QML imports and upstream installation mappings. Staged
actual desktop and greeter assets locally using our static-file installer.
No upstream installation script was executed. Breeze remains installed;
rollback after runtime rendering errors is manual, as documented in README.
French keyboard configuration is independent of the theme, with Plasma readback
checks added. Local asset tests cover repeat installs, preservation of Breeze
and refusal of payload/destination symlinks. Guest QML rendering, colorscheme
activation and the login keyboard still require actual VM validation.
