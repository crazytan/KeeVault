import SwiftUI

@main
struct KeeVaultApp: App {
    @State private var viewModel = DatabaseViewModel()
    @State private var screenProtectionService = ScreenProtectionService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        screenProtectionService.hideShield()
                    case .inactive:
                        if !BiometricService.isBiometricAuthInProgress {
                            screenProtectionService.showShield()
                        }
                    case .background:
                        screenProtectionService.showShield()
                        viewModel.lock()
                    @unknown default:
                        screenProtectionService.showShield()
                    }
                }
        }
    }
}

struct ContentView: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        switch viewModel.state {
        case .locked, .unlocking, .error:
            UnlockView(viewModel: viewModel)
        case .unlocked:
            DatabaseNavigationView(viewModel: viewModel)
        }
    }
}

struct DatabaseNavigationView: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if viewModel.searchText.isEmpty {
                    if let root = viewModel.rootGroup {
                        GroupListView(group: root, viewModel: viewModel)
                    } else {
                        ContentUnavailableView(
                            "Vault Not Loaded",
                            systemImage: "lock.doc",
                            description: Text("Unlock a database to view groups and entries.")
                        )
                    }
                } else {
                    SearchView(viewModel: viewModel)
                }
            }
            .navigationDestination(for: KPGroup.self) { group in
                GroupListView(group: group, viewModel: viewModel)
            }
            .navigationDestination(for: KPEntry.self) { entry in
                EntryDetailView(entry: entry)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.lock()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                    .accessibilityIdentifier("vault.lock.button")
                }
            }
        }
        .onChange(of: viewModel.searchText) { _, newValue in
            if !newValue.isEmpty && !viewModel.navigationPath.isEmpty {
                viewModel.navigationPath = NavigationPath()
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search entries"
        )
    }
}
