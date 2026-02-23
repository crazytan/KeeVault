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

    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: AutoLockTests.self)
        return try XCTUnwrap(bundle.url(forResource: "test", withExtension: "kdbx"))
    }
}
