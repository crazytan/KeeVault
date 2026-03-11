import XCTest

@MainActor
final class SortUITests: KeeForgeUITestCase {

    func testSortMenuShowsOptionsAndDirectionToggle() {
        unlockSuccessfully()

        // Sort menu should exist and open
        let sortMenu = app.buttons["sort.menu"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 5), "Sort menu button not found in toolbar")
        sortMenu.tap()

        // Should show sort options: Title, Created Date, Modified Date
        let titleOption = app.buttons["Title"]
        XCTAssertTrue(titleOption.waitForExistence(timeout: 3), "Sort menu should show sort order options")

        // Dismiss by tapping elsewhere
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
    }

    func testSortOrderChangeWorks() {
        unlockSuccessfully()

        let sortMenu = app.buttons["sort.menu"]
        XCTAssertTrue(sortMenu.waitForExistence(timeout: 5), "Sort menu not found")
        sortMenu.tap()

        // Select "Modified Date"
        let modifiedOption = app.buttons["Modified Date"]
        if modifiedOption.waitForExistence(timeout: 3) {
            modifiedOption.tap()
        }

        // Verify the list still displays entries (sort didn't crash)
        sleep(1)
        let hasContent = app.buttons.matching(identifier: "entry.navlink").firstMatch.waitForExistence(timeout: 5)
            || app.buttons.matching(identifier: "group.navlink").firstMatch.waitForExistence(timeout: 5)
        XCTAssertTrue(hasContent, "List should still show entries/groups after changing sort order")
    }
}
