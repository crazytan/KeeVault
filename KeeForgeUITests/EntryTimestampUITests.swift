import XCTest

@MainActor
final class EntryTimestampUITests: KeeForgeUITestCase {

    func testEntryDetailShowsTimestamps() {
        unlockSuccessfully()

        XCTAssertTrue(openAnyEntry(), "Could not open any entry")

        // Scroll down to find the Details section with timestamps (v1.4.0 feature)
        let detailList = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        for _ in 0..<4 {
            detailList.swipeUp()
        }

        // Check for "Created" or "Modified" labels in the Details section
        let createdLabel = app.staticTexts["Created"]
        let modifiedLabel = app.staticTexts["Modified"]

        let hasTimestamp = createdLabel.exists || modifiedLabel.exists
        XCTAssertTrue(hasTimestamp, "Entry detail should show Created or Modified timestamp")
    }
}
