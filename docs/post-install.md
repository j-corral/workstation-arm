
Post-install manual checklist (only for applicable installed components):
[ ] Reboot after the KDE module; SDDM and Plasma X11 are selected automatically
[ ] Sign in normally and confirm the Plasma desktop opens
[ ] After reboot, confirm French PC AZERTY and NumLock in Plasma; test the login screen separately
[ ] Test Parallels graphics/resolution and Zed Vulkan support; use VS Code if unsupported
[ ] Open Konsole and verify the translucent Workstation profile
[ ] Optionally select Plasma Wayland from SDDM and verify its graphics, input and Foot terminal behavior before using it daily
[ ] Open local DOCX, XLSX and PPTX files in ONLYOFFICE
[ ] Attach Logitech receiver to guest or pair with Bluetooth; run solaar show
[ ] Open Bitwarden from Plasma and sign in; confirm the vault unlocks
[ ] Generate a dedicated passphrase-protected client SSH key
[ ] Set client-specific Git identity; gh auth login; glab auth login
[ ] Open Toolbox, authenticate JetBrains and select needed IDEs
[ ] Validate GUI apps, including Obsidian's extracted Electron build
[ ] Confirm no KWallet prompt appears; use Bitwarden or KeePassXC for credentials
[ ] Authenticate Tailscale only if approved by client IT
[ ] Run sudo ./tools/dns_status.sh; after connecting the client VPN, confirm private names and external DNS still resolve
[ ] Optional account separation: run `./bootstrap.sh --only accounts`. It prompts for the normal desktop account, enables/verifies terminal-only root administration, then removes `sudo`. The chosen developer retains Docker/lazydocker access, which is root-equivalent. Administer other system tasks with `su - root`, run the command directly, then `exit`.
[ ] Ensure Firefox/Chrome Secure DNS uses the system resolver rather than a third-party DoH endpoint
[ ] Arrange Proton VPN setup with IT (KDE is outside documented support)
[ ] Ask client IT for its approved Bitdefender BEST Linux ARM64 kit; IT installs/enrolls it, then check systemctl status bdsec*
[ ] Launch codex and claude from a project; sign in to each account interactively if permitted
[ ] If curl.md was selected, use it only for public documentation/articles; never provide private client URLs, tickets, repositories, authenticated links or secrets
[ ] Start Kapitsa on macOS with --host, --port and --api-key on the approved private VM-to-host route
[ ] From Ubuntu, run ./verify.sh --kapitsa-host http://HOST_IP:8000, source LLM_API_KEY privately and synchronize the Codex model catalog
[ ] Test inference with a non-sensitive prompt and confirm macOS handled it; keep models on macOS
[ ] Review/activate OpenSnitch and test all VPN/AI paths
[ ] Review Parallels sharing/isolation and clipboard policy
[ ] Run ./verify.sh; explicitly opt into --docker-hello and --kapitsa-host when the Mac server is running
[ ] Take a clean post-bootstrap snapshot if client policy permits
