# STATUS.md — KeeVault Project Status

**Last updated:** 2026-02-17

## Current State

✅ **All tests passing** — App Store prep in progress

| Suite | Status |
|-------|--------|
| Unit tests | 43/43 ✅ |
| UI tests (Simulator) | 6/6 ✅ (includes screenshot test) |
| UI tests (Device) | 5/5 ✅ (iPhone 17 Pro Max) |

## App Store Prep (2026-02-17)

### Done
- [x] App icon — golden key on navy background (replaced placeholder question mark)
- [x] Screenshots captured via UI test (unlock, database browser, entry detail)
- [x] Listing copy drafted (name, subtitle, description, keywords)
- [x] Privacy policy — hosted as GitHub Gist
- [x] Support page — hosted as GitHub Gist
- [x] Analytics decision — Apple built-in only, no third-party SDKs
- [x] TOTP functionality verified (8/8 tests passing)
- [x] ScreenshotTests.swift added to UI test suite

### Remaining
- [ ] Remove "State: locked" debug label from unlock screen
- [ ] Create App Store Connect listing
- [ ] Archive build with release signing
- [ ] Upload to App Store Connect
- [ ] Submit for review

### App Store URLs
- **Privacy Policy:** https://gist.github.com/crazytan/afe07aecf77d2aea2664b4af79d70e0d#file-privacy-policy-md
- **Support:** https://gist.github.com/crazytan/afe07aecf77d2aea2664b4af79d70e0d#file-index-md
- **Support email:** tjtanjia.tan@gmail.com

### Listing Copy
- **Name:** KeeVault
- **Subtitle:** KeePass Password Manager
- **Category:** Utilities
- **Price:** Free
- **Keywords:** keepass,password,manager,kdbx,vault,security,autofill,totp,2fa,biometric

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
- [x] AutoFill credential matching (18 unit tests)
- [x] App icon + screenshots + listing prep

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
