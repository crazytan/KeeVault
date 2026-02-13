import SwiftUI

struct GroupListView: View {
    let group: KPGroup
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        List {
            if !group.groups.isEmpty {
                Section("Groups") {
                    ForEach(group.groups) { subgroup in
                        NavigationLink(value: subgroup) {
                            GroupRow(group: subgroup)
                        }
                    }
                }
            }

            if !group.entries.isEmpty {
                Section("Entries") {
                    ForEach(group.entries) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                    }
                }
            }

            if group.groups.isEmpty && group.entries.isEmpty {
                ContentUnavailableView(
                    "Empty Group",
                    systemImage: "folder",
                    description: Text("This group has no entries.")
                )
            }
        }
        .navigationTitle(group.name)
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
