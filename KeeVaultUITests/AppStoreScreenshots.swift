import XCTest

final class AppStoreScreenshots: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()

        guard let fixtureURL = Bundle(for: AppStoreScreenshots.self).url(forResource: "demo", withExtension: "kdbx") else {
            throw NSError(domain: "Screenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing demo.kdbx"])
        }

        let fixtureData = try Data(contentsOf: fixtureURL)
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UI_TEST_DB_BASE64"] = fixtureData.base64EncodedString()
        app.launchEnvironment["UI_TEST_DB_FILENAME"] = "demo.kdbx"
        app.launchEnvironment["UI_TEST_ENABLE_FAVICONS"] = "1"
        app.launch()
    }

    private func saveScreenshot(_ name: String) {
        sleep(1) // Let animations settle
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func unlock() {
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10))
        passwordField.tap()
        passwordField.typeText("demo")
        app.buttons["unlock.button"].tap()
        XCTAssertTrue(app.buttons["lock.button"].waitForExistence(timeout: 20))
        sleep(2)
    }

    private func tapBackButton() {
        let navBar = app.navigationBars.firstMatch
        if navBar.exists {
            let backButton = navBar.buttons.firstMatch
            if backButton.exists && backButton.isHittable {
                backButton.tap()
                sleep(1)
            }
        }
    }

    func testCaptureAllScreenshots() throws {
        // 1. Unlock screen
        saveScreenshot("01-unlock-screen")

        // Unlock
        unlock()

        // 2. Root view - tap into Root group to see all subgroups
        let rootGroup = app.buttons.matching(identifier: "group.navlink").allElementsBoundByIndex
            .first(where: { $0.exists && $0.isHittable })
        if let rootGroup {
            rootGroup.tap()
            sleep(2)
            saveScreenshot("02-vault-groups")
        }

        // 3. Entry list - tap into Finance group (has TOTP entries)
        let financeGroup = app.buttons.matching(identifier: "group.navlink").allElementsBoundByIndex
            .first(where: { $0.label.contains("Finance") })
        if let financeGroup, financeGroup.waitForExistence(timeout: 5) {
            financeGroup.tap()
            sleep(2)
            saveScreenshot("03-entry-list")

            // 4. Entry detail with TOTP - tap Chase Bank
            let entries = app.buttons.matching(identifier: "entry.navlink").allElementsBoundByIndex
            let totpEntry = entries.first(where: { $0.label.contains("Chase") || $0.label.contains("Coinbase") })
                ?? entries.first(where: { $0.exists && $0.isHittable })
            if let totpEntry {
                totpEntry.tap()
                sleep(1)
                saveScreenshot("04-entry-detail")
            }

            // Go back to Finance
            tapBackButton()
            // Go back to Root
            tapBackButton()
        }

        // 5. Search
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 5) {
            searchField.tap()
            sleep(1)
            searchField.typeText("git")
            sleep(2)
            saveScreenshot("05-search")
            // Dismiss keyboard and search
            if app.buttons["Cancel"].exists {
                app.buttons["Cancel"].tap()
            }
            sleep(1)
        }

        // Go back to top level
        tapBackButton()

        // 6. Settings
        let settingsButton = app.buttons["settings.button"]
        if settingsButton.waitForExistence(timeout: 5) && settingsButton.isHittable {
            settingsButton.tap()
            sleep(1)
            saveScreenshot("06-settings")
        }
    }
}
