# Changelog

## TODO

- [ ] Face ID unlock button not appearing on device (keychain `hasStoredKey` returns false even after successful store — possibly `SecItemCopyMatching` with `kSecUseAuthenticationUISkip` returns unexpected status code with `.biometryCurrentSet` access control; needs status code debugging on device)
- [ ] AutoFill from Safari not working as expected
- [ ] AutoFill subtitle missing in iOS Settings

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
