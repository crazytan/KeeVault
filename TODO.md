# TODO — KeeVault

## v1.2 (next)
- [ ] AutoFill from Safari not working as expected
- [ ] AutoFill subtitle missing in iOS Settings

## v2
- [ ] Editing support (create/modify entries)
- [ ] iPad support
- [ ] Sync / attachments

## Completed

### v1.1.0 (2026-02-22)
- [x] Most entries show no password — fixed inner stream decryption
- [x] TOTP not parsed from otp property
- [x] Replace vendored argon2 C code with Argon2Swift SPM
- [x] Search not working smoothly — fixed duplicate .searchable conflict
- [x] Duplicate entries from History — skip history entries in parser
- [x] Require Face ID to reveal/copy passwords
- [x] No lock shield flash during Face ID auth
- [x] Fix launch screen placeholder icon
- [x] Fix Xcode warnings (concurrency, deprecations)

### v1.0.0 (2026-02-17)
- [x] KDBX 4.x read/decrypt
- [x] Group/entry browsing
- [x] Search
- [x] TOTP display + copy
- [x] Face ID unlock
- [x] AutoFill credential provider extension
- [x] App Store submission
