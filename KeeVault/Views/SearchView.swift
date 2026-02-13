import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: DatabaseViewModel

    var body: some View {
        EntryListView(entries: viewModel.searchResults)
            .navigationTitle("Search")
    }
}
