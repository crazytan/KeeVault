import SwiftUI

struct EntryListView: View {
    let entries: [KPEntry]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView.search
        } else {
            List(entries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
        }
    }
}
