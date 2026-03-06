import Foundation
import StoreKit

@MainActor
enum ReviewPromptService {
    private enum Key {
        static let actionCount = "KeeForge.reviewPrompt.actionCount"
        static let lastPromptedVersion = "KeeForge.reviewPrompt.lastPromptedVersion"
        static let lastPromptedDate = "KeeForge.reviewPrompt.lastPromptedDate"
    }

    nonisolated(unsafe) static var minimumActions = 7
    nonisolated(unsafe) static var minimumDaysBetweenPrompts = 30
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static var actionCount: Int {
        get { defaults.integer(forKey: Key.actionCount) }
        set { defaults.set(newValue, forKey: Key.actionCount) }
    }

    static var lastPromptedVersion: String? {
        get { defaults.string(forKey: Key.lastPromptedVersion) }
        set { defaults.set(newValue, forKey: Key.lastPromptedVersion) }
    }

    static var lastPromptedDate: Date? {
        get { defaults.object(forKey: Key.lastPromptedDate) as? Date }
        set { defaults.set(newValue, forKey: Key.lastPromptedDate) }
    }

    static func recordMeaningfulAction() {
        actionCount += 1
    }

    static func shouldPrompt() -> Bool {
        guard actionCount >= minimumActions else { return false }
        guard lastPromptedVersion != currentAppVersion else { return false }

        if let lastDate = lastPromptedDate {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            guard daysSince >= minimumDaysBetweenPrompts else { return false }
        }

        return true
    }

    static func requestReviewIfAppropriate() {
        recordMeaningfulAction()

        guard shouldPrompt() else { return }

        lastPromptedVersion = currentAppVersion
        lastPromptedDate = Date()
        actionCount = 0

        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    static func resetForTesting() {
        defaults.removeObject(forKey: Key.actionCount)
        defaults.removeObject(forKey: Key.lastPromptedVersion)
        defaults.removeObject(forKey: Key.lastPromptedDate)
    }
}
