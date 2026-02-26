import AuthenticationServices
import UIKit

@MainActor
final class CredentialProviderViewController: ASCredentialProviderViewController {
    private var serviceIdentifiers: [ASCredentialServiceIdentifier] = []
    private var parsedEntries: [KPEntry] = []
    private var isUnlockInProgress = false
    private var didAttemptAutoBiometricUnlock = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers
        didAttemptAutoBiometricUnlock = false
        presentUnlockPromptIfNeeded()
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        serviceIdentifiers = [credentialIdentity.serviceIdentifier]
        didAttemptAutoBiometricUnlock = false
        presentUnlockPromptIfNeeded()
    }

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
    }

    override func prepareInterfaceForExtensionConfiguration() {
        let error = ASExtensionError(.failed)
        extensionContext.cancelRequest(withError: error)
    }

    private func presentUnlockPromptIfNeeded() {
        guard presentedViewController == nil, !isUnlockInProgress else { return }

        if shouldAutoUnlockWithBiometrics {
            didAttemptAutoBiometricUnlock = true
            unlockWithBiometrics()
            return
        }

        let alert = UIAlertController(
            title: "Unlock KeeVault",
            message: "Enter your master password or use biometrics.",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "Master Password"
            field.isSecureTextEntry = true
            field.textContentType = .password
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelRequest(code: .userCanceled)
        })

        alert.addAction(UIAlertAction(title: "Unlock", style: .default) { [weak self, weak alert] _ in
            guard let self, let password = alert?.textFields?.first?.text, !password.isEmpty else {
                self?.presentUnlockPromptIfNeeded()
                return
            }
            self.unlockWithPassword(password)
        })

        if canUseBiometrics {
            alert.addAction(UIAlertAction(title: biometricActionTitle, style: .default) { [weak self] _ in
                self?.unlockWithBiometrics()
            })
        }

        present(alert, animated: true)
    }

    private var shouldAutoUnlockWithBiometrics: Bool {
        guard !didAttemptAutoBiometricUnlock else { return false }
        guard SettingsService.autoUnlockWithFaceID else { return false }
        return canUseBiometrics
    }

    private var canUseBiometrics: Bool {
        guard BiometricService.isAvailable else { return false }
        guard let databasePath = SharedVaultStore.loadBookmarkedURL()?.path else { return false }
        return KeychainService.hasStoredKey(for: databasePath)
    }

    private var biometricActionTitle: String {
        switch BiometricService.availableType {
        case .faceID: "Use Face ID"
        case .touchID: "Use Touch ID"
        case .none: "Use Biometrics"
        }
    }

    private func unlockWithPassword(_ password: String) {
        isUnlockInProgress = true
        Task {
            defer { isUnlockInProgress = false }
            do {
                try await loadEntries(password: password, compositeKey: nil)
                presentMatchesOrFinish()
            } catch {
                showErrorAndRetry(error)
            }
        }
    }

    private func unlockWithBiometrics() {
        isUnlockInProgress = true
        Task {
            defer { isUnlockInProgress = false }
            do {
                guard let url = SharedVaultStore.loadBookmarkedURL() else {
                    throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
                }

                let context = try await BiometricService.authenticate(reason: "Unlock KeeVault for AutoFill")
                let compositeKey = try KeychainService.retrieveCompositeKey(for: url.path, context: context)
                try await loadEntries(password: nil, compositeKey: compositeKey)
                presentMatchesOrFinish()
            } catch {
                showErrorAndRetry(error)
            }
        }
    }

    private func loadEntries(password: String?, compositeKey: Data?) async throws {
        guard let url = SharedVaultStore.loadBookmarkedURL() else {
            throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
        }

        let data = try readSecurityScoped(url: url)

        let root = try await Task.detached {
            if let password {
                return try KDBXParser.parse(data: data, password: password)
            }

            guard let compositeKey else {
                throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
            }

            return try KDBXParser.parse(data: data, compositeKey: compositeKey)
        }.value

        let allEntries: [KPEntry]
        if let recycleBinID = root.recycleBinUUID {
            allEntries = root.allEntries(excludingGroupID: recycleBinID)
        } else {
            allEntries = root.allEntries
        }
        parsedEntries = allEntries.filter { !$0.password.isEmpty }
    }

    private func readSecurityScoped(url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try Data(contentsOf: url)
    }

    private func presentMatchesOrFinish() {
        let matches = CredentialMatcher.matchedEntries(from: parsedEntries, for: serviceIdentifiers)

        if matches.isEmpty {
            cancelRequest(code: .credentialIdentityNotFound)
            return
        }

        if matches.count == 1, let entry = matches.first {
            completeRequest(with: entry)
            return
        }

        presentEntryPicker(entries: matches)
    }

    private func presentEntryPicker(entries: [KPEntry]) {
        let alert = UIAlertController(title: "Choose Credential", message: nil, preferredStyle: .alert)

        for entry in entries.prefix(10) {
            let title = entry.title.isEmpty ? entry.username : entry.title
            let subtitle = entry.username.isEmpty ? "Use credential" : entry.username
            let label = "\(title) (\(subtitle))"

            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.completeRequest(with: entry)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelRequest(code: .userCanceled)
        })

        present(alert, animated: true)
    }

    private func completeRequest(with entry: KPEntry) {
        let user = entry.username.isEmpty ? entry.title : entry.username
        guard !user.isEmpty else {
            cancelRequest(code: .failed)
            return
        }

        let credential = ASPasswordCredential(user: user, password: entry.password)
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    private func cancelRequest(code: ASExtensionError.Code) {
        extensionContext.cancelRequest(withError: ASExtensionError(code))
    }

    private func showErrorAndRetry(_ error: Error) {
        let alert = UIAlertController(
            title: "Unlock Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            self?.presentUnlockPromptIfNeeded()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelRequest(code: .userCanceled)
        })

        present(alert, animated: true)
    }
}
