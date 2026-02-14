import XCTest

final class NavigationUITests: KeeVaultUITestCase {
    func testCanNavigateGroupsThenEntries() {
        unlockSuccessfully()

        let firstGroup = app.buttons.matching(identifier: "group.navlink").firstMatch
        XCTAssertTrue(firstGroup.waitForExistence(timeout: 10), "No group rows found")
        firstGroup.tap()

        let firstEntry = app.buttons.matching(identifier: "entry.navlink").firstMatch
        if !firstEntry.waitForExistence(timeout: 5) {
            let nestedGroup = app.buttons.matching(identifier: "group.navlink").firstMatch
            XCTAssertTrue(nestedGroup.waitForExistence(timeout: 5), "No entry reachable after opening a group")
            nestedGroup.tap()
        }

        let reachableEntry = app.buttons.matching(identifier: "entry.navlink").firstMatch
        XCTAssertTrue(reachableEntry.waitForExistence(timeout: 5), "No entry found while navigating groups")
        reachableEntry.tap()

        let anyCopyButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "entry.copy.")).firstMatch
        XCTAssertTrue(anyCopyButton.waitForExistence(timeout: 5), "Entry detail did not open")
    }
}
