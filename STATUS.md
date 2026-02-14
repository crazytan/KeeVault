# STATUS.md — KeeVault Project Status

**Last updated:** 2026-02-13 10:42pm PST

## Current State
- **Phase:** UI test fixes
- **Build:** ✅ Compiles and runs
- **Tests:** 1/5 passing (wrong password rejection works)
- **Blocker:** UI tests can't unlock vault — see debugging notes below

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
