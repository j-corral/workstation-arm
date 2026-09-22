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
