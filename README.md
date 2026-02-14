# KeeVault

Free, native iOS KeePassXC-compatible password manager. Version 1 is read-only.

## What It Is

- Opens and decrypts `.kdbx` (KDBX 4.x) databases
- Browses groups and entries
- Supports TOTP display/copy
- Targets iOS 17+ with SwiftUI and Swift 6
- Uses Apple frameworks plus bundled `libargon2` (no third-party runtime deps)

## Build

1. Open `KeeVault.xcodeproj` in Xcode 16+
2. Select an iOS 17+ simulator or device
3. Build and run

## Basic Usage

1. Pick a `.kdbx` file from Files/iCloud
2. Enter master password to unlock
3. Browse groups and entries
4. Copy fields (username/password/TOTP), open URLs, and search entries

## Current State

- ✅ Core parser/crypto/models/TOTP (`KeeVault/Models/`)
- ✅ Services layer (Keychain, Biometric, Clipboard, DocumentPicker)
- ✅ ViewModels (DatabaseViewModel, TOTPViewModel)
- ✅ SwiftUI views (Unlock, GroupList, EntryList, EntryDetail, Search)
- ✅ AutoFill extension
- 🔧 UI tests (1/5 passing, debugging sandbox issue)

## Docs

- `STATUS.md`: current project state + debugging notes
- `AGENTS.md`: architecture + coding-agent guidance
- `TODO.md`: roadmap and next implementation steps

## License

MIT
