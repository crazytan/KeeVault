# STATUS.md — KeeVault Project Status

**Last updated:** 2026-02-15

## Current State

✅ **All tests passing** — device testing complete!

| Suite | Status |
|-------|--------|
| Unit tests | 25/25 ✅ |
| UI tests (Simulator) | 5/5 ✅ |
| UI tests (Device) | 5/5 ✅ (iPhone 17 Pro Max) |

## Completed Phases

- [x] Phase 1: Xcode project + argon2 C sources
- [x] Phase 2: Services (Keychain, Biometric, Clipboard, DocumentPicker)
- [x] Phase 3: ViewModels (Database, TOTP)
- [x] Phase 4: SwiftUI views (Unlock, GroupList, EntryList, EntryDetail, Search)
- [x] Phase 5-6: AutoFill extension + polish
- [x] Biometric unlock fix
- [x] UI test suite (5 tests)
- [x] Unit test suite (25 tests)
- [x] Search navigation depth fix
- [x] Real device testing (iPhone 17 Pro Max, iOS 26.3)

## Recent Fixes (2026-02-15)

**Search UI test fix** (`b82075d`):
- Root cause: test typed into search while pushed inside nested groups, but SearchView only swapped at NavigationStack root
- Fix: Added `.onChange(of: viewModel.searchText)` to clear `navigationPath` when search starts
- Test robustness: Re-focus search field after clearing text

**Unit test expansion** (`1d29feb`):
- Added 21 new unit tests covering ViewModels, Services, and Models
- Coverage: DatabaseViewModel, TOTPViewModel, TOTPGenerator, SharedVaultStore, KPGroup/KPEntry utilities

## Next Steps

1. **App Store prep** — privacy manifest, screenshots, metadata
2. **v2 roadmap** — editing, sync, attachments

## Tech Stack

- Swift 6, SwiftUI, iOS 17+
- KDBX 4.x parsing (Argon2, ChaCha20, AES-KDF)
- TOTP generation
- AutoFill extension
- Face ID / Touch ID

## Test Fixture

- Path: `TestFixtures/test.kdbx`
- Password: `testpassword123`
- Groups: `Social/`, `Work/`
