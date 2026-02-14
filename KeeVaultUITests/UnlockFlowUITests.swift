import XCTest

final class UnlockFlowUITests: KeeVaultUITestCase {
    func testUnlockShowsErrorForWrongPassword() {
        unlock(password: "wrong-password")
        XCTAssertTrue(app.staticTexts["unlock.error.label"].waitForExistence(timeout: 10))
    }

    func testUnlockSucceedsWithCorrectPassword() {
        unlockSuccessfully()
    }
}
