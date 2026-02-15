import XCTest
@testable import KeeVault

final class SharedVaultStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SharedVaultStore.clearBookmark()
    }

    override func tearDown() {
        SharedVaultStore.clearBookmark()
        super.tearDown()
    }

    func testSharedVaultStoreSaveLoadAndClearBookmark() throws {
        let url = try makeTemporaryFileURL(name: "shared-store-test.kdbx")

        try SharedVaultStore.saveBookmark(for: url)
        let loaded = try XCTUnwrap(SharedVaultStore.loadBookmarkedURL())
        XCTAssertEqual(loaded.path, url.path)

        SharedVaultStore.clearBookmark()
        XCTAssertNil(SharedVaultStore.loadBookmarkedURL())
    }

    func testDocumentPickerServiceDelegatesSaveLoadAndClear() throws {
        let url = try makeTemporaryFileURL(name: "doc-picker-test.kdbx")

        try DocumentPickerService.saveBookmark(for: url)
        let loaded = try XCTUnwrap(DocumentPickerService.loadBookmarkedURL())
        XCTAssertEqual(loaded.path, url.path)

        DocumentPickerService.clearBookmark()
        XCTAssertNil(DocumentPickerService.loadBookmarkedURL())
    }

    private func makeTemporaryFileURL(name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: url)
        return url
    }
}
