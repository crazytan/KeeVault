import XCTest
@testable import KeeVault

@MainActor
final class AutoLockTests: XCTestCase {
    private let fixturePassword = "testpassword123"

    private func makeUnlockedViewModel() async throws -> DatabaseViewModel {
        let vm = DatabaseViewModel()
        vm.selectFile(try fixtureURL())
        await vm.unlock(password: fixturePassword)
        return vm
    }

    func testLockClearsRootGroup() async throws {
        let vm = try await makeUnlockedViewModel()
        XCTAssertNotNil(vm.rootGroup)

        vm.lock()

        XCTAssertNil(vm.rootGroup)
    }

    func testLockClearsCompositeKey() async throws {
        let vm = try await makeUnlockedViewModel()
        XCTAssertNotNil(vm.compositeKey)

        vm.lock()

        XCTAssertNil(vm.compositeKey)
    }

    func testLockSetsStateLocked() async throws {
        let vm = try await makeUnlockedViewModel()
        guard case .unlocked = vm.state else {
            XCTFail("Expected .unlocked before lock()")
            return
        }

        vm.lock()

        guard case .locked = vm.state else {
            XCTFail("Expected .locked after lock()")
            return
        }
    }

    func testLockPreservesSelectedFile() async throws {
        let vm = try await makeUnlockedViewModel()
        XCTAssertTrue(vm.hasSavedFile)

        vm.lock()

        XCTAssertTrue(vm.hasSavedFile)
    }


    func testLockClearsSearchText() async throws {
        let vm = try await makeUnlockedViewModel()
        vm.searchText = "test"

        vm.lock()

        XCTAssertEqual(vm.searchText, "")
    }

    func testLockClearsNavigationPath() async throws {
        let vm = try await makeUnlockedViewModel()
        vm.navigationPath.append("something")

        vm.lock()

        XCTAssertTrue(vm.navigationPath.isEmpty)
    }

    // MARK: - Inactivity Timer

    private var savedAutoLockTimeout: SettingsService.AutoLockTimeout!

    override func setUp() async throws {
        try await super.setUp()
        savedAutoLockTimeout = SettingsService.autoLockTimeout
    }

    override func tearDown() async throws {
        SettingsService.autoLockTimeout = savedAutoLockTimeout
        try await super.tearDown()
    }

    func testInactivityTimerCreatedWithCorrectInterval() async throws {
        SettingsService.autoLockTimeout = .fiveMinutes
        let vm = try await makeUnlockedViewModel()

        XCTAssertNotNil(vm.inactivityTimer)
        XCTAssertEqual(vm.inactivityTimerInterval, 300)
    }

    func testInactivityTimerThirtySecondsInterval() async throws {
        SettingsService.autoLockTimeout = .thirtySeconds
        let vm = try await makeUnlockedViewModel()

        XCTAssertNotNil(vm.inactivityTimer)
        XCTAssertEqual(vm.inactivityTimerInterval, 30)
    }

    func testInactivityTimerCancelledOnLock() async throws {
        SettingsService.autoLockTimeout = .fiveMinutes
        let vm = try await makeUnlockedViewModel()
        XCTAssertNotNil(vm.inactivityTimer)

        vm.lock()

        XCTAssertNil(vm.inactivityTimer)
    }

    func testNeverSettingMeansNoTimer() async throws {
        SettingsService.autoLockTimeout = .never
        let vm = try await makeUnlockedViewModel()

        XCTAssertNil(vm.inactivityTimer)
    }

    func testImmediatelySettingMeansNoForegroundTimer() async throws {
        SettingsService.autoLockTimeout = .immediately
        let vm = try await makeUnlockedViewModel()

        XCTAssertNil(vm.inactivityTimer)
    }

    func testResetInactivityTimerDoesNothingWhenLocked() {
        SettingsService.autoLockTimeout = .fiveMinutes
        let vm = DatabaseViewModel()

        vm.resetInactivityTimer()

        XCTAssertNil(vm.inactivityTimer)
    }

    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: AutoLockTests.self)
        return try XCTUnwrap(bundle.url(forResource: "test", withExtension: "kdbx"))
    }
}
