# Maintenance

- Read README.md, docs/ARCHITECTURE.md and docs/VALIDATION.md first.
- Keep the applicationId and published signing identity stable. The package matches an unused factory HOME whitelist candidate; it confers no vendor signature or root privilege. Stop on collisions.
- Keep private signing keys, original firmware, device identifiers, backups, logs, NAS credentials and local tool directories out of Git and releases.
- Preserve other accessibility services, especially Tencent voice. BACK adaptation only handles Tencent root HOME and usage events; do not request screen contents.
- Device writes require user-authorized scope, a baseline backup and a recovery route. Announce intentional reboots. ADB offline does not establish power off.
- No rooting, flashing, system partition edits or boot video replacement are part of this installer.
- Distinguish build, mock tests, read-only device checks, physical device tests and user acceptance. Update docs/VALIDATION.md when evidence changes.
- When changing installer sources, regenerate checksums with Prepare.ps1 and rerun tests/Test-Installer.ps1. Publish only the reviewed source tree and explicit release artifacts.
