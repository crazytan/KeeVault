import SwiftUI
import UniformTypeIdentifiers

struct UnlockView: View {
    @Bindable var viewModel: DatabaseViewModel
    @State private var password = ""
    private enum PickerKind { case database, keyFile }
    @State private var activePicker: PickerKind?
    @State private var showPicker = false
    @State private var selectionError: String?
    @State private var keyFileData: Data?
    @State private var keyFileName: String?
    @State private var autoUnlockAttemptedLockCycle: Int?
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("KeeForge")
                .font(.largeTitle.bold())

            if viewModel.hasSavedFile {
                passwordSection
            } else {
                noFileSection
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .accessibilityIdentifier("unlock.error.label")
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: pickerContentTypes,
            onCompletion: { result in
                switch activePicker {
                case .keyFile:
                    handleKeyFileSelection(result)
                default:
                    handleFileSelection(result)
                }
                activePicker = nil
            }
        )
        .onAppear {
            loadUITestKeyFileIfNeeded()
            autoUnlockWithBiometricsIfNeeded()
        }
        .onChange(of: viewModel.lockCycleID) { _, _ in
            autoUnlockWithBiometricsIfNeeded()
        }
        .onChange(of: viewModel.canUseBiometrics) { _, _ in
            autoUnlockWithBiometricsIfNeeded()
        }
    }

    private var passwordSection: some View {
        VStack(spacing: 16) {
            SecureField("Master Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .focused($passwordFocused)
                .submitLabel(.go)
                .onSubmit(unlockWithPassword)
                .padding(.horizontal)
                .accessibilityIdentifier("unlock.password.field")

            keyFileRow

            Button(action: unlockWithPassword) {
                Label("Unlock", systemImage: "lock.open.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty && keyFileData == nil || isUnlocking)
            .padding(.horizontal)
            .accessibilityIdentifier("unlock.button")

            if viewModel.canUseBiometrics {
                Button(action: unlockWithBiometrics) {
                    Label(viewModel.biometricLabel, systemImage: viewModel.biometricIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isUnlocking)
                .padding(.horizontal)
            }

            Button("Choose Different File") {
                selectionError = nil
                activePicker = .database
                showPicker = true
            }
            .font(.footnote)
            .accessibilityIdentifier("unlock.choose-different")

            if isUnlocking {
                ProgressView("Decrypting...")
            }
        }
    }

    private var keyFileRow: some View {
        HStack {
            Label {
                if let keyFileName {
                    Text(keyFileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("None")
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "key.fill")
            }

            Spacer()

            if keyFileData != nil {
                Button {
                    keyFileData = nil
                    keyFileName = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear key file")
                .accessibilityIdentifier("unlock.keyfile.clear")
            }

            Button("Select") {
                selectionError = nil
                activePicker = .keyFile
                showPicker = true
            }
            .font(.subheadline)
            .accessibilityIdentifier("unlock.keyfile.select")
        }
        .padding(.horizontal)
        .accessibilityIdentifier("unlock.keyfile.row")
    }

    private var noFileSection: some View {
        VStack(spacing: 16) {
            Text("Open a .kdbx database to get started")
                .foregroundStyle(.secondary)

            Button(action: {
                selectionError = nil
                activePicker = .database
                showPicker = true
            }) {
                Label("Open Database", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    private var pickerContentTypes: [UTType] {
        switch activePicker {
        case .keyFile:
            DocumentPickerService.keyFilePickerContentTypes
        case .database, .none:
            DocumentPickerService.databasePickerContentTypes
        }
    }

    private var errorMessage: String? {
        if let selectionError {
            return selectionError
        }

        if case .error(let message) = viewModel.state {
            return message
        }

        return nil
    }

    private var isUnlocking: Bool {
        if case .unlocking = viewModel.state { return true }
        return false
    }

    private func unlockWithPassword() {
        let pwd = password.isEmpty ? nil : password
        guard pwd != nil || keyFileData != nil else { return }
        Task {
            await viewModel.unlock(password: password, keyFileData: keyFileData)
            if case .unlocked = viewModel.state {
                password = ""
            }
        }
    }

    private func unlockWithBiometrics() {
        Task {
            await viewModel.unlockWithBiometrics()
        }
    }

    private func autoUnlockWithBiometricsIfNeeded() {
        guard SettingsService.autoUnlockWithFaceID else { return }
        guard viewModel.hasSavedFile else { return }
        guard viewModel.canUseBiometrics else { return }
        guard case .locked = viewModel.state else { return }
        guard !viewModel.didManuallyLock else { return }
        guard autoUnlockAttemptedLockCycle != viewModel.lockCycleID else { return }

        autoUnlockAttemptedLockCycle = viewModel.lockCycleID
        unlockWithBiometrics()
    }

    private func loadUITestKeyFileIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        guard keyFileData == nil else { return }
        let env = ProcessInfo.processInfo.environment
        guard let base64 = env["UI_TEST_KEYFILE_BASE64"], !base64.isEmpty,
              let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return }
        keyFileData = data
        keyFileName = env["UI_TEST_KEYFILE_FILENAME"] ?? "test.key"
    }

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard isSupportedDatabaseSelection(url) else {
                selectionError = "Please select a KeePass .kdbx database."
                return
            }
            selectionError = nil
            viewModel.selectFile(url)
            passwordFocused = true
        case .failure(let error):
            guard !isUserCancelledPicker(error) else { return }
            selectionError = error.localizedDescription
        }
    }

    private func handleKeyFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                keyFileData = try Data(contentsOf: url)
                keyFileName = url.lastPathComponent
            } catch {
                keyFileData = nil
                keyFileName = nil
            }
        case .failure:
            break
        }
    }

    private func isSupportedDatabaseSelection(_ url: URL) -> Bool {
        if DocumentPickerService.isLikelyDatabaseFile(url) {
            return true
        }

        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return DocumentPickerService.isSupportedDatabaseFile(at: url)
    }

    private func isUserCancelledPicker(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.code == NSUserCancelledError
    }
}
