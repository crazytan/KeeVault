import XCTest

final class LockUnlockUITests: KeeForgeUITestCase {

    func testManualLockBehavior() {
        unlockSuccessfully()

        // Lock the database
        let lockButton = app.buttons["lock.button"]
        XCTAssertTrue(lockButton.waitForExistence(timeout: 5), "Lock button not found")
        lockButton.tap()

        // Should return to unlock screen
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field did not appear after locking")

        // Wait several seconds and verify no auto-biometric unlock was triggered
        sleep(4)

        XCTAssertTrue(passwordField.exists, "Password field should still be visible — no auto-biometric should trigger after manual lock")
        XCTAssertFalse(
            app.buttons["lock.button"].exists,
            "Lock button should NOT exist — vault should remain locked after manual lock"
        )
    }

    func testFailedThenSuccessfulUnlock() {
        // Multiple wrong passwords show errors
        for attempt in 1...4 {
            unlock(password: "wrong-password-\(attempt)")

            let errorLabel = app.staticTexts["unlock.error.label"]
            XCTAssertTrue(errorLabel.waitForExistence(timeout: 10), "Error should appear on attempt \(attempt)")

            // Brief pause to let any lockout timer start
            sleep(1)
        }

        // After multiple failures, should still be on unlock screen
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.exists, "Password field should still be visible after failed attempts")

        // Now unlock with correct password
        passwordField.tap()
        passwordField.doubleTap()
        sleep(1)
        passwordField.typeText("testpassword123")
        app.buttons["unlock.button"].tap()

        sleep(3)
        XCTAssertTrue(app.buttons["lock.button"].waitForExistence(timeout: 20), "Should unlock after failed attempts")
    }
}
