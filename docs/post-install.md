
Post-install manual checklist (only for applicable installed components):
[ ] Reboot after the KDE module; SDDM and Plasma Wayland are selected automatically
[ ] Sign in normally and confirm the Plasma desktop opens
[ ] After reboot, confirm French PC AZERTY and NumLock in Plasma; test the login screen separately
[ ] Test Parallels graphics/resolution and Zed Vulkan support; use VS Code if unsupported
[ ] Open Konsole and verify the translucent Workstation profile
[ ] In Plasma Wayland, optionally open Foot and verify its translucent theme
[ ] Open local DOCX, XLSX and PPTX files in ONLYOFFICE
[ ] Attach Logitech receiver to guest or pair with Bluetooth; run solaar show
[ ] Open Bitwarden from Plasma and sign in; confirm the vault unlocks
[ ] Generate a dedicated passphrase-protected client SSH key
[ ] Set client-specific Git identity; gh auth login; glab auth login
[ ] Open Toolbox, authenticate JetBrains and select needed IDEs
[ ] Validate GUI apps, including Obsidian's extracted Electron build
[ ] At the first KWallet prompt, select Classic (Blowfish) and set a wallet password; GPG mode needs an existing encryption-capable key
[ ] Authenticate Tailscale only if approved by client IT
[ ] Run sudo ./tools/dns_status.sh; after connecting the client VPN, confirm private names and external DNS still resolve
[ ] Optional account separation: run `./bootstrap.sh --only accounts`. It prompts for the normal desktop account, enables/verifies terminal-only root administration, then removes `sudo`. The chosen developer retains Docker/lazydocker access, which is root-equivalent. Administer other system tasks with `su - root`, run the command directly, then `exit`.
[ ] Ensure Firefox/Chrome Secure DNS uses the system resolver rather than a third-party DoH endpoint
[ ] Arrange Proton VPN setup with IT (KDE is outside documented support)
[ ] Ask client IT for its approved Bitdefender BEST Linux ARM64 kit; IT installs/enrolls it, then check systemctl status bdsec*
[ ] Launch codex and claude from a project; sign in to each account interactively if permitted
[ ] Start LM Studio's API server on macOS; enable network access and authentication on the approved private VM-to-host route
[ ] From Ubuntu, run ./verify.sh --lm-host http://HOST_IP:1234 and configure chosen apps with base URL http://HOST_IP:1234/v1
[ ] Test inference with a non-sensitive prompt and confirm macOS handled it; keep models on macOS
[ ] Review/activate OpenSnitch and test all VPN/AI paths
[ ] Review Parallels sharing/isolation and clipboard policy
[ ] Run ./verify.sh; explicitly opt into --docker-hello and --lm-link
[ ] Take a clean post-bootstrap snapshot if client policy permits
