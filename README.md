# KeeVault

Free, native iOS KeePass password manager. Read-only in v1.

## Features

- Opens `.kdbx` (KDBX 4.x) databases
- Browse groups and entries
- TOTP display & copy
- AutoFill credential provider extension
- Face ID / Touch ID unlock
- iOS 17+, SwiftUI, Swift 6

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open KeeVault.xcodeproj
```

Select an iOS 17+ simulator or device, build and run.

## Usage

1. Pick a `.kdbx` file from Files/iCloud
2. Enter master password to unlock
3. Browse, search, copy credentials

## Project Structure

```
KeeVault/
├── App/              # App entry point
├── Models/           # KDBX parser, crypto, data models
├── Services/         # Keychain, Biometric, Clipboard, CredentialMatcher
├── ViewModels/       # DatabaseViewModel, TOTPViewModel
├── Views/            # SwiftUI views
AutoFillExtension/    # AutoFill Credential Provider
KeeVaultTests/        # Unit tests
KeeVaultUITests/      # UI tests
TestFixtures/         # Test .kdbx fixtures
```

## Docs

- `CHANGELOG.md` — releases, unreleased changes, and TODO
- `AGENTS.md` — context for AI coding agents

## License

MIT
