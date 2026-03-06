import Foundation

enum SharedVaultStore {
    static let appGroupID = "group.com.keevault.shared"

    private static let bookmarkKey = "savedDatabaseBookmark"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func saveBookmark(for url: URL) throws {
        let bookmarkData = try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        sharedDefaults.set(bookmarkData, forKey: bookmarkKey)
    }

    static func loadBookmarkedURL() -> URL? {
        guard let data = sharedDefaults.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            try? saveBookmark(for: url)
        }

        return url
    }

    static func clearBookmark() {
        sharedDefaults.removeObject(forKey: bookmarkKey)
    }
}
