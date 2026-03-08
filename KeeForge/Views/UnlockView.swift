import SwiftUI
import UniformTypeIdentifiers

struct UnlockView: View {
    @Bindable var viewModel: DatabaseViewModel
    @State private var password = ""
    private enum PickerKind { case database, keyFile }
    @State private var activePicker: PickerKind?
    @State private var showPicker = false
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

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: [.item],
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
                activePicker = .database
                showPicker = true
            }
            .font(.footnote)

            if isUnlocking {
                ProgressView("Decrypting...")
            }

            if case .error(let message) = viewModel.state {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
                    .accessibilityIdentifier("unlock.error.label")
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

            Button(action: { activePicker = .database; showPicker = true }) {
                Label("Open Database", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
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

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.pathExtension.lowercased() == "kdbx" else { return }
            viewModel.selectFile(url)
            passwordFocused = true
        case .failure:
            break
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
}
