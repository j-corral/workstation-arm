
Post-install manual checklist (only for applicable installed components):
[ ] Reboot after the KDE module; SDDM and Plasma Wayland are selected automatically
[ ] Sign in normally and confirm the Plasma desktop opens
[ ] After reboot, confirm French PC AZERTY and NumLock in Plasma; test the login screen separately
[ ] Test Parallels graphics/resolution and Zed Vulkan support; use VS Code if unsupported
[ ] Open Konsole and verify the translucent Workstation profile
[ ] In Plasma Wayland, optionally open Foot and verify its translucent theme
[ ] Open local DOCX, XLSX and PPTX files in ONLYOFFICE
[ ] Attach Logitech receiver to guest or pair with Bluetooth; run solaar show
[ ] Generate a dedicated passphrase-protected client SSH key
[ ] Set client-specific Git identity; gh auth login; glab auth login
[ ] Open Toolbox, authenticate JetBrains and select needed IDEs
[ ] Validate GUI apps, including Obsidian's extracted Electron build
[ ] At the first KWallet prompt, select Classic (Blowfish) and set a wallet password; GPG mode needs an existing encryption-capable key
[ ] Authenticate Tailscale only if approved by client IT
[ ] Arrange Proton VPN setup with IT (KDE is outside documented support)
[ ] Install/enroll GravityZone using the client-provided package
[ ] Resolve the model-free LM tooling packaging blocker with IT
[ ] Once compliant tooling exists: lms login; lms link enable; pair macOS LM Studio
[ ] Verify LM Link and host inference; keep models on macOS
[ ] Review/activate OpenSnitch and test all VPN/AI paths
[ ] Review Parallels sharing/isolation and clipboard policy
[ ] Run ./verify.sh; explicitly opt into --docker-hello and --lm-link
[ ] Take a clean post-bootstrap snapshot if client policy permits
