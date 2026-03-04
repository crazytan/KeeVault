# AGENTS.md

Context for AI coding agents working on KeeForge.

## Overview

iOS KeePass password manager (KDBX 4.x, read-only in v1). Swift 6, SwiftUI, iOS 17+, MVVM with `@Observable`. Build system: XcodeGen (`project.yml` → `.xcodeproj`).

## Architecture

```
KeeVault/
├── App/
│   └── KeeVaultApp.swift          # App entry, scene lifecycle, auto-lock on background
├── Models/
│   ├── KDBXParser.swift           # KDBX 4.x binary format → XML → KPGroup/KPEntry tree
│   ├── KDBXCrypto.swift           # AES-256, ChaCha20, HMAC-SHA256, Argon2, gzip
│   ├── Group.swift                # KPGroup model (tree of groups + entries)
│   ├── Entry.swift                # KPEntry model (title, username, password, URLs, TOTP)
│   ├── EncryptedValue.swift       # AES-GCM wrapper for in-memory secret protection
│   └── TOTPGenerator.swift        # RFC 6238 TOTP generation
├── ViewModels/
│   ├── DatabaseViewModel.swift    # Main VM: unlock, lock, search, sort, state machine
│   └── TOTPViewModel.swift        # Live TOTP code + countdown timer
├── Views/
│   ├── UnlockView.swift           # Password entry + Face ID unlock + auto-unlock logic
│   ├── GroupListView.swift        # Group/entry navigation (excludes Recycle Bin)
│   ├── EntryDetailView.swift      # Entry detail with copy actions + Face ID for passwords
│   ├── EntryListView.swift        # Flat entry list within a group
│   ├── SearchView.swift           # Search results overlay
│   ├── FaviconView.swift          # Favicon image with fallback chain (cached → fetch → iconID)
│   └── SettingsView.swift         # Settings page (security, display, about)
├── Services/
│   ├── BiometricService.swift     # Face ID / Touch ID availability + authentication
│   ├── KeychainService.swift      # Composite key storage with biometric access control
│   ├── SettingsService.swift      # UserDefaults persistence (some shared via App Group)
│   ├── SharedVaultStore.swift     # App Group shared storage (database bookmark)
│   ├── CredentialMatcher.swift    # URL matching for AutoFill
│   ├── ClipboardService.swift     # Copy with auto-expiry
│   ├── DocumentPickerService.swift # File bookmark management
│   ├── FaviconService.swift        # Favicon fetch (Google API) + disk cache with TTL
│   ├── ScreenProtectionService.swift # Shield on background
│   └── HapticService.swift        # Haptic feedback
├── Extensions/
│   └── NavigationConformances.swift
└── Resources/

AutoFillExtension/
└── CredentialProviderViewController.swift  # ASCredentialProviderViewController

KeeVaultTests/          # Unit tests
KeeVaultUITests/        # UI tests (XCUITest)
TestFixtures/test.kdbx  # Test database
```

## Data Flow

```
.kdbx file → KDBXParser.parse(data:compositeKey:sessionKey:)
  → Decrypts binary (AES/ChaCha20 + Argon2 key derivation)
  → Decompresses (gzip)
  → Parses XML → KPGroup tree (with recycleBinUUID on root)
  → Passwords & TOTP secrets re-encrypted with sessionKey as EncryptedValue (AES-GCM)
  → DatabaseViewModel stores rootGroup + sessionKey
  → Views decrypt on demand (copy, reveal, TOTP generation)
  → On lock: sessionKey nilled, EncryptedValues become undecryptable
```

## Key Patterns

- **State machine:** `DatabaseViewModel.State` = `.locked` → `.unlocking` → `.unlocked` / `.error(String)`
- **Lock cycle tracking:** `lockCycleID` increments on each lock, used to prevent auto-unlock retry loops
- **Recycle Bin:** parsed from `<RecycleBinUUID>` in XML metadata, stored as `recycleBinUUID` on root `KPGroup`. Excluded from search, AutoFill, and group navigation.
- **Settings storage:** Most settings in `UserDefaults.standard`. Settings shared with AutoFill extension (like `autoUnlockWithFaceID`) use `UserDefaults(suiteName: SharedVaultStore.appGroupID)`.
- **App Group:** `group.com.keevault.shared` — shared between main app and AutoFill extension for database bookmark + shared settings + favicon cache
- **Favicons:** Opt-in via `SettingsService.showWebsiteIcons` (off by default). `FaviconService` fetches from Google favicon API (`/s2/favicons?domain=&sz=64`), caches to App Group container (`favicons/` directory) with SHA256(domain) filenames and 7-day TTL. `FaviconView` is a SwiftUI component with fallback chain: cached → fetch → KeePass iconID → generic key icon. Used in `EntryRow` (24×24), `EntryDetailView` (40×40), and search results.

## Conventions

- `@Observable`, not `ObservableObject`/`@Published`
- `NavigationStack` + `NavigationPath`, not `NavigationView`
- Swift 6 strict concurrency (`Sendable` correctness)
- Crypto/parsing off main thread
- No force unwraps outside tests
- No unnecessary dependencies
- Accessibility identifiers: `lock.button`, `sort.menu`, `settings.button`, `group.navlink`, `entry.navlink`, `entry.copy.<field>`, `unlock.password.field`, `unlock.button`, `unlock.error.label`

## Adding a New Setting

1. Add key to `SettingsService.Key`
2. Add computed property in `SettingsService` (use `sharedDefaults` if AutoFill needs it)
3. Add `@State` in `SettingsView` + UI control + `.onChange` handler
4. Add tests in `SettingsServiceTests`
5. If AutoFill needs the setting, ensure `SettingsService.swift` is in AutoFill target sources (`project.yml`)

## Security

- **Lazy decrypt:** Passwords and TOTP secrets are stored as `EncryptedValue` (AES-GCM sealed data) in memory, not plaintext `String`. A per-session `SymmetricKey` is generated at unlock and passed through the parser. Secrets are only decrypted into transient local variables at the point of use (copy, reveal, AutoFill, TOTP generation). The session key is nilled on lock, making all `EncryptedValue`s undecryptable.
- `EncryptedValue.hasValue` allows checking emptiness without decrypting (e.g. `entry.hasPassword`)
- Composite key stored in Keychain with biometric access control
- Never store raw master password
- Auto-lock on background, clear sensitive state
- Clipboard auto-expires (configurable, default 30s)
- No analytics or telemetry. Network calls only for opt-in favicon fetching (domain only, no credentials)
- Face ID required to reveal/copy passwords

## Stable Core (change only for real bugs)

- `KDBXParser.swift` — KDBX 4.x parsing, decryption, XML extraction
- `KDBXCrypto.swift` — AES, ChaCha20, HMAC, gzip, key derivation
- `Entry.swift`, `Group.swift` — data models
- `TOTPGenerator.swift` — RFC 6238

## Build & Test

```bash
xcodegen generate
xcodebuild build -project KeeVault.xcodeproj -scheme KeeVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project KeeVault.xcodeproj -scheme KeeVault \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If simulator gets stuck with "preflight checks" error:
```bash
xcrun simctl shutdown all && xcrun simctl erase <UDID>
```

## Testing

- Every feature and bug fix should include automated tests
- Unit tests for logic, UI tests for user-facing flows
- If a bug is found, write a regression test first, then fix
- Run the full test suite before committing

### Test Fixture

`TestFixtures/test.kdbx` (password: `testpassword123`) contains:
- **Root** group (top-level, no entries directly)
  - **Empty** group (0 entries)
  - **Social** group: Twitter (with 2 history entries), Discord (with TOTP), Offline Key, Public Profile
  - **Work** group: Email, GitHub (with TOTP)

**UI test gotcha:** The root group has only subgroups, no direct entries. `openAnyEntry()` must navigate into a non-empty subgroup (Social or Work) to find entries. The helper `findNonEmptyGroup()` in `KeeVaultUITestCase.swift` handles this by preferring groups whose label doesn't contain "0 entries".

## CHANGELOG

**Always update `CHANGELOG.md` when committing a feature or bug fix.** Add a bullet to the `## Unreleased` section describing the change. Use past tense for fixes ("Fixed ...") and present tense for features ("Add ..."). Keep entries concise. Do NOT modify entries under released versions (v1.0.0, v1.1.0, etc.).
