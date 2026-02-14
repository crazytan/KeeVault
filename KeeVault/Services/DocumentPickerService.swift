import Foundation

enum DocumentPickerService {
    static func saveBookmark(for url: URL) throws {
        try SharedVaultStore.saveBookmark(for: url)
    }

    static func loadBookmarkedURL() -> URL? {
        SharedVaultStore.loadBookmarkedURL()
    }

    static func clearBookmark() {
        SharedVaultStore.clearBookmark()
    }
}
