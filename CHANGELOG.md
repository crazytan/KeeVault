# Changelog

## TODO

### Bugs
- [ ] Face ID unlock button not appearing on device (keychain `hasStoredKey` returns false after successful store; needs on-device status code debugging)
- [ ] AutoFill from Safari not working as expected
- [ ] AutoFill subtitle missing in iOS Settings

### Features
- [ ] Settings page (clipboard timeout, auto-lock timeout, auto Face ID, sort preference)
- [ ] List sorting by different attributes (created, updated, title)
- [ ] Auto-lock after inactivity timeout (foreground idle timer; background lock already works)
- [ ] Auto Face ID unlock on app open (opt-in; depends on keychain bug fix)
- [ ] Favicon support (download from Google favicon service; opt-in since it adds network calls)
- [ ] Multiple URLs per entry via KP2A_URL custom fields (also improves AutoFill matching)
- [ ] Add tests for auto-lock on background behavior

### v2 roadmap
- [ ] Editing support (create/modify entries)
- [ ] iPad support
- [ ] Sync / attachments

## Unreleased

- Fixed keychain account key to use filename instead of full path (bookmark-resolved paths change between launches)

## v1.1.0 (2026-02-22)

- Fixed inner stream decryption — passwords now display correctly
- Fixed TOTP parsing from `otp://` custom property
- Replaced vendored argon2 C code with Argon2Swift SPM package
- Fixed search — no longer dismisses on typing, works on all pages
- Fixed duplicate entries from History elements leaking into results
- Face ID required to reveal/copy passwords
- No lock shield flash during biometric authentication
- Fixed launch screen placeholder icon
- Resolved Xcode warnings (concurrency, deprecations)

## v1.0.0 (2026-02-17)

- KDBX 4.x read & decrypt
- Group/entry browsing with navigation
- Search across all entries
- TOTP display & copy
- Face ID database unlock
- AutoFill credential provider extension
- Initial App Store release
