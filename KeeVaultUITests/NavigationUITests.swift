import XCTest

final class NavigationUITests: KeeVaultUITestCase {
    func testCanNavigateGroupsThenEntries() {
        unlockSuccessfully()

        XCTAssertTrue(openAnyEntry(maxDepth: 8), "No entry found while navigating groups")

        let anyCopyButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "entry.copy.")).firstMatch
        XCTAssertTrue(anyCopyButton.waitForExistence(timeout: 5), "Entry detail did not open")
    }
}
