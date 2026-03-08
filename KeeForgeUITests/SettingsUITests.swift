import XCTest

final class SettingsUITests: KeeForgeUITestCase {

    private func openSettings() {
        let settingsButton = app.buttons["settings.button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button not found")
        settingsButton.tap()
    }

    private func scrollSettingsForm(times: Int = 3) {
        let settingsForm = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        for _ in 0..<times {
            settingsForm.swipeUp()
        }
    }

    func testSettingsPageContent() {
        unlockSuccessfully()
        openSettings()

        // Settings page loads with nav bar and About section
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings nav bar not found")
        XCTAssertTrue(app.staticTexts["About"].waitForExistence(timeout: 3), "About section not found")

        // Sort Direction picker exists
        let settingsForm = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
        settingsForm.swipeUp()
        let sortDirection = app.staticTexts["Sort Direction"]
        XCTAssertTrue(sortDirection.waitForExistence(timeout: 5), "Sort Direction picker not found")

        // Scroll to bottom for feedback button and tip jar
        scrollSettingsForm(times: 3)

        let feedbackLink = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Send Feedback'")).firstMatch
        XCTAssertTrue(feedbackLink.waitForExistence(timeout: 3), "Send Feedback link not found in About section")

        let tipJarHeader = app.staticTexts["Tip Jar"]
        XCTAssertTrue(tipJarHeader.waitForExistence(timeout: 5), "Tip Jar section header not found")
    }

    func testTipJarContent() {
        unlockSuccessfully()
        openSettings()
        scrollSettingsForm(times: 4)

        // Tip Jar section should exist
        let tipJarHeader = app.staticTexts["Tip Jar"]
        XCTAssertTrue(tipJarHeader.waitForExistence(timeout: 5), "Tip Jar header not found")

        // Should show tip tier buttons or "not available" fallback
        let smallTip = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Small' OR label CONTAINS[c] '$1.99' OR label CONTAINS[c] 'tip'")).firstMatch
        let notAvailable = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'not available' OR label CONTAINS[c] 'unavailable'")).firstMatch
        let hasTipContent = smallTip.exists || notAvailable.exists
        XCTAssertTrue(hasTipContent, "Tip Jar should show tip buttons or 'not available' fallback")

        // Should show some descriptive text about tips
        let description = app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] 'support' OR label CONTAINS[c] 'tip' OR label CONTAINS[c] 'free'"
        )).firstMatch
        XCTAssertTrue(description.waitForExistence(timeout: 3), "Tip Jar should have a description")
    }
}
