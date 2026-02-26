import SwiftUI

struct GroupListView: View {
    let group: KPGroup
    @Bindable var viewModel: DatabaseViewModel
    @State private var showSettings = false

    private var visibleGroups: [KPGroup] {
        let recycleBinID = viewModel.rootGroup?.recycleBinUUID
        if let recycleBinID {
            return group.groups.filter { $0.id != recycleBinID }
        }
        return group.groups
    }

    var body: some View {
        Group {
            if viewModel.searchText.isEmpty {
                List {
                    if !visibleGroups.isEmpty {
                        Section("Groups") {
                            ForEach(viewModel.sortedGroups(visibleGroups)) { subgroup in
                                NavigationLink(value: subgroup) {
                                    GroupRow(group: subgroup)
                                }
                                .accessibilityIdentifier("group.navlink")
                            }
                        }
                    }

                    if !group.entries.isEmpty {
                        Section("Entries") {
                            ForEach(viewModel.sortedEntries(group.entries)) { entry in
                                NavigationLink(value: entry) {
                                    EntryRow(entry: entry)
                                }
                                .accessibilityIdentifier("entry.navlink")
                            }
                        }
                    }

                    if visibleGroups.isEmpty && group.entries.isEmpty {
                        ContentUnavailableView(
                            "Empty Group",
                            systemImage: "folder",
                            description: Text("This group has no entries.")
                        )
                    }
                }
                .navigationTitle(group.name)
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 12) {
                            Button {
                                viewModel.lock()
                            } label: {
                                Image(systemName: "lock")
                            }
                            .accessibilityIdentifier("lock.button")

                            Menu {
                                Picker("Sort By", selection: $viewModel.sortOrder) {
                                    ForEach(DatabaseViewModel.SortOrder.allCases, id: \.self) { order in
                                        Text(order.rawValue).tag(order)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .accessibilityIdentifier("sort.menu")

                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .accessibilityIdentifier("settings.button")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
                }
            } else {
                SearchView(viewModel: viewModel)
            }
        }
        .searchable(
            text: $viewModel.searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search entries"
        )
    }
}

struct GroupRow: View {
    let group: KPGroup

    var body: some View {
        HStack {
            Image(systemName: group.systemIconName)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading) {
                Text(group.name)
                    .font(.body)
                Text("\(group.allEntries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct EntryRow: View {
    let entry: KPEntry

    var body: some View {
        HStack {
            Image(systemName: entry.systemIconName)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading) {
                Text(entry.title.isEmpty ? "(untitled)" : entry.title)
                    .font(.body)
                if !entry.username.isEmpty {
                    Text(entry.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if entry.totpConfig != nil {
                Image(systemName: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}
