import XCTest
@testable import KeeVault

final class KDBXParserTests: XCTestCase {
    private let fixturePassword = "testpassword123"

    // MARK: - Fixture Expectations

    /// Expected entries in test.kdbx — ground truth from keepassxc-cli / pykeepass
    private struct Expected {
        struct EntryData {
            let group: String
            let title: String
            let username: String
            let password: String
            let url: String
            let notes: String
            let hasTOTP: Bool
            let totpSecret: String?
        }

        static let entries: [EntryData] = [
            EntryData(
                group: "Social", title: "Twitter",
                username: "testuser", password: "twitterpass123",
                url: "https://twitter.com", notes: "",
                hasTOTP: false, totpSecret: nil
            ),
            EntryData(
                group: "Social", title: "Discord",
                username: "gamer123", password: "discordpass!@#",
                url: "https://discord.com", notes: "Gaming account",
                hasTOTP: true, totpSecret: "GEZDGNBVGY3TQOJQ"
            ),
            EntryData(
                group: "Social", title: "Offline Key",
                username: "", password: "physical-key-backup",
                url: "", notes: "Stored in safe deposit box\nBox #42\nBank: Chase\n" + String(repeating: "A", count: 200),
                hasTOTP: false, totpSecret: nil
            ),
            EntryData(
                group: "Social", title: "Public Profile",
                username: "crazytan", password: "",
                url: "https://keybase.io/crazytan", notes: "",
                hasTOTP: false, totpSecret: nil
            ),
            EntryData(
                group: "Work", title: "Email",
                username: "work@example.com", password: "workpass456",
                url: "https://mail.example.com", notes: "",
                hasTOTP: false, totpSecret: nil
            ),
            EntryData(
                group: "Work", title: "GitHub",
                username: "devuser", password: "githubpass789",
                url: "https://github.com", notes: "",
                hasTOTP: true, totpSecret: "JBSWY3DPEHPK3PXP"
            ),
            EntryData(
                group: "Internal", title: "日本語テスト 🔑",
                username: "ユーザー", password: "pässwörd!@#¥",
                url: "https://example.jp", notes: "",
                hasTOTP: false, totpSecret: nil
            ),
        ]

        static let groups = ["Social", "Work", "Empty", "Internal"]
    }

    // MARK: - Structure Tests

    func testParseFindsAllGroups() throws {
        let root = try parseFixture()
        let groupNames = Set(allGroupNames(in: root))

        for name in Expected.groups {
            XCTAssertTrue(groupNames.contains(name), "Missing group: \(name)")
        }
    }

    func testParseFindsCorrectEntryCount() throws {
        let root = try parseFixture()
        XCTAssertEqual(root.allEntries.count, Expected.entries.count,
                       "Expected \(Expected.entries.count) entries, got \(root.allEntries.count)")
    }

    // MARK: - No Duplicates (History entries must be excluded)

    func testNoDuplicateEntries() throws {
        // test.kdbx has 2 history versions inside the Twitter entry.
        // Without proper History filtering, the parser would return 6 entries instead of 4.
        let root = try parseFixture()
        let entries = root.allEntries

        XCTAssertEqual(entries.count, Expected.entries.count,
                       "Expected \(Expected.entries.count) entries but got \(entries.count) — history entries may be leaking")

        // Each title+username combo should appear exactly once
        let keys = entries.map { "\($0.title)|\($0.username)" }
        let uniqueKeys = Set(keys)
        XCTAssertEqual(keys.count, uniqueKeys.count,
                       "Duplicate entries found: \(keys)")
    }

    // MARK: - Entry Field Tests

    func testAllEntryUsernames() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertEqual(entry?.username, expected.username,
                           "\(expected.title): username mismatch")
        }
    }

    func testAllEntryPasswords() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertEqual(entry?.password, expected.password,
                           "\(expected.title): password mismatch — inner stream decryption may be broken")
        }
    }

    func testAllEntryURLs() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertEqual(entry?.url, expected.url,
                           "\(expected.title): URL mismatch")
        }
    }

    func testAllEntryNotes() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertEqual(entry?.notes, expected.notes,
                           "\(expected.title): notes mismatch")
        }
    }

    // MARK: - TOTP Tests

    func testEntriesWithTOTPHaveConfig() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries where expected.hasTOTP {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertNotNil(entry?.totpConfig,
                            "\(expected.title): expected TOTP config but got nil")
            XCTAssertEqual(entry?.totpConfig?.secret, expected.totpSecret,
                           "\(expected.title): TOTP secret mismatch")
        }
    }

    func testEntriesWithoutTOTPHaveNoConfig() throws {
        let root = try parseFixture()
        let entries = root.allEntries

        for expected in Expected.entries where !expected.hasTOTP {
            let entry = entries.first { $0.title == expected.title }
            XCTAssertNotNil(entry, "Entry not found: \(expected.title)")
            XCTAssertNil(entry?.totpConfig,
                         "\(expected.title): should not have TOTP config")
        }
    }

    // MARK: - Group Membership Tests

    func testEntriesAreInCorrectGroups() throws {
        let root = try parseFixture()

        for expected in Expected.entries {
            let group = findGroup(named: expected.group, in: root)
            XCTAssertNotNil(group, "Group not found: \(expected.group)")
            let entryInGroup = group?.entries.first { $0.title == expected.title }
            XCTAssertNotNil(entryInGroup,
                            "\(expected.title) should be in group \(expected.group)")
        }
    }

    // MARK: - Nested Groups

    func testNestedSubgroupParsed() throws {
        let root = try parseFixture()
        let work = findGroup(named: "Work", in: root)
        XCTAssertNotNil(work)
        let internal_ = work?.groups.first { $0.name == "Internal" }
        XCTAssertNotNil(internal_, "Nested group Work/Internal not found")
        XCTAssertEqual(internal_?.entries.count, 1)
    }

    func testEmptyGroupHasNoEntries() throws {
        let root = try parseFixture()
        let empty = root.groups.first { $0.name == "Empty" }
        XCTAssertNotNil(empty, "Empty group not found")
        XCTAssertTrue(empty?.entries.isEmpty ?? false)
    }

    func testAllEntriesIncludesNestedGroupEntries() throws {
        let root = try parseFixture()
        let nestedEntry = root.allEntries.first { $0.title == "日本語テスト 🔑" }
        XCTAssertNotNil(nestedEntry, "Entry in nested group not found via allEntries")
    }

    // MARK: - Edge Cases

    func testEntryWithEmptyURLAndUsername() throws {
        let root = try parseFixture()
        let entry = root.allEntries.first { $0.title == "Offline Key" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.url, "")
        XCTAssertEqual(entry?.username, "")
    }

    func testEntryWithEmptyPassword() throws {
        let root = try parseFixture()
        let entry = root.allEntries.first { $0.title == "Public Profile" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.password, "")
    }

    func testUnicodeEntryFieldsParsedCorrectly() throws {
        let root = try parseFixture()
        let entry = root.allEntries.first { $0.title == "日本語テスト 🔑" }
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.username, "ユーザー")
        XCTAssertEqual(entry?.password, "pässwörd!@#¥")
    }

    // MARK: - KP2A Additional URLs

    func testGitHubEntryHasAdditionalURLs() throws {
        let root = try parseFixture()
        let github = try XCTUnwrap(root.allEntries.first { $0.title == "GitHub" })

        XCTAssertEqual(github.additionalURLs, [
            "https://github.com/settings",
            "https://gist.github.com",
        ])
    }

    func testEntriesWithoutKP2AURLsHaveEmptyAdditionalURLs() throws {
        let root = try parseFixture()
        let twitter = try XCTUnwrap(root.allEntries.first { $0.title == "Twitter" })
        XCTAssertTrue(twitter.additionalURLs.isEmpty)
    }

    func testKP2AURLFieldsExcludedFromCustomFields() throws {
        let root = try parseFixture()
        let github = try XCTUnwrap(root.allEntries.first { $0.title == "GitHub" })

        let kp2aKeys = github.customFields.keys.filter { $0.hasPrefix("KP2A_URL_") }
        // KP2A_URL fields should still be in customFields (additionalURLs reads from them)
        XCTAssertEqual(kp2aKeys.count, 2)
    }

    // MARK: - Crypto Tests

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

    // MARK: - Composite Key Tests

    func testCompositeKeyPathMatchesPasswordPath() throws {
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

    // MARK: - Helpers

    private func parseFixture() throws -> KPGroup {
        let data = try fixtureData()
        return try KDBXParser.parse(data: data, password: fixturePassword)
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

    private func findGroup(named name: String, in root: KPGroup) -> KPGroup? {
        for group in root.groups {
            if group.name == name { return group }
            if let found = findGroup(named: name, in: group) { return found }
        }
        return nil
    }
}
