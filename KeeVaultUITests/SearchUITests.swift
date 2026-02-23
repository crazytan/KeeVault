import XCTest

final class SearchUITests: KeeVaultUITestCase {
    private func debugSearchHierarchy(_ stage: String, file: StaticString = #filePath, line: UInt = #line) {
        let promptMatchCount = app.descendants(matching: .any).matching(identifier: "Search entries").count
        let searchFieldCount = app.searchFields.count
        let textFieldCount = app.textFields.count
        let searchButtonCount = app.buttons.matching(identifier: "Search").count
        let navBarCount = app.navigationBars.count
        let tableCount = app.tables.count
        let collectionCount = app.collectionViews.count
        let scrollViewCount = app.scrollViews.count
        let navSearchButtonCount = app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Search'")).count

        let summary = """
        [SearchUITests] \(stage)
          navigationBars=\(navBarCount) tables=\(tableCount) collectionViews=\(collectionCount) scrollViews=\(scrollViewCount)
          searchFields=\(searchFieldCount) textFields=\(textFieldCount)
          buttons[Search]=\(searchButtonCount) navButtons[label~Search]=\(navSearchButtonCount) descendants[id=Search entries]=\(promptMatchCount)
        """
        NSLog("%@", summary)

        let attachment = XCTAttachment(string: "[\(stage)]\n\(app.debugDescription)")
        attachment.name = "Search hierarchy - \(stage)"
        attachment.lifetime = .keepAlways
        add(attachment)

        if !app.navigationBars.firstMatch.exists {
            XCTFail("Navigation bar is missing at \(stage)", file: file, line: line)
        }
    }

    private func findSearchInput(timeout: TimeInterval) -> XCUIElement? {
        let candidates: [XCUIElement] = [
            app.searchFields["Search entries"],
            app.searchFields.firstMatch,
            app.textFields["Search entries"],
            app.textFields.firstMatch
        ]

        for candidate in candidates where candidate.waitForExistence(timeout: timeout) {
            return candidate
        }

        return nil
    }

    private func tapSearchButtonIfPresent(timeout: TimeInterval) -> Bool {
        let candidates: [XCUIElement] = [
            app.navigationBars.buttons["Search"].firstMatch,
            app.buttons["Search"].firstMatch,
            app.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Search'")).firstMatch,
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Search'")).firstMatch
        ]

        for button in candidates where button.waitForExistence(timeout: timeout) {
            button.tap()
            return true
        }

        return false
    }

    private func activateSearchField(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        debugSearchHierarchy("before-search-activation", file: file, line: line)

        if let searchInput = findSearchInput(timeout: 1) {
            searchInput.tap()
            return searchInput
        }

        if tapSearchButtonIfPresent(timeout: 1), let searchInput = findSearchInput(timeout: 1) {
            searchInput.tap()
            return searchInput
        }

        let swipeTargets: [XCUIElement] = [
            app.collectionViews.firstMatch,
            app.tables.firstMatch,
            app.scrollViews.firstMatch,
            app.navigationBars.firstMatch
        ]

        for _ in 0..<3 {
            for target in swipeTargets where target.waitForExistence(timeout: 1) {
                target.swipeDown()

                if tapSearchButtonIfPresent(timeout: 1), let searchInput = findSearchInput(timeout: 1) {
                    searchInput.tap()
                    return searchInput
                }

                if let searchInput = findSearchInput(timeout: 1) {
                    searchInput.tap()
                    return searchInput
                }
            }
        }

        debugSearchHierarchy("search-field-missing-after-fallback", file: file, line: line)
        let fallbackField = app.searchFields.firstMatch
        XCTAssertTrue(
            fallbackField.waitForExistence(timeout: 5),
            "Search field did not appear",
            file: file,
            line: line
        )
        fallbackField.tap()
        return fallbackField
    }

    private func clearSearchField(_ searchField: XCUIElement) {
        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
            return
        }

        let currentValue = (searchField.value as? String) ?? ""
        if currentValue.isEmpty || currentValue == "Search entries" {
            return
        }

        let deleteSequence = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        searchField.typeText(deleteSequence)
    }

    func testSearchStaysActiveWhileTyping() {
        unlockSuccessfully()

        let searchField = activateSearchField()

        // Type one character at a time and verify the search field keeps focus
        searchField.typeText("T")
        sleep(1)

        // Search field should still exist and be active (not dismissed)
        let activeSearchField = findSearchInput(timeout: 3)
        XCTAssertNotNil(activeSearchField, "Search field disappeared after typing first character")

        // Type more characters
        activeSearchField?.typeText("wi")
        sleep(1)

        // Verify results appeared (we have a "Twitter" entry)
        let resultsCountLabel = app.staticTexts["search.results.count"]
        if resultsCountLabel.waitForExistence(timeout: 5) {
            XCTAssertNotEqual(resultsCountLabel.label, "results:0", "Expected search results for 'Twi'")
        }

        // Verify search field is still active
        let stillActive = findSearchInput(timeout: 2)
        XCTAssertNotNil(stillActive, "Search field dismissed during typing")
    }

    func testSearchShowsMatchesAndNoResults() {
        unlockSuccessfully()

        guard let searchTerm = firstVisibleEntryLabel() else {
            XCTFail("Could not determine a searchable entry title")
            return
        }

        let searchField = activateSearchField()
        searchField.typeText(searchTerm + "\n")

        let resultsCountLabel = app.staticTexts["search.results.count"]
        XCTAssertTrue(resultsCountLabel.waitForExistence(timeout: 5), "Search results count label did not appear")
        XCTAssertFalse(resultsCountLabel.label == "results:0", "Expected at least one search result")

        searchField.tap()
        clearSearchField(searchField)

        let refocusedSearchField = activateSearchField()
        refocusedSearchField.typeText("___unlikely_query___\n")

        let timeout = Date().addingTimeInterval(5)
        var didReachZeroResults = false
        repeat {
            if resultsCountLabel.label == "results:0" {
                didReachZeroResults = true
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < timeout

        XCTAssertTrue(didReachZeroResults, "Expected no-results state")
    }
}
