import SwiftUI

struct UnlockView: View {
    @Bindable var viewModel: DatabaseViewModel
    @State private var password = ""
    @State private var showFilePicker = false
    @FocusState private var passwordFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("KeeVault")
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
            isPresented: $showFilePicker,
            allowedContentTypes: [.init(filenameExtension: "kdbx")!],
            onCompletion: handleFileSelection
        )
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

            Button(action: unlockWithPassword) {
                Label("Unlock", systemImage: "lock.open.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty || isUnlocking)
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
                showFilePicker = true
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
            
            #if DEBUG
            // Debug state indicator for UI tests
            Text("State: \(String(describing: viewModel.state))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("debug.state.label")
            #endif
        }
    }

    private var noFileSection: some View {
        VStack(spacing: 16) {
            Text("Open a .kdbx database to get started")
                .foregroundStyle(.secondary)

            Button(action: { showFilePicker = true }) {
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
        guard !password.isEmpty else { return }
        Task {
            await viewModel.unlock(password: password)
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

    private func handleFileSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            viewModel.selectFile(url)
            passwordFocused = true
        case .failure:
            break
        }
    }
}
