import Foundation
import UniformTypeIdentifiers

enum DocumentPickerService {
    static let kdbxTypeIdentifier = "com.keevault.kdbx"
    static let databaseContentType = UTType(importedAs: kdbxTypeIdentifier)
    static let databasePickerContentTypes: [UTType] = [databaseContentType, .item]
    static let keyFilePickerContentTypes: [UTType] = [.item]
    private static let kdbxMagic = Data([0x03, 0xD9, 0xA2, 0x9A, 0x67, 0xFB, 0x4B, 0xB5])

    static func saveBookmark(for url: URL) throws {
        try SharedVaultStore.saveBookmark(for: url)
    }

    static func loadBookmarkedURL() -> URL? {
        SharedVaultStore.loadBookmarkedURL()
    }

    static func clearBookmark() {
        SharedVaultStore.clearBookmark()
    }

    static func isLikelyDatabaseFile(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "kdbx"
    }

    static func isSupportedDatabaseFile(
        at url: URL,
        headerReader: (URL, Int) throws -> Data = { try CoordinatedFileReader.readDataPrefix(from: $0, byteCount: $1) }
    ) -> Bool {
        if isLikelyDatabaseFile(url) {
            return true
        }

        guard let header = try? headerReader(url, kdbxMagic.count) else {
            return false
        }

        return hasKDBXHeader(header)
    }

    static func hasKDBXHeader(_ data: Data) -> Bool {
        data.starts(with: kdbxMagic)
    }
}
