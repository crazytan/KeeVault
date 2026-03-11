import XCTest

@MainActor
final class UnlockFlowUITests: KeeForgeUITestCase {
    func testUnlockShowsErrorForWrongPassword() {
        unlock(password: "wrong-password")
        XCTAssertTrue(app.staticTexts["unlock.error.label"].waitForExistence(timeout: 10))
    }

    func testUnlockSucceedsWithCorrectPassword() {
        unlockSuccessfully()
    }

    func testChooseDifferentFileShowsDocumentPicker() {
        // Unlock first, then lock to get back to unlock screen with "Choose Different File"
        unlockSuccessfully()

        let lockButton = app.buttons["lock.button"]
        XCTAssertTrue(lockButton.waitForExistence(timeout: 5), "Lock button not found")
        lockButton.tap()

        // Wait for unlock screen
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field did not appear after locking")

        // Tap "Choose Different File"
        let chooseDifferent = app.buttons["unlock.choose-different"]
        XCTAssertTrue(chooseDifferent.waitForExistence(timeout: 5), "Choose Different File button not found")
        chooseDifferent.tap()

        // Document picker should appear — check for Cancel button or Browse nav bar
        let cancelButton = app.buttons["Cancel"]
        let browseNav = app.navigationBars.matching(NSPredicate(format: "label CONTAINS[c] 'Browse' OR label CONTAINS[c] 'Recents'")).firstMatch
        let pickerAppeared = cancelButton.waitForExistence(timeout: 5) || browseNav.waitForExistence(timeout: 3)
        XCTAssertTrue(pickerAppeared, "Document picker did not appear after tapping Choose Different File")
    }
}
