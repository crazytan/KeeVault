# STATUS.md — KeeVault Project Status

**Last updated:** 2026-02-14 11:22pm PST

## Current State
- **Phase:** KDBX parser unit-test stabilization
- **Build:** ✅ Compiles and runs
- **Unit tests:** ✅ 4/4 passing (`KeeVaultTests`)
- **UI tests:** unchanged from prior run (see historical results below)
- **Blocker:** remaining failures are in UI flow, not parser unit coverage

## Unit Test Work (2026-02-14)
- Verified fixture header: `TestFixtures/test.kdbx` exists, bytes `10-11` = `0x0004` (KDBX major version 4)
- Verified fixture via KeePassXC CLI:
  - `keepassxc-cli ls TestFixtures/test.kdbx` => `Social/`, `Work/`
  - `keepassxc-cli db-info TestFixtures/test.kdbx` => Argon2d KDF, valid DB metadata
- Added new unit test target: `KeeVaultTests` in `project.yml`
- Added tests: `KeeVaultTests/KDBXParserTests.swift`
  - fixture parse (direct file parse, no UI)
  - Argon2 known vector derivation
  - gzip decompression known data
  - full parse flow parity (`password` vs `compositeKey` path)
- Fixed parser bug in `KeeVault/Models/KDBXParser.swift`:
  - handle payloads where gzip wraps inner header/XML
  - gracefully handle payloads without an explicit inner header

## Unit Test Results (2026-02-14)
| Test | Status |
|------|--------|
| `testParseFixtureFileDirectly` | ✅ PASS |
| `testArgon2KeyDerivationKnownVector` | ✅ PASS |
| `testGunzipKnownCompressedData` | ✅ PASS |
| `testFullParseFlowCompositeKeyPathMatchesPasswordPath` | ✅ PASS |

Command used:
`xcodebuild -scheme KeeVault -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KeeVaultTests test`

## Test Results (2026-02-13)
| Test | Status |
|------|--------|
| `testUnlockShowsErrorForWrongPassword` | ✅ PASS |
| `testUnlockSucceedsWithCorrectPassword` | ❌ FAIL |
| `testEntryDetailCopyActions` | ❌ FAIL |
| `testCanNavigateGroupsThenEntries` | ❌ FAIL |
| `testSearchShowsMatchesAndNoResults` | ❌ FAIL |

## Debugging Notes
**Problem:** Tests fail with "Vault did not unlock" even though password is correct (`testpassword123` verified with keepassxc-cli)

**Root cause identified:**
1. UI tests inject test.kdbx via base64 in launch environment
2. App decodes base64 + writes to temp directory
3. When this fails silently, app falls back to bookmarked vault (wrong password!)

**Fixes applied (Codex session `tide-mist`):**
- Detect UI test mode via `-ui-testing` launch argument
- In UI test mode: NO fallback to bookmarked DBs
- Added `effectiveDatabaseURL` computed property for deterministic behavior
- Added diagnostic logging: `[DatabaseViewModel] ...`

**Next debug steps:**
1. Run tests in Xcode, check Console for `[DatabaseViewModel] ...` logs
2. Trace where base64 decode/write is failing
3. Verify `effectiveDatabaseURL` returns correct temp file path

## Completed
- [x] Phase 1: Xcode project + argon2 C sources
- [x] Phase 2: Services (Keychain, Biometric, Clipboard, DocumentPicker)
- [x] Phase 3: ViewModels (Database, TOTP)
- [x] Phase 4: SwiftUI views (Unlock, GroupList, EntryList, EntryDetail, Search)
- [x] Phase 5-6: AutoFill extension + polish
- [x] A1: Biometric unlock fix
- [x] UI test suite added
- [x] Asset catalog fix (AccentColor + LaunchGlyph)

## Next Steps (after tests pass)
1. Test with real .kdbx file on device
2. App Store readiness audit
3. Privacy manifest, screenshots, metadata

## Tech Stack
- Swift 6, SwiftUI, iOS 17+
- KDBX 4.x parsing, TOTP, AutoFill, Face ID
- Xcode 26.2

## Notes
- Simulator runtimes: iOS 26.2 (iPhone 17 Pro, iPhone Air, etc.)
- Test fixture password: `testpassword123`
- Test fixture has groups: `Social/`, `Work/`
