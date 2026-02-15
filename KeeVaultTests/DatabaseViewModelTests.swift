import XCTest
import SwiftUI
@testable import KeeVault

@MainActor
final class DatabaseViewModelTests: XCTestCase {
    private let fixturePassword = "testpassword123"

    override func setUp() {
        super.setUp()
        DocumentPickerService.clearBookmark()
    }

    override func tearDown() {
        DocumentPickerService.clearBookmark()
        super.tearDown()
    }

    func testInitialStateWithNoBookmarkIsLockedAndNoSavedFile() {
        let vm = DatabaseViewModel()

        XCTAssertState(vm.state, is: .locked)
        XCTAssertFalse(vm.hasSavedFile)
        XCTAssertFalse(vm.canUseBiometrics)
        XCTAssertTrue(vm.searchResults.isEmpty)
    }

    func testSelectFileSetsSavedFileAndResetsToLocked() throws {
        let vm = DatabaseViewModel()
        let url = try fixtureURL()

        vm.selectFile(url)

        XCTAssertTrue(vm.hasSavedFile)
        XCTAssertState(vm.state, is: .locked)
    }

    func testUnlockWithCorrectPasswordTransitionsToUnlocked() async throws {
        let vm = DatabaseViewModel()
        vm.selectFile(try fixtureURL())

        await vm.unlock(password: fixturePassword)

        XCTAssertState(vm.state, is: .unlocked)
        XCTAssertNotNil(vm.rootGroup)
        XCTAssertFalse(vm.rootGroup?.allEntries.isEmpty ?? true)
    }

    func testUnlockWithWrongPasswordTransitionsToError() async throws {
        let vm = DatabaseViewModel()
        vm.selectFile(try fixtureURL())

        await vm.unlock(password: "wrong-password")

        guard case .error(let message) = vm.state else {
            XCTFail("Expected .error state")
            return
        }
        XCTAssertFalse(message.isEmpty)
        XCTAssertNil(vm.rootGroup)
    }

    func testSearchResultsMatchesEntryFieldsCaseInsensitively() async throws {
        let vm = DatabaseViewModel()
        vm.selectFile(try fixtureURL())
        await vm.unlock(password: fixturePassword)

        guard case .unlocked = vm.state else {
            XCTFail("Expected unlocked state before search")
            return
        }

        let allEntries = vm.rootGroup?.allEntries ?? []
        let entryByTitle = allEntries.first(where: { !$0.title.isEmpty })
        let entryByUsername = allEntries.first(where: { !$0.username.isEmpty })
        let entryByURL = allEntries.first(where: { !$0.url.isEmpty })
        let entryByNotes = allEntries.first(where: { !$0.notes.isEmpty })

        if let entryByTitle {
            vm.searchText = mixedCasePrefix(from: entryByTitle.title)
            XCTAssertTrue(vm.searchResults.contains(where: { $0.id == entryByTitle.id }))
        }

        if let entryByUsername {
            vm.searchText = mixedCasePrefix(from: entryByUsername.username)
            XCTAssertTrue(vm.searchResults.contains(where: { $0.id == entryByUsername.id }))
        }

        if let entryByURL {
            vm.searchText = mixedCasePrefix(from: entryByURL.url)
            XCTAssertTrue(vm.searchResults.contains(where: { $0.id == entryByURL.id }))
        }

        if let entryByNotes {
            vm.searchText = mixedCasePrefix(from: entryByNotes.notes)
            XCTAssertTrue(vm.searchResults.contains(where: { $0.id == entryByNotes.id }))
        }

        vm.searchText = ""
        XCTAssertTrue(vm.searchResults.isEmpty)

        vm.searchText = "___no_match___"
        XCTAssertTrue(vm.searchResults.isEmpty)
    }

    func testLockClearsSensitiveAndNavigationState() async throws {
        let vm = DatabaseViewModel()
        vm.selectFile(try fixtureURL())
        await vm.unlock(password: fixturePassword)

        vm.searchText = "query"
        vm.navigationPath.append("pushed")

        vm.lock()

        XCTAssertState(vm.state, is: .locked)
        XCTAssertNil(vm.rootGroup)
        XCTAssertEqual(vm.searchText, "")
        XCTAssertTrue(vm.navigationPath.isEmpty)
    }

    private func fixtureURL() throws -> URL {
        let bundle = Bundle(for: DatabaseViewModelTests.self)
        return try XCTUnwrap(bundle.url(forResource: "test", withExtension: "kdbx"))
    }

    private func mixedCasePrefix(from source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(trimmed.prefix(4))
        guard !prefix.isEmpty else { return source }
        return prefix.uppercased()
    }

    private func XCTAssertState(_ state: DatabaseViewModel.State, is expected: ExpectedState, file: StaticString = #filePath, line: UInt = #line) {
        switch (state, expected) {
        case (.locked, .locked), (.unlocking, .unlocking), (.unlocked, .unlocked):
            return
        case (.error, .error):
            return
        default:
            XCTFail("Unexpected state: \(state)", file: file, line: line)
        }
    }

    private enum ExpectedState {
        case locked
        case unlocking
        case unlocked
        case error
    }
}
