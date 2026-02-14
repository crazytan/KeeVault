import XCTest

class KeeVaultUITestCase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        guard let fixtureURL = Bundle(for: KeeVaultUITestCase.self).url(forResource: "test", withExtension: "kdbx") else {
            throw NSError(domain: "KeeVaultUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing test.kdbx fixture in test bundle"])
        }

        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment["UI_TEST_DB_PATH"] = fixtureURL.path
        app.launch()
    }

    func unlock(password: String) {
        let passwordField = app.secureTextFields["unlock.password.field"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10), "Password field did not appear")

        passwordField.tap()
        passwordField.typeText(password)
        app.buttons["unlock.button"].tap()
    }

    func unlockSuccessfully(file: StaticString = #filePath, line: UInt = #line) {
        unlock(password: "testpassword123")
        XCTAssertTrue(
            app.buttons["vault.lock.button"].waitForExistence(timeout: 20),
            "Vault did not unlock",
            file: file,
            line: line
        )
    }

    @discardableResult
    func openAnyEntry(maxDepth: Int = 5) -> Bool {
        for _ in 0..<maxDepth {
            let entry = app.buttons.matching(identifier: "entry.navlink").firstMatch
            if entry.waitForExistence(timeout: 3) {
                entry.tap()
                return true
            }

            let group = app.buttons.matching(identifier: "group.navlink").firstMatch
            if group.waitForExistence(timeout: 3) {
                group.tap()
                continue
            }

            return false
        }

        return false
    }

    func firstVisibleEntryLabel(navigatingGroups maxDepth: Int = 5) -> String? {
        for _ in 0..<maxDepth {
            let entry = app.buttons.matching(identifier: "entry.navlink").firstMatch
            if entry.waitForExistence(timeout: 3) {
                let title = entry.label.components(separatedBy: "\n").first
                return (title?.isEmpty == false) ? title : entry.label
            }

            let group = app.buttons.matching(identifier: "group.navlink").firstMatch
            if group.waitForExistence(timeout: 3) {
                group.tap()
                continue
            }

            return nil
        }

        return nil
    }
}
