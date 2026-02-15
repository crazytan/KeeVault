import XCTest

final class SearchUITests: KeeVaultUITestCase {
    func testSearchShowsMatchesAndNoResults() {
        unlockSuccessfully()

        guard let searchTerm = firstVisibleEntryLabel() else {
            XCTFail("Could not determine a searchable entry title")
            return
        }

        // Search field should always be visible (displayMode: .always)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Search field did not appear")
        searchField.tap()
        searchField.typeText(searchTerm)

        let matchingResult = app.buttons.matching(identifier: "search.entry.navlink").firstMatch
        XCTAssertTrue(matchingResult.waitForExistence(timeout: 5), "Expected at least one search result")

        searchField.tap()
        searchField.typeText("___unlikely_query___")
        XCTAssertTrue(app.staticTexts["No Results"].waitForExistence(timeout: 5), "Expected no-results state")
    }
}
