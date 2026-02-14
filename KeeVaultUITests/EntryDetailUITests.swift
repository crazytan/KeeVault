import XCTest

final class EntryDetailUITests: KeeVaultUITestCase {
    func testEntryDetailCopyActions() {
        unlockSuccessfully()

        XCTAssertTrue(openAnyEntry(), "Could not find an entry to open")

        let copyQuery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "entry.copy."))
        XCTAssertTrue(copyQuery.firstMatch.waitForExistence(timeout: 5), "No copy actions found in entry detail")

        let tapCount = min(copyQuery.count, 3)
        XCTAssertGreaterThan(tapCount, 0)
        for index in 0..<tapCount {
            copyQuery.element(boundBy: index).tap()
        }

        let revealButton = app.buttons["entry.password.reveal"]
        if revealButton.exists {
            revealButton.tap()
            let passwordCopy = app.buttons["entry.copy.password"]
            if passwordCopy.exists {
                passwordCopy.tap()
            }
        }

        let urlCopy = app.buttons["entry.copy.url"]
        if urlCopy.exists {
            urlCopy.tap()
        }
    }
}
