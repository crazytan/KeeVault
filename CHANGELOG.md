# Changelog

## TODO

### Features
- [x] Feedback button in About page → links to GitHub Issues
- [x] Tip Jar in About page — consumable IAPs (StoreKit 2)
- [x] Key file support (`.key` / `.keyx` — composite key unlock) → see docs/KEY_FILE_IMPLEMENTATION.md
- [ ] Passkey support
- [x] Show created/modified timestamps in entry detail view
- [x] Sort ascending/descending toggle (currently always ascending)

### Bugs
- [x] Tip Jar section shows spinner on device (StoreKit config not wired to scheme, or products not in App Store Connect)

### Security (from SECURITY_AUDIT.md)
- [x] **HIGH-1/2:** Lazy decrypt — passwords and TOTP secrets held as AES-GCM `EncryptedValue` in memory, decrypted on demand only (copy, reveal, AutoFill, TOTP generation). Session key nilled on lock.
- [x] **MEDIUM-1:** Switch favicon provider from Google to DuckDuckGo (privacy)
- [x] **MEDIUM-5:** Filter internal/private domain names from favicon fetching
- [x] **LOW-2:** Add exponential backoff after failed password attempts
- [x] **LOW-3:** Detect active screen recording (`UIScreen.isCaptured`) and show warning/blur

### v2 roadmap
- Editing support (create/modify entries)
- iPad-native layout
- Sync / attachments

## v1.3.0 (2026-03-03)

### New Features
- **QuickType AutoFill** — credential suggestions appear in the keyboard bar in Safari. Tap to autofill with Face ID, no full AutoFill popup needed. Toggle in Settings → Quick AutoFill.

### Fixes
- Fixed QuickType domain extraction — www-stripping, subdomain collapsing, multi-part TLD support (e.g. `login.facebook.com` → `facebook.com`, `bbc.co.uk` handled correctly)
- Fixed AutoFill Face ID timing — biometric now deferred until view is presented, resolving "User interaction required" error on QuickType tap
- Increased tap targets for view/copy/open URL buttons in entry detail (44pt minimum per Apple HIG)

### Security
- Hardened KDBX parser: `DataReader` now throws on truncated data instead of silently truncating
- Bounded Argon2 KDF parameters (iterations, memory, parallelism) to prevent resource exhaustion from malicious files
- Validated variant-map value lengths before decoding

### Changes
- Renamed from KeeVault to KeeForge (display name, all internal references, folders, scheme, module name)
- License changed to GPLv3
- Switched favicon provider from Google to DuckDuckGo (privacy)
- Private/internal domains filtered from favicon fetching
- Passwords and TOTP secrets stored as AES-GCM `EncryptedValue` in memory (lazy decrypt on demand)

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
