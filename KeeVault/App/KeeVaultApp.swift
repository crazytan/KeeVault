import SwiftUI

@main
struct KeeVaultApp: App {
    @State private var viewModel = DatabaseViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        viewModel.lock()
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
            .searchable(text: $viewModel.searchText, prompt: "Search entries")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.lock()
                    } label: {
                        Image(systemName: "lock.fill")
                    }
                }
            }
        }
    }
}
