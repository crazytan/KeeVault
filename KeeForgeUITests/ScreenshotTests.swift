import XCTest

@MainActor
final class ScreenshotTests: KeeForgeUITestCase {
    
    func testCaptureScreenshots() throws {
        // Screenshot 1: Unlock screen (before entering password)
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10))
        let unlockScreenshot = XCUIScreen.main.screenshot()
        let unlock = XCTAttachment(screenshot: unlockScreenshot)
        unlock.name = "01-unlock-screen"
        unlock.lifetime = .keepAlways
        add(unlock)
        
        // Unlock the database
        unlockSuccessfully()
        sleep(2)
        
        // Screenshot 2: Database browser / group list
        let browserScreenshot = XCUIScreen.main.screenshot()
        let browser = XCTAttachment(screenshot: browserScreenshot)
        browser.name = "02-database-browser"
        browser.lifetime = .keepAlways
        add(browser)
        
        // Screenshot 3: Open an entry to see detail view
        let opened = openAnyEntry()
        if opened {
            sleep(1)
            let detailScreenshot = XCUIScreen.main.screenshot()
            let detail = XCTAttachment(screenshot: detailScreenshot)
            detail.name = "03-entry-detail"
            detail.lifetime = .keepAlways
            add(detail)
        }
    }
}
