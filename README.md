# KeeVault

Free, native iOS KeePassXC-compatible password manager. Version 1 is read-only.

## What It Is

- Opens and decrypts `.kdbx` (KDBX 4.x) databases
- Browses groups and entries
- Supports TOTP display/copy
- AutoFill extension for system-wide password autofill
- Face ID / Touch ID unlock
- Targets iOS 17+ with SwiftUI and Swift 6

## Build

1. Open `KeeVault.xcodeproj` in Xcode 16+
2. Select an iOS 17+ simulator or device
3. Build and run

## Usage

1. Pick a `.kdbx` file from Files/iCloud
2. Enter master password to unlock
3. Browse groups and entries
4. Copy fields (username/password/TOTP), open URLs, and search entries

## Test Status

| Suite | Status |
|-------|--------|
| Unit tests | 25/25 ✅ |
| UI tests | 5/5 ✅ |

## Project Structure

```
KeeVault/
├── App/              # App entry point
├── Models/           # KDBX parser, crypto, data models
├── Services/         # Keychain, Biometric, Clipboard, DocumentPicker
├── ViewModels/       # DatabaseViewModel, TOTPViewModel
├── Views/            # SwiftUI views
└── argon2/           # Bundled libargon2 C sources

KeeVaultAutoFill/     # AutoFill extension
KeeVaultTests/        # Unit tests
KeeVaultUITests/      # UI tests
TestFixtures/         # Test .kdbx files
```

## Docs

- `STATUS.md` — current project state + recent changes
- `AGENTS.md` — architecture notes for AI coding agents

## License

MIT
