import XCTest
@testable import KeeVault

final class KDBXParserTests: XCTestCase {
    private let fixturePassword = "testpassword123"

    func testParseFixtureFileDirectly() throws {
        let data = try fixtureData()

        let root = try KDBXParser.parse(data: data, password: fixturePassword)
        let groupNames = Set(allGroupNames(in: root))

        XCTAssertTrue(groupNames.contains("Social"))
        XCTAssertTrue(groupNames.contains("Work"))
    }

    func testArgon2KeyDerivationKnownVector() throws {
        let derived = try Argon2.hash(
            password: Data("password".utf8),
            salt: Data("somesalt".utf8),
            timeCost: 2,
            memoryCost: 65_536,
            parallelism: 1,
            hashLength: 32,
            variant: .d
        )

        XCTAssertEqual(
            derived.hexString,
            "955e5d5b163a1b60bba35fc36d0496474fba4f6b59ad53628666f07fb2f93eaf"
        )
    }

    func testGunzipKnownCompressedData() throws {
        let compressedBase64 = "H4sIAAAAAAAC//NOTQ1LLM0pUUgvzavKLFAoS00uyS9SKEiszMlPTOHKycxLNQIAX50mACQAAAA="
        let compressed = try XCTUnwrap(Data(base64Encoded: compressedBase64))

        let decompressed = try KDBXCrypto.gunzip(compressed)
        let text = String(data: decompressed, encoding: .utf8)

        XCTAssertEqual(text, "KeeVault gunzip vector payload\nline2")
    }

    func testFullParseFlowCompositeKeyPathMatchesPasswordPath() throws {
        let data = try fixtureData()

        let parsedWithPassword = try KDBXParser.parse(data: data, password: fixturePassword)
        let compositeKey = KDBXCrypto.compositeKey(password: fixturePassword)
        let parsedWithCompositeKey = try KDBXParser.parse(data: data, compositeKey: compositeKey)

        XCTAssertEqual(
            allGroupNames(in: parsedWithPassword),
            allGroupNames(in: parsedWithCompositeKey)
        )
        XCTAssertEqual(parsedWithPassword.allEntries.count, parsedWithCompositeKey.allEntries.count)
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: KDBXParserTests.self)
        let fixtureURL = try XCTUnwrap(bundle.url(forResource: "test", withExtension: "kdbx"))
        return try Data(contentsOf: fixtureURL)
    }

    private func allGroupNames(in root: KPGroup) -> [String] {
        root.groups.flatMap { group in
            [group.name] + allGroupNames(in: group)
        }
    }
}
