# AGENTS.md

Context for AI coding agents working on KeeVault.

## Overview

- iOS KeePass password manager (KDBX 4.x, read-only in v1)
- Swift 6, SwiftUI, iOS 17+, MVVM with `@Observable`
- Build system: XcodeGen (`project.yml` → `.xcodeproj`)
- Crypto: Argon2Swift (SPM), custom AES/ChaCha20/HMAC in `KDBXCrypto.swift`

## Stable Core

These files are tested and should only change for real bugs:

- `KDBXParser.swift` — KDBX 4.x parsing, decryption, XML extraction
- `KDBXCrypto.swift` — AES, ChaCha20, HMAC, gzip, key derivation
- `Entry.swift`, `Group.swift` — data models
- `TOTPGenerator.swift` — RFC 6238

## Conventions

- `@Observable`, not `ObservableObject`/`@Published`
- `NavigationStack` + `NavigationPath`, not `NavigationView`
- Swift 6 strict concurrency (`Sendable` correctness)
- Crypto/parsing off main thread
- No force unwraps outside tests
- No unnecessary dependencies

## Security

- Composite key stored in Keychain with biometric access control
- Never store raw master password
- Auto-lock on background, clear sensitive state
- Clipboard auto-expires (30s)
- No analytics, telemetry, or network calls

## Build & Test

```bash
xcodegen generate
xcodebuild build -project KeeVault.xcodeproj -scheme KeeVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild test -project KeeVault.xcodeproj -scheme KeeVault -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

If simulator gets stuck with "preflight checks" error:
```bash
xcrun simctl shutdown all && xcrun simctl erase <UDID>
```

## Test Fixture

`TestFixtures/test.kdbx` (password: `testpassword123`) contains:
- Social/Twitter (with 2 history entries), Social/Discord (with TOTP)
- Work/Email, Work/GitHub (with TOTP)
