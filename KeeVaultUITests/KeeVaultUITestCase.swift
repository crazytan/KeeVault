import XCTest

class KeeVaultUITestCase: XCTestCase {
    private static let uiTestDBBase64Env = "UI_TEST_DB_BASE64"
    private static let uiTestDBFilenameEnv = "UI_TEST_DB_FILENAME"

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()

        guard let fixtureURL = Bundle(for: KeeVaultUITestCase.self).url(forResource: "test", withExtension: "kdbx") else {
            throw NSError(domain: "KeeVaultUITests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing test.kdbx fixture in test bundle"])
        }

        let fixtureData = try Data(contentsOf: fixtureURL)
        app.launchArguments += ["-ui-testing"]
        app.launchEnvironment[Self.uiTestDBBase64Env] = fixtureData.base64EncodedString()
        app.launchEnvironment[Self.uiTestDBFilenameEnv] = "test.kdbx"
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
        
        // Check for error first
        let errorLabel = app.staticTexts["unlock.error.label"]
        if errorLabel.waitForExistence(timeout: 2) {
            XCTFail("Unlock failed with error: \(errorLabel.label)", file: file, line: line)
            return
        }
        
        // Wait a bit for unlock to complete
        sleep(3)
        
        XCTAssertTrue(
            app.buttons["lock.button"].waitForExistence(timeout: 20),
            "Vault did not unlock",
            file: file,
            line: line
        )
    }

    private func currentListContainer() -> XCUIElement? {
        let candidates: [XCUIElement] = [
            app.collectionViews.firstMatch,
            app.tables.firstMatch,
            app.scrollViews.firstMatch,
        ]

        for candidate in candidates where candidate.exists {
            return candidate
        }

        return nil
    }

    private func firstHittableNavigationLink(identifier: String) -> XCUIElement? {
        let query: XCUIElementQuery
        if let container = currentListContainer() {
            query = container.descendants(matching: .any).matching(identifier: identifier)
        } else {
            query = app.descendants(matching: .any).matching(identifier: identifier)
        }

        return query.allElementsBoundByIndex.first(where: { $0.exists && $0.isHittable })
    }

    private func waitForHittableNavigationLink(identifier: String, timeout: TimeInterval) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let element = firstHittableNavigationLink(identifier: identifier) {
                return element
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline

        return nil
    }

    private func tryRevealEntryInCurrentList() -> XCUIElement? {
        guard let container = currentListContainer(), container.exists else {
            return nil
        }

        for _ in 0..<2 {
            container.swipeUp()
            if let entry = firstHittableNavigationLink(identifier: "entry.navlink") {
                return entry
            }
        }

        for _ in 0..<2 {
            container.swipeDown()
            if let entry = firstHittableNavigationLink(identifier: "entry.navlink") {
                return entry
            }
        }

        return nil
    }

    /// Find a non-empty group to tap. Prefers groups whose label contains a non-zero entry count.
    private func findNonEmptyGroup(timeout: TimeInterval = 3) -> XCUIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let groups = app.buttons.matching(identifier: "group.navlink").allElementsBoundByIndex
                .filter { $0.exists && $0.isHittable }
            // Prefer groups that don't say "0 entries"
            if let nonEmpty = groups.first(where: { !$0.label.contains("0 entries") }) {
                return nonEmpty
            }
            // Fall back to any group
            if let any = groups.first {
                return any
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return nil
    }

    @discardableResult
    func openAnyEntry(maxDepth: Int = 8) -> Bool {
        for _ in 0..<maxDepth {
            if let entry = waitForHittableNavigationLink(identifier: "entry.navlink", timeout: 3) {
                entry.tap()
                return true
            }

            if let entry = tryRevealEntryInCurrentList() {
                entry.tap()
                return true
            }

            if let group = findNonEmptyGroup() {
                group.tap()
                continue
            }

            return false
        }

        return false
    }

    func firstVisibleEntryLabel(navigatingGroups maxDepth: Int = 8) -> String? {
        for _ in 0..<maxDepth {
            if let entry = waitForHittableNavigationLink(identifier: "entry.navlink", timeout: 3) {
                return normalizedEntryTitle(from: entry.label)
            }

            if let entry = tryRevealEntryInCurrentList() {
                return normalizedEntryTitle(from: entry.label)
            }

            if let group = findNonEmptyGroup() {
                group.tap()
                continue
            }

            return nil
        }

        return nil
    }

    private func normalizedEntryTitle(from rawLabel: String) -> String {
        let title = rawLabel
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let title, !title.isEmpty {
            return title
        }
        return rawLabel
    }
}
