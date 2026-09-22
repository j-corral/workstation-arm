
Post-install manual checklist (only for applicable installed components):
[ ] Reboot if required; select Plasma (prefer Wayland) at login
[ ] Choose SDDM with sudo dpkg-reconfigure sddm if desired
[ ] After reboot, confirm French PC AZERTY and NumLock in Plasma; test the login screen separately
[ ] Test Parallels graphics/resolution and Zed Vulkan support
[ ] Generate a dedicated passphrase-protected client SSH key
[ ] Set client-specific Git identity; gh auth login; glab auth login
[ ] Open Toolbox, authenticate JetBrains and select needed IDEs
[ ] Validate GUI apps, including Obsidian's Electron sandbox
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
