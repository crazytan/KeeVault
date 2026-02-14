import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        Group {
            if viewModel.searchText.isEmpty {
                ContentUnavailableView(
                    "Search Entries",
                    systemImage: "magnifyingglass",
                    description: Text("Type to search by title, username, URL, or notes.")
                )
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("No entries matched \"\(viewModel.searchText)\".")
                )
            } else {
                EntryListView(entries: viewModel.searchResults)
            }
        }
        .navigationTitle("Search")
    }
}
