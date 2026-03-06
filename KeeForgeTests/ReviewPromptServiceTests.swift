import XCTest
@testable import KeeForge

@MainActor
final class ReviewPromptServiceTests: XCTestCase {
    private let suiteName = "ReviewPromptServiceTests"
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)!
        ReviewPromptService.defaults = testDefaults
        ReviewPromptService.resetForTesting()
        ReviewPromptService.minimumActions = 7
        ReviewPromptService.minimumDaysBetweenPrompts = 30
    }

    override func tearDown() {
        ReviewPromptService.resetForTesting()
        ReviewPromptService.defaults = .standard
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Action counting

    func testActionCountStartsAtZero() {
        XCTAssertEqual(ReviewPromptService.actionCount, 0)
    }

    func testRecordMeaningfulActionIncrementsCount() {
        ReviewPromptService.recordMeaningfulAction()
        XCTAssertEqual(ReviewPromptService.actionCount, 1)

        ReviewPromptService.recordMeaningfulAction()
        XCTAssertEqual(ReviewPromptService.actionCount, 2)
    }

    // MARK: - shouldPrompt logic

    func testShouldNotPromptBelowThreshold() {
        ReviewPromptService.actionCount = 6
        XCTAssertFalse(ReviewPromptService.shouldPrompt())
    }

    func testShouldPromptAtThreshold() {
        ReviewPromptService.actionCount = 7
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    func testShouldPromptAboveThreshold() {
        ReviewPromptService.actionCount = 15
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    func testShouldNotPromptIfAlreadyPromptedForCurrentVersion() {
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedVersion = ReviewPromptService.currentAppVersion
        XCTAssertFalse(ReviewPromptService.shouldPrompt())
    }

    func testShouldPromptForNewVersion() {
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedVersion = "0.0.0-old"
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    func testShouldNotPromptIfTooSoonSinceLastPrompt() {
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedVersion = "0.0.0-old"
        ReviewPromptService.lastPromptedDate = Date() // just now
        XCTAssertFalse(ReviewPromptService.shouldPrompt())
    }

    func testShouldPromptIfEnoughDaysSinceLastPrompt() {
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedVersion = "0.0.0-old"
        ReviewPromptService.lastPromptedDate = Calendar.current.date(byAdding: .day, value: -31, to: Date())
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    func testShouldPromptIfNoLastPromptedDate() {
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedDate = nil
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    // MARK: - Custom thresholds

    func testCustomMinimumActionsThreshold() {
        ReviewPromptService.minimumActions = 3
        ReviewPromptService.actionCount = 2
        XCTAssertFalse(ReviewPromptService.shouldPrompt())

        ReviewPromptService.actionCount = 3
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    func testCustomMinimumDaysBetweenPrompts() {
        ReviewPromptService.minimumDaysBetweenPrompts = 7
        ReviewPromptService.actionCount = 10
        ReviewPromptService.lastPromptedVersion = "0.0.0-old"
        ReviewPromptService.lastPromptedDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())
        XCTAssertTrue(ReviewPromptService.shouldPrompt())
    }

    // MARK: - resetForTesting

    func testResetClearsAllState() {
        ReviewPromptService.actionCount = 42
        ReviewPromptService.lastPromptedVersion = "1.0.0"
        ReviewPromptService.lastPromptedDate = Date()

        ReviewPromptService.resetForTesting()

        XCTAssertEqual(ReviewPromptService.actionCount, 0)
        XCTAssertNil(ReviewPromptService.lastPromptedVersion)
        XCTAssertNil(ReviewPromptService.lastPromptedDate)
    }
}
