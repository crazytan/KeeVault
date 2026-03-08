import AuthenticationServices
import CryptoKit
import SwiftUI
import UIKit

@MainActor
final class CredentialProviderViewController: ASCredentialProviderViewController {
    private var serviceIdentifiers: [ASCredentialServiceIdentifier] = []
    private var parsedEntries: [KPEntry] = []
    private var sessionKey: SymmetricKey?
    private var isUnlockInProgress = false
    private var didAttemptAutoBiometricUnlock = false
    private var targetRecordIdentifier: String?
    private var pendingPasskeyRequest: ASPasskeyCredentialRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers
        targetRecordIdentifier = nil
        pendingPasskeyRequest = nil
        didAttemptAutoBiometricUnlock = false
        pendingUnlock = true
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        serviceIdentifiers = [credentialIdentity.serviceIdentifier]
        targetRecordIdentifier = credentialIdentity.recordIdentifier
        pendingPasskeyRequest = nil
        didAttemptAutoBiometricUnlock = false
        // Delay unlock to ensure the view is fully presented,
        // otherwise biometric auth fails with "not interactive".
        pendingUnlock = true
    }

    // MARK: - Passkey credential request (iOS 17+)

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        self.serviceIdentifiers = serviceIdentifiers
        targetRecordIdentifier = nil
        pendingPasskeyRequest = nil
        didAttemptAutoBiometricUnlock = false
        pendingUnlock = true
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        if let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest {
            pendingPasskeyRequest = passkeyRequest
            targetRecordIdentifier = passkeyRequest.credentialIdentity.recordIdentifier
            didAttemptAutoBiometricUnlock = false
            pendingUnlock = true
        } else if let passwordIdentity = credentialRequest.credentialIdentity as? ASPasswordCredentialIdentity {
            prepareInterfaceToProvideCredential(for: passwordIdentity)
        } else {
            cancelRequest(code: .failed)
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        if let passkeyRequest = credentialRequest as? ASPasskeyCredentialRequest {
            providePasskeyWithoutUserInteraction(for: passkeyRequest)
        } else if let passwordIdentity = credentialRequest.credentialIdentity as? ASPasswordCredentialIdentity {
            provideCredentialWithoutUserInteraction(for: passwordIdentity)
        } else {
            extensionContext.cancelRequest(withError: ASExtensionError(.failed))
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if pendingUnlock {
            pendingUnlock = false
            presentUnlockPromptIfNeeded()
        }
    }

    private var pendingUnlock = false

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        guard SettingsService.quickAutoFillEnabled else {
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            return
        }

        guard canUseBiometrics else {
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            return
        }

        let recordIdentifier = credentialIdentity.recordIdentifier

        Task {
            do {
                guard let url = SharedVaultStore.loadBookmarkedURL() else {
                    throw ASExtensionError(.failed)
                }

                let context = try await BiometricService.authenticate(reason: "AutoFill with KeeForge")
                let compositeKey = try KeychainService.retrieveCompositeKey(for: url.path, context: context)
                try await loadEntries(password: nil, compositeKey: compositeKey)

                if let recordIdentifier, let entry = findEntry(byRecordIdentifier: recordIdentifier) {
                    completeRequest(with: entry)
                } else {
                    let matches = CredentialMatcher.matchedEntries(
                        from: parsedEntries,
                        for: [credentialIdentity.serviceIdentifier]
                    )
                    if let entry = matches.first {
                        completeRequest(with: entry)
                    } else {
                        cancelRequest(code: .credentialIdentityNotFound)
                    }
                }
            } catch {
                extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            }
        }
    }

    override func prepareInterfaceForExtensionConfiguration() {
        let error = ASExtensionError(.failed)
        extensionContext.cancelRequest(withError: error)
    }

    // MARK: - Passkey silent auth

    private func providePasskeyWithoutUserInteraction(for request: ASPasskeyCredentialRequest) {
        guard SettingsService.quickAutoFillEnabled else {
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            return
        }

        guard canUseBiometrics else {
            extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            return
        }

        Task {
            do {
                guard let url = SharedVaultStore.loadBookmarkedURL() else {
                    throw ASExtensionError(.failed)
                }

                let context = try await BiometricService.authenticate(reason: "Passkey sign-in with KeeForge")
                let compositeKey = try KeychainService.retrieveCompositeKey(for: url.path, context: context)
                try await loadEntries(password: nil, compositeKey: compositeKey)

                try completePasskeyRequest(request)
            } catch {
                extensionContext.cancelRequest(withError: ASExtensionError(.userInteractionRequired))
            }
        }
    }

    // MARK: - Unlock flow

    private func presentUnlockPromptIfNeeded() {
        guard presentedViewController == nil, !isUnlockInProgress else { return }

        if shouldAutoUnlockWithBiometrics {
            didAttemptAutoBiometricUnlock = true
            unlockWithBiometrics()
            return
        }

        let alert = UIAlertController(
            title: "Unlock KeeForge",
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
                afterUnlock()
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

                let context = try await BiometricService.authenticate(reason: "Unlock KeeForge for AutoFill")
                let compositeKey = try KeychainService.retrieveCompositeKey(for: url.path, context: context)
                try await loadEntries(password: nil, compositeKey: compositeKey)
                afterUnlock()
            } catch {
                showErrorAndRetry(error)
            }
        }
    }

    private func afterUnlock() {
        if let request = pendingPasskeyRequest {
            pendingPasskeyRequest = nil
            do {
                try completePasskeyRequest(request)
            } catch {
                showErrorAndRetry(error)
            }
        } else {
            presentMatchesOrFinish()
        }
    }

    private func loadEntries(password: String?, compositeKey: Data?) async throws {
        guard let url = SharedVaultStore.loadBookmarkedURL() else {
            throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
        }

        let data = try readSecurityScoped(url: url)
        let key = SymmetricKey(size: .bits256)

        let root = try await Task.detached {
            if let password {
                return try KDBXParser.parse(data: data, password: password, sessionKey: key)
            }

            guard let compositeKey else {
                throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
            }

            return try KDBXParser.parse(data: data, compositeKey: compositeKey, sessionKey: key)
        }.value

        self.sessionKey = key

        let allEntries: [KPEntry]
        if let recycleBinID = root.recycleBinUUID {
            allEntries = root.allEntries(excludingGroupID: recycleBinID)
        } else {
            allEntries = root.allEntries
        }
        // Include entries with passwords OR passkeys
        parsedEntries = allEntries.filter { $0.hasPassword || $0.hasPasskey }
    }

    private func readSecurityScoped(url: URL) throws -> Data {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
        }
        defer { url.stopAccessingSecurityScopedResource() }
        return try CoordinatedFileReader.readData(from: url)
    }

    private func presentMatchesOrFinish() {
        // If we have a target recordIdentifier from QuickType, jump directly to that entry
        if let recordIdentifier = targetRecordIdentifier, let entry = findEntry(byRecordIdentifier: recordIdentifier) {
            completeRequest(with: entry)
            return
        }

        let matches = CredentialMatcher.matchedEntries(from: parsedEntries, for: serviceIdentifiers)

        if matches.isEmpty || serviceIdentifiers.isEmpty {
            presentSearchView(entries: parsedEntries)
            return
        }

        if matches.count == 1, let entry = matches.first {
            completeRequest(with: entry)
            return
        }

        presentEntryPicker(entries: matches)
    }

    private func findEntry(byRecordIdentifier recordIdentifier: String) -> KPEntry? {
        guard let targetUUID = UUID(uuidString: recordIdentifier) else { return nil }
        return parsedEntries.first { $0.id == targetUUID }
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

    private func presentSearchView(entries: [KPEntry]) {
        let searchView = AutoFillSearchView(
            entries: entries,
            onSelect: { [weak self] entry in
                self?.dismiss(animated: false) {
                    self?.completeRequest(with: entry)
                }
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: false) {
                    self?.cancelRequest(code: .userCanceled)
                }
            }
        )
        let host = UIHostingController(rootView: searchView)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    // MARK: - Complete password request

    private func completeRequest(with entry: KPEntry) {
        let user = entry.username.isEmpty ? entry.title : entry.username
        guard !user.isEmpty else {
            cancelRequest(code: .failed)
            return
        }

        let decryptedPassword = (try? entry.password.decrypt(using: sessionKey!)) ?? ""
        parsedEntries = []
        sessionKey = nil
        targetRecordIdentifier = nil
        pendingPasskeyRequest = nil
        let credential = ASPasswordCredential(user: user, password: decryptedPassword)
        extensionContext.completeRequest(withSelectedCredential: credential, completionHandler: nil)
    }

    // MARK: - Complete passkey request

    private func completePasskeyRequest(_ request: ASPasskeyCredentialRequest) throws {
        let identity = request.credentialIdentity as! ASPasskeyCredentialIdentity
        let recordIdentifier = identity.recordIdentifier

        guard let recordIdentifier,
              let entry = findEntry(byRecordIdentifier: recordIdentifier),
              let passkey = entry.passkeyCredential
        else {
            cancelRequest(code: .credentialIdentityNotFound)
            return
        }

        guard let credentialIDData = passkey.credentialIDData,
              let userHandleData = passkey.userHandleData
        else {
            cancelRequest(code: .failed)
            return
        }

        let privateKey = try PasskeyCrypto.privateKey(fromPEM: passkey.privateKeyPEM)
        let clientDataHash = request.clientDataHash

        let (authenticatorData, signature) = try PasskeyCrypto.signAssertion(
            relyingPartyID: identity.relyingPartyIdentifier,
            clientDataHash: clientDataHash,
            privateKey: privateKey
        )

        let credential = ASPasskeyAssertionCredential(
            userHandle: userHandleData,
            relyingParty: identity.relyingPartyIdentifier,
            signature: signature,
            clientDataHash: clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: credentialIDData
        )

        parsedEntries = []
        sessionKey = nil
        targetRecordIdentifier = nil
        pendingPasskeyRequest = nil
        extensionContext.completeAssertionRequest(using: credential)
    }

    // MARK: - Error handling

    private func cancelRequest(code: ASExtensionError.Code) {
        parsedEntries = []
        sessionKey = nil
        targetRecordIdentifier = nil
        pendingPasskeyRequest = nil
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
