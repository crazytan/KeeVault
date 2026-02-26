# Changelog

## TODO

### Bugs
- AutoFill subtitle missing in iOS Settings (Passwords & AutoFill page)
- 3 UI tests failing (EntryDetail, Navigation, Search) — can't find entries after unlock, likely UI test mode detection issue

### Features
- Auto Face ID unlock on app open (opt-in setting)
- Auto Face ID unlock in AutoFill extension (when opt-in enabled)
- Exclude Recycle Bin from search results and AutoFill
- Favicon support (download from Google favicon service; opt-in since it adds network calls)

### v2 roadmap
- Editing support (create/modify entries)
- iPad support
- Sync / attachments

## Unreleased

- Lock button in group list toolbar
- Renamed "Clipboard Timeout" → "Clipboard Clear Timeout" in Settings
- Renamed "Sort Order" → "Default Sort Order" in Settings
- Removed GitHub Repository link from Settings
- Fixed Face ID unlock not appearing on device (improved keychain existence check)
- Auto-lock inactivity timer (resets on user interaction, configurable in Settings)
- Settings page with auto-lock timeout, clipboard timeout, sort order, and about section
- Fixed keychain account key to use filename instead of full path (bookmark-resolved paths change between launches)
- List sorting by title, created date, or modified date (persisted to UserDefaults)
- Multiple URLs per entry via KP2A_URL custom fields (display + AutoFill matching)
- Auto-lock unit tests + enriched test fixture (7 entries, nested groups, unicode, edge cases)

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
