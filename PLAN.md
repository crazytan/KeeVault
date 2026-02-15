# KeeVault Unit Test Expansion Plan

## Scope
Expand `KeeVaultTests` coverage for essential app logic outside `KDBXParser` by adding deterministic XCTest unit tests for:
- ViewModels (`DatabaseViewModel`, `TOTPViewModel`)
- Services and service wrappers where deterministic in tests (`SharedVaultStore`, `DocumentPickerService`)
- Core utility/model behavior (`TOTPGenerator`, `KPGroup`, `KPEntry`, navigation/hash conformance)

## Existing Test Pattern Baseline
Reference style from `KeeVaultTests/KDBXParserTests.swift`:
- `XCTestCase` with focused, behavior-named tests
- Real fixture-based integration where appropriate
- Private helpers for fixture loading and shared assertions
- Deterministic assertions over concrete expected outcomes

## Testable Units Missing Coverage

### 1) `DatabaseViewModel`
File: `KeeVault/ViewModels/DatabaseViewModel.swift`

#### Behaviors to test
- Initial/default state behavior (with no saved bookmark)
- `selectFile(_:)` updates selected database and state reset
- `searchResults`:
  - empty query returns empty
  - case-insensitive matching across `title`, `username`, `url`, `notes`
- `unlock(password:)` success path using known fixture/password
- `unlock(password:)` wrong password path sets `.error`
- `lock()` clears sensitive/UI state (`rootGroup`, key-derived state, search, navigation path, state)
- `canUseBiometrics` returns `false` when no DB path is selected

#### Dependencies / isolation
- Uses static services (`DocumentPickerService`, `BiometricService`, `KeychainService`) and parser/crypto statics.
- No dependency injection seam currently exists; avoid refactoring stable core.
- Determinism approach:
  - Clear bookmark key before each test (`DocumentPickerService.clearBookmark()`) to prevent ambient state leakage.
  - Use local fixture file URL from test bundle + `selectFile(_:)` to avoid relying on previously saved app state.
  - For unlock tests, rely on test fixture (`test.kdbx`) and known password.

#### Mocking/stubbing need
- Ideal future seam: protocol-backed adapters for biometric/keychain/document store.
- For this phase: no mocks added; tests target deterministic paths only.

### 2) `TOTPViewModel`
File: `KeeVault/ViewModels/TOTPViewModel.swift`

#### Behaviors to test
- Initialization computes initial code/remaining/progress
- `period` passthrough from config
- `start()` and `stop()` lifecycle safety (timer start/stop idempotence and no crash)
- Basic invariants after refresh lifecycle:
  - non-placeholder code for valid secret
  - `secondsRemaining` in valid range
  - `progress` in valid range

#### Dependencies / isolation
- Depends on `Timer` and wall clock (`Date()`).
- Determinism strategy: assert invariants/ranges instead of exact second values.

#### Mocking/stubbing need
- Ideal future seam: injectable clock/timer scheduler.
- For this phase: avoid brittle time-based exact assertions.

### 3) `TOTPGenerator`
File: `KeeVault/Models/TOTPGenerator.swift`

#### Behaviors to test
- RFC 6238 known-vector generation (at least SHA1)
- Invalid Base32 secret yields placeholder `"------"`
- `secondsRemaining(period:date:)` boundary behavior (exact boundary and mid-period)
- Base32 decoding normalization support (lowercase, spaces, padding)

#### Dependencies / isolation
- Pure deterministic logic; no mocking needed.

### 4) `SharedVaultStore` + `DocumentPickerService`
Files:
- `KeeVault/Services/SharedVaultStore.swift`
- `KeeVault/Services/DocumentPickerService.swift`

#### Behaviors to test
- Save bookmark then load returns expected URL path
- Clear bookmark removes persisted URL
- `DocumentPickerService` wrapper delegates expected behavior

#### Dependencies / isolation
- Uses `UserDefaults(suiteName:)` and bookmark APIs.
- Determinism strategy:
  - Use temporary local file URLs created in test.
  - Clear bookmark state before/after tests.

#### Mocking/stubbing need
- None required for deterministic local-file bookmark cycle.

### 5) `KPGroup`, `KPEntry`, and Hash/Navigation Conformances
Files:
- `KeeVault/Models/Group.swift`
- `KeeVault/Models/Entry.swift`
- `KeeVault/Extensions/NavigationConformances.swift`

#### Behaviors to test
- `KPGroup.allEntries` recursive flattening order/content
- `systemIconName` mappings for known/default icon IDs (`KPEntry`, `KPGroup`)
- Hashable/equality semantics based on `id` for `KPEntry` and `KPGroup`

#### Dependencies / isolation
- Pure model logic; no mocking needed.

## Units Deferred (OS/Device-coupled, no seam)

### `KeychainService`
- Calls Security framework APIs directly; deterministic tests would need an injectable Security client shim.

### `BiometricService`
- Depends on `LAContext` policy evaluation and device biometry availability.

### `ClipboardService`, `HapticService`, `ScreenProtectionService`
- Rely on UIKit runtime/device state; unit tests without seams would be brittle/non-deterministic.

## Implementation Plan
1. Add new XCTest files under `KeeVaultTests/`:
   - `DatabaseViewModelTests.swift`
   - `TOTPViewModelTests.swift`
   - `TOTPGeneratorTests.swift`
   - `SharedVaultStoreTests.swift`
   - `ModelLogicTests.swift`
2. Reuse fixture-loading helper pattern from parser tests for DB unlock tests.
3. Keep each test focused and deterministic (no external network/device state).
4. Run requested suite command:
   - `xcodebuild -scheme KeeVault -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:KeeVaultTests test`
5. Fix failing tests if any.
6. Update `STATUS.md` with:
   - new unit test count
   - summary of added coverage areas
   - execution date/time and command

## Risk Notes
- Static dependencies in `DatabaseViewModel` and service layer limit deep mocking in this phase.
- If bookmark APIs behave differently in simulator, fallback is to keep wrapper tests minimal and isolated with cleanup.
