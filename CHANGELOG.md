# Changelog

## TODO

### Bugs
- (none currently)

### Features
- (none currently)

### Security (from SECURITY_AUDIT.md)
- [x] **HIGH-1/2:** Lazy decrypt — passwords and TOTP secrets held as AES-GCM `EncryptedValue` in memory, decrypted on demand only (copy, reveal, AutoFill, TOTP generation). Session key nilled on lock.
- [x] **MEDIUM-1:** Switch favicon provider from Google to DuckDuckGo (privacy)
- [x] **MEDIUM-5:** Filter internal/private domain names from favicon fetching
- [ ] **LOW-2:** Add exponential backoff after failed password attempts
- [ ] **LOW-3:** Detect active screen recording (`UIScreen.isCaptured`) and show warning/blur

### v2 roadmap
- Editing support (create/modify entries)
- iPad support
- Sync / attachments

## Unreleased

### Features
- **QuickType AutoFill** — credential suggestions appear in the keyboard bar in Safari. Tap to autofill with Face ID, no full AutoFill popup needed. Toggle in Settings → Security → Quick AutoFill.

### Changes
- License changed to GPLv3
- Moved SECURITY_AUDIT.md to docs/
- EU App Store availability enabled (DSA trader status submitted)


### Security
- Switched favicon provider from Google to DuckDuckGo (prevents Google tracking favicon requests)
- Private/internal domains (RFC 1918 IPs, .local/.corp/.internal TLDs, single-label hostnames, etc.) are now filtered from favicon fetching to prevent hostname leakage
- Passwords and TOTP secrets now stored as AES-GCM encrypted `EncryptedValue` in memory (lazy decrypt on demand)
- Per-session symmetric key generated at unlock, destroyed on lock
- Plaintext secrets only exist in transient local variables at point of use (copy, reveal, TOTP generation)

## v1.2.0 (2026-02-26)

### New Features
- Opt-in website favicon support with disk cache (Google favicon API, SHA256 cache keys, 7-day TTL)
- "Download Website Favicons" toggle in Settings (off by default) with "Clear Favicon Cache" action
- Auto Face ID unlock on app open (opt-in setting in Security)
- Auto Face ID unlock in AutoFill extension (shared via App Group)
- Auto-lock inactivity timer (resets on user interaction, configurable in Settings)
- List sorting by title, created date, or modified date (persisted)
- Multiple URLs per entry via KP2A_URL custom fields (display + AutoFill matching)
- Exclude Recycle Bin from search, AutoFill, and group navigation

### Security
- Clipboard now uses `.localOnly` — passwords no longer sync via Universal Clipboard
- Constant-time HMAC/hash comparison (timing side-channel mitigation)
- Decompression bomb protection (256MB limit)
- Favicon cache written with `NSFileProtectionComplete`
- AutoFill extension clears parsed entries from memory after use
- Removed "Never" from clipboard clear timeout options
- Production logging gated behind `#if DEBUG`
- Negative block size validation in KDBX parser

### Fixes
- Fixed duplicate lock button in root view
- Fixed AutoFill subtitle missing in iOS Settings
- Fixed Face ID unlock not appearing on device (improved keychain existence check)
- Fixed keychain account key to use filename instead of full path
- Fixed 3 failing UI tests (navigation helpers now prefer non-empty groups)

### UI
- Renamed "Show Website Icons" → "Download Website Favicons"
- Renamed "Clipboard Timeout" → "Clipboard Clear Timeout"
- Renamed "Sort Order" → "Default Sort Order"
- Lock button in group list toolbar
- Removed debug state label from unlock screen
- Removed GitHub Repository link from Settings

### Infrastructure
- GitHub Actions CI workflow (build + unit tests)
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
