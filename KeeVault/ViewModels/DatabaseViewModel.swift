import Foundation
import OSLog
import SwiftUI

@MainActor @Observable
final class DatabaseViewModel {
    private static let uiTestDBPathEnv = "UI_TEST_DB_PATH"
    private static let uiTestDBBase64Env = "UI_TEST_DB_BASE64"
    private static let uiTestDBFilenameEnv = "UI_TEST_DB_FILENAME"
    private static let uiTestingLaunchArg = "-ui-testing"
    private static let logger = Logger(subsystem: "KeeVault", category: "DatabaseViewModel")
    private static let kdbxMagic: [UInt8] = [0x03, 0xD9, 0xA2, 0x9A, 0x67, 0xFB, 0x4B, 0xB5]

    enum State: Sendable {
        case locked
        case unlocking
        case unlocked
        case error(String)
    }

    enum SortOrder: String, CaseIterable, Sendable {
        case title = "Title"
        case createdDate = "Date Created"
        case modifiedDate = "Date Modified"
    }

    private(set) var state: State = .locked
    private(set) var lockCycleID = 0
    private(set) var rootGroup: KPGroup?
    private(set) var inactivityTimer: Timer?
    private(set) var inactivityTimerInterval: TimeInterval?
    var searchText = "" {
        didSet { resetInactivityTimer() }
    }
    var isSearchActive = false {
        didSet { resetInactivityTimer() }
    }
    var navigationPath = NavigationPath() {
        didSet { resetInactivityTimer() }
    }
    var sortOrder: SortOrder {
        didSet { Self.saveSortOrder(sortOrder) }
    }

    private var databaseURL: URL?
    private(set) var compositeKey: Data?
    private let isUITesting: Bool

    var hasSavedFile: Bool {
        effectiveDatabaseURL != nil
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
        let candidates: [KPEntry]
        if let recycleBinID = root.recycleBinUUID {
            candidates = root.allEntries(excludingGroupID: recycleBinID)
        } else {
            candidates = root.allEntries
        }
        return candidates.filter { entry in
            entry.title.lowercased().contains(query) ||
            entry.username.lowercased().contains(query) ||
            entry.url.lowercased().contains(query) ||
            entry.notes.lowercased().contains(query)
        }
    }

    private var databasePath: String? {
        effectiveDatabaseURL?.path
    }

    private var effectiveDatabaseURL: URL? {
        if let databaseURL {
            return databaseURL
        }
        if isUITesting {
            return nil
        }
        return DocumentPickerService.loadBookmarkedURL()
    }

    init() {
        let launchArgs = ProcessInfo.processInfo.arguments
        isUITesting = launchArgs.contains(Self.uiTestingLaunchArg)
        sortOrder = Self.loadSortOrder()

        if isUITesting {
            Self.diagnostic("init: running in UI test mode")
            if let uiTestURL = Self.uiTestDatabaseURL() {
                databaseURL = uiTestURL
                Self.diagnostic("init: UI test DB URL resolved to \(uiTestURL.path)")
            } else if let uiTestPath = ProcessInfo.processInfo.environment[Self.uiTestDBPathEnv], !uiTestPath.isEmpty {
                let url = URL(fileURLWithPath: uiTestPath)
                databaseURL = url
                Self.diagnostic("init: using UI_TEST_DB_PATH \(url.path)")
            } else {
                databaseURL = nil
                Self.diagnostic("init: no UI test DB env set; leaving databaseURL nil")
            }
            return
        }

        databaseURL = DocumentPickerService.loadBookmarkedURL()
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
        beginNewLockCycle()
        state = .locked
    }

    func unlock(password: String) async {
        guard let url = effectiveDatabaseURL else {
            state = .error("No database file selected")
            return
        }

        if isUITesting {
            let exists = FileManager.default.fileExists(atPath: url.path)
            Self.diagnostic("unlock: using database URL \(url.path), exists=\(exists)")
        }

        state = .unlocking

        do {
            let data = try readSecurityScoped(url: url)
            if isUITesting {
                let hasMagic = data.starts(with: Self.kdbxMagic)
                Self.diagnostic("unlock: read \(data.count) bytes, kdbxMagic=\(hasMagic)")
            }
            let compositeKey = KDBXCrypto.compositeKey(password: password)

            let root = try await Task.detached {
                try KDBXParser.parse(data: data, password: password)
            }.value

            self.rootGroup = root
            self.compositeKey = compositeKey
            state = .unlocked
            startInactivityTimer()

            // Store key for biometric unlock
            if BiometricService.isAvailable {
                try? KeychainService.storeCompositeKey(compositeKey, for: url.path)
            }
        } catch {
            if isUITesting {
                Self.diagnostic("unlock: failed with error '\(error.localizedDescription)'")
            }
            state = .error(error.localizedDescription)
        }
    }

    func unlockWithBiometrics() async {
        guard let url = effectiveDatabaseURL else {
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
            startInactivityTimer()
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func lock() {
        cancelInactivityTimer()
        beginNewLockCycle()
        state = .locked
        rootGroup = nil
        compositeKey = nil
        searchText = ""
        navigationPath = NavigationPath()
    }

    // MARK: - Inactivity Timer

    func startInactivityTimer() {
        cancelInactivityTimer()
        let timeout = SettingsService.autoLockTimeout
        guard let seconds = timeout.seconds, seconds > 0 else { return }
        inactivityTimerInterval = seconds
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.lock()
            }
        }
    }

    func cancelInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        inactivityTimerInterval = nil
    }

    func resetInactivityTimer() {
        guard case .unlocked = state else { return }
        startInactivityTimer()
    }

    private func beginNewLockCycle() {
        lockCycleID += 1
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

    private static func uiTestDatabaseURL() -> URL? {
        let env = ProcessInfo.processInfo.environment
        guard let base64 = env[uiTestDBBase64Env], !base64.isEmpty else {
            diagnostic("uiTestDatabaseURL: \(uiTestDBBase64Env) missing or empty")
            return nil
        }
        diagnostic("uiTestDatabaseURL: found base64 payload (\(base64.count) chars)")

        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else {
            diagnostic("uiTestDatabaseURL: failed to decode base64")
            return nil
        }
        diagnostic("uiTestDatabaseURL: decoded \(data.count) bytes")

        let requestedFilename = env[uiTestDBFilenameEnv] ?? "ui-test.kdbx"
        let safeFilename = (requestedFilename as NSString).lastPathComponent
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeFilename, isDirectory: false)

        do {
            try data.write(to: url, options: .atomic)
            let readBack = try Data(contentsOf: url)
            let hasMagic = readBack.starts(with: kdbxMagic)
            diagnostic("uiTestDatabaseURL: wrote and re-read \(readBack.count) bytes to \(url.path), kdbxMagic=\(hasMagic)")
            return url
        } catch {
            diagnostic("uiTestDatabaseURL: failed writing temp DB '\(error.localizedDescription)'")
            return nil
        }
    }

    func sortedGroups(_ groups: [KPGroup]) -> [KPGroup] {
        switch sortOrder {
        case .title:
            return groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .createdDate:
            return groups.sorted { ($0.creationTime ?? .distantPast) < ($1.creationTime ?? .distantPast) }
        case .modifiedDate:
            return groups.sorted { ($0.lastModificationTime ?? .distantPast) > ($1.lastModificationTime ?? .distantPast) }
        }
    }

    func sortedEntries(_ entries: [KPEntry]) -> [KPEntry] {
        switch sortOrder {
        case .title:
            return entries.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .createdDate:
            return entries.sorted { ($0.creationTime ?? .distantPast) < ($1.creationTime ?? .distantPast) }
        case .modifiedDate:
            return entries.sorted { ($0.lastModificationTime ?? .distantPast) > ($1.lastModificationTime ?? .distantPast) }
        }
    }

    private static let sortOrderKey = "KeeVault.sortOrder"

    private static func loadSortOrder() -> SortOrder {
        guard let raw = UserDefaults.standard.string(forKey: sortOrderKey) else { return .title }
        return SortOrder(rawValue: raw) ?? .title
    }

    private static func saveSortOrder(_ order: SortOrder) {
        UserDefaults.standard.set(order.rawValue, forKey: sortOrderKey)
    }

    private static func diagnostic(_ message: String) {
        logger.notice("\(message, privacy: .public)")
        print("[DatabaseViewModel] \(message)")
    }
}
