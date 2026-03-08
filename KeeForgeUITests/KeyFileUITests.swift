import XCTest

// MARK: - Key file UI controls (uses default test.kdbx)

final class KeyFileUITests: KeeForgeUITestCase {

    private func findKeyFileSelect() -> XCUIElement? {
        // Try direct identifier first
        let direct = app.buttons["unlock.keyfile.select"]
        if direct.waitForExistence(timeout: 3) { return direct }

        // Scroll and retry
        app.swipeUp()
        if direct.waitForExistence(timeout: 3) { return direct }

        // Try matching by label "Select"
        let byLabel = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Select'")).firstMatch
        if byLabel.waitForExistence(timeout: 3) { return byLabel }

        return nil
    }

    func testKeyFileSelectOpensDocumentPicker() {
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field not found")

        guard let selectButton = findKeyFileSelect() else {
            XCTFail("Key file Select button not found")
            return
        }
        selectButton.tap()

        // Document picker should appear (presented as a sheet/modal)
        let documentPicker = app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS[c] 'doc' OR label CONTAINS[c] 'Browse' OR label CONTAINS[c] 'Recents'")).firstMatch
        let pickerAppeared = documentPicker.waitForExistence(timeout: 5)

        // On simulator, the document picker may present differently — also check for any modal
        if !pickerAppeared {
            // Check if any new sheet/navigation appeared after tapping
            let browseButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Browse'")).firstMatch
            let cancelButton = app.buttons["Cancel"]
            let hasModal = browseButton.waitForExistence(timeout: 3) || cancelButton.exists
            XCTAssertTrue(hasModal, "Document picker did not appear after tapping Select key file")
        }
    }
}

// MARK: - Key file unlock end-to-end (uses demo-keyfile.kdbx + demo-keyfile.key)

final class KeyFileUnlockUITests: KeeForgeUITestCase {

    override var databaseFixtureName: String { "demo-keyfile" }
    override var keyFileFixtureName: String? { "demo-keyfile" }
    override var keyFileFixtureExtension: String { "key" }

    /// Wait for key file injection to complete (name label appears in key file row).
    private func waitForKeyFileInjection() {
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field did not appear")

        // Wait for key file name to appear, confirming env var injection worked
        let keyFileLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'demo-keyfile'")).firstMatch
        XCTAssertTrue(keyFileLabel.waitForExistence(timeout: 10), "Key file name did not appear — injection may have failed")
    }

    private func unlockWithKeyFile() {
        waitForKeyFileInjection()

        // demo-keyfile.kdbx requires password "demo" + key file
        let passwordField = app.secureTextFields["unlock.password.field"]
        passwordField.tap()
        passwordField.typeText("demo")

        let unlockButton = app.buttons["unlock.button"]
        XCTAssertTrue(unlockButton.waitForExistence(timeout: 5), "Unlock button not found")
        unlockButton.tap()

        XCTAssertTrue(
            app.buttons["lock.button"].waitForExistence(timeout: 20),
            "Vault did not unlock with password + key file"
        )
    }

    func testKeyFileUnlockShowsEntries() {
        unlockWithKeyFile()

        // After unlock, entries should be visible (navigate into a group if needed)
        let entryLabel = firstVisibleEntryLabel()
        XCTAssertNotNil(entryLabel, "No entries visible after key file unlock")
    }
}
