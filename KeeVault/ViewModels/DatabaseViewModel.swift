import Foundation
import SwiftUI

@MainActor @Observable
final class DatabaseViewModel {
    enum State: Sendable {
        case locked
        case unlocking
        case unlocked
        case error(String)
    }

    private(set) var state: State = .locked
    private(set) var rootGroup: KPGroup?
    var searchText = ""
    var navigationPath = NavigationPath()

    private var databaseURL: URL?
    private var compositeKey: Data?

    var hasSavedFile: Bool {
        databaseURL != nil || DocumentPickerService.loadBookmarkedURL() != nil
    }

    var canUseBiometrics: Bool {
        guard let path = databasePath else { return false }
        return BiometricService.isAvailable && KeychainService.hasStoredKey(for: path)
    }

    var biometricLabel: String {
        switch BiometricService.availableType {
        case .faceID: "Unlock with Face ID"
        case .touchID: "Unlock with Touch ID"
        case .none: "Biometrics unavailable"
        }
    }

    var biometricIcon: String {
        switch BiometricService.availableType {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .none: "lock.fill"
        }
    }

    var searchResults: [KPEntry] {
        guard !searchText.isEmpty, let root = rootGroup else { return [] }
        let query = searchText.lowercased()
        return root.allEntries.filter { entry in
            entry.title.lowercased().contains(query) ||
            entry.username.lowercased().contains(query) ||
            entry.url.lowercased().contains(query) ||
            entry.notes.lowercased().contains(query)
        }
    }

    private var databasePath: String? {
        databaseURL?.path ?? DocumentPickerService.loadBookmarkedURL()?.path
    }

    init() {
        if let uiTestPath = ProcessInfo.processInfo.environment["UI_TEST_DB_PATH"], !uiTestPath.isEmpty {
            databaseURL = URL(fileURLWithPath: uiTestPath)
        } else {
            databaseURL = DocumentPickerService.loadBookmarkedURL()
        }
    }

    func selectFile(_ url: URL) {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        if hasSecurityScope {
            try? DocumentPickerService.saveBookmark(for: url)
        }
        databaseURL = url
        state = .locked
    }

    func unlock(password: String) async {
        guard let url = databaseURL ?? DocumentPickerService.loadBookmarkedURL() else {
            state = .error("No database file selected")
            return
        }

        state = .unlocking

        do {
            let data = try readSecurityScoped(url: url)
            let compositeKey = KDBXCrypto.compositeKey(password: password)

            let root = try await Task.detached {
                try KDBXParser.parse(data: data, password: password)
            }.value

            self.rootGroup = root
            self.compositeKey = compositeKey
            state = .unlocked

            // Store key for biometric unlock
            if BiometricService.isAvailable {
                try? KeychainService.storeCompositeKey(compositeKey, for: url.path)
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func unlockWithBiometrics() async {
        guard let url = databaseURL ?? DocumentPickerService.loadBookmarkedURL() else {
            state = .error("No database file selected")
            return
        }

        state = .unlocking

        do {
            let context = try await BiometricService.authenticate(reason: "Unlock your password database")
            let compositeKey = try KeychainService.retrieveCompositeKey(for: url.path, context: context)

            let data = try readSecurityScoped(url: url)

            let root = try await Task.detached {
                try KDBXParser.parse(data: data, compositeKey: compositeKey)
            }.value

            self.rootGroup = root
            self.compositeKey = compositeKey
            state = .unlocked
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func lock() {
        rootGroup = nil
        compositeKey = nil
        searchText = ""
        navigationPath = NavigationPath()
        state = .locked
    }

    private func readSecurityScoped(url: URL) throws -> Data {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }
}
