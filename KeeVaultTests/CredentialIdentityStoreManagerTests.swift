import AuthenticationServices
import XCTest
@testable import KeeVault

final class CredentialIdentityStoreManagerTests: XCTestCase {

    // MARK: - domainFromURLString

    func testDomainFromFullHTTPSURL() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://github.com/login"), "github.com")
    }

    func testDomainFromHTTPURL() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("http://example.org/path"), "example.org")
    }

    func testDomainFromURLWithPort() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://example.com:8443/path"), "example.com")
    }

    func testDomainFromSubdomainURL() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://accounts.google.com/signin"), "google.com")
    }

    func testDomainFromBareDomainPrependsHTTPS() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("example.com"), "example.com")
    }

    func testDomainFromBareDomainWithPath() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("example.com/login"), "example.com")
    }

    func testDomainFromEmptyStringReturnsNil() {
        XCTAssertNil(CredentialIdentityStoreManager.domainFromURLString(""))
    }

    func testDomainFromWhitespaceOnlyReturnsNil() {
        // URL(string:) returns nil for whitespace-only strings
        XCTAssertNil(CredentialIdentityStoreManager.domainFromURLString("   "))
    }

    func testDomainFromURLWithQueryAndFragment() {
        XCTAssertEqual(
            CredentialIdentityStoreManager.domainFromURLString("https://example.com/path?q=1#section"),
            "example.com"
        )
    }

    // MARK: - passwordIdentity: basic identity creation

    func testIdentityWithUsernameAndURL() {
        let entry = makeEntry(title: "GitHub", url: "https://github.com", username: "octocat", hasPassword: true)
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.user, "octocat")
        XCTAssertEqual(identity?.serviceIdentifier.identifier, "github.com")
        XCTAssertEqual(identity?.serviceIdentifier.type, .domain)
    }

    func testIdentityRecordIdentifierIsEntryUUID() {
        let id = UUID()
        let entry = makeEntry(id: id, title: "Test", url: "https://example.com", username: "user", hasPassword: true)
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertEqual(identity?.recordIdentifier, id.uuidString)
    }

    // MARK: - passwordIdentity: username fallback to title

    func testIdentityFallsBackToTitleWhenUsernameEmpty() {
        let entry = makeEntry(title: "Work Account", url: "https://example.com", username: "", hasPassword: true)
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.user, "Work Account")
    }

    // MARK: - passwordIdentity: entries that should be skipped

    func testIdentityNilWhenNoUsernameAndNoTitle() {
        let entry = makeEntry(title: "", url: "https://example.com", username: "", hasPassword: true)
        XCTAssertNil(CredentialIdentityStoreManager.passwordIdentity(for: entry))
    }

    func testIdentityNilWhenNoPassword() {
        let entry = makeEntry(title: "Test", url: "https://example.com", username: "user", hasPassword: false)
        XCTAssertNil(CredentialIdentityStoreManager.passwordIdentity(for: entry))
    }

    func testIdentityNilWhenURLEmpty() {
        let entry = makeEntry(title: "No URL", url: "", username: "user", hasPassword: true)
        XCTAssertNil(CredentialIdentityStoreManager.passwordIdentity(for: entry))
    }

    func testIdentityNilWhenURLWhitespace() {
        let entry = makeEntry(title: "Bad URL", url: "   ", username: "user", hasPassword: true)
        XCTAssertNil(CredentialIdentityStoreManager.passwordIdentity(for: entry))
    }

    // MARK: - passwordIdentity: multiple URLs (additionalURLs via KP2A_URL_*)

    func testFirstValidDomainWinsFromPrimaryURL() {
        let entry = makeEntry(
            title: "Multi",
            url: "https://github.com",
            username: "user",
            hasPassword: true,
            customFields: ["KP2A_URL_1": "https://gitlab.com"]
        )
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertEqual(identity?.serviceIdentifier.identifier, "github.com")
    }

    func testFallsBackToAdditionalURLWhenPrimaryInvalid() {
        let entry = makeEntry(
            title: "Fallback",
            url: "",
            username: "user",
            hasPassword: true,
            customFields: ["KP2A_URL_1": "https://backup.example.com"]
        )
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.serviceIdentifier.identifier, "example.com")
    }

    func testNilWhenAllURLsInvalid() {
        let entry = makeEntry(
            title: "No Valid URLs",
            url: "",
            username: "user",
            hasPassword: true,
            customFields: ["KP2A_URL_1": "", "KP2A_URL_2": ""]
        )
        XCTAssertNil(CredentialIdentityStoreManager.passwordIdentity(for: entry))
    }

    func testAdditionalURLsSortedByKey() {
        // KP2A_URL_1 is empty, KP2A_URL_2 has a valid domain — should use KP2A_URL_2
        let entry = makeEntry(
            title: "Sorted",
            url: "",
            username: "user",
            hasPassword: true,
            customFields: [
                "KP2A_URL_1": "",
                "KP2A_URL_2": "https://second.example.com",
            ]
        )
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertEqual(identity?.serviceIdentifier.identifier, "example.com")
    }

    // MARK: - passwordIdentity: bare domain URLs

    func testIdentityWithBareDomainURL() {
        let entry = makeEntry(title: "Bare", url: "example.com", username: "user", hasPassword: true)
        let identity = CredentialIdentityStoreManager.passwordIdentity(for: entry)

        XCTAssertNotNil(identity)
        XCTAssertEqual(identity?.serviceIdentifier.identifier, "example.com")
    }

    // MARK: - domainFromURLString: www stripping and registered domain

    func testDomainStripsWWWPrefix() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://www.facebook.com"), "facebook.com")
    }

    func testDomainStripsWWWFromBareDomain() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("www.facebook.com"), "facebook.com")
    }

    func testDomainExtractsRegisteredDomainFromSubdomain() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://login.facebook.com/path"), "facebook.com")
    }

    func testDomainFromBareFacebookDomain() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("facebook.com"), "facebook.com")
    }

    func testDomainReturnsNilForIPv4Address() {
        XCTAssertNil(CredentialIdentityStoreManager.domainFromURLString("https://192.168.1.1/path"))
    }

    func testDomainReturnsNilForLocalhost() {
        XCTAssertNil(CredentialIdentityStoreManager.domainFromURLString("http://localhost:8080"))
    }

    func testDomainHandlesMultiPartTLD() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://www.bbc.co.uk"), "bbc.co.uk")
    }

    func testDomainExtractsRegisteredDomainFromMultiPartTLD() {
        XCTAssertEqual(CredentialIdentityStoreManager.domainFromURLString("https://news.bbc.co.uk"), "bbc.co.uk")
    }

    func testDomainReturnsNilForBareMultiPartTLD() {
        // "co.uk" alone is a TLD, not a registrable domain
        XCTAssertNil(CredentialIdentityStoreManager.domainFromURLString("https://co.uk"))
    }

    // MARK: - Helpers

    private func makeEntry(
        id: UUID = UUID(),
        title: String,
        url: String,
        username: String,
        hasPassword: Bool,
        customFields: [String: String] = [:]
    ) -> KPEntry {
        let encrypted: EncryptedValue = hasPassword
            ? EncryptedValue(sealedData: Data([0]), hasValue: true)
            : .empty
        return KPEntry(
            id: id,
            title: title,
            username: username,
            password: encrypted,
            url: url,
            customFields: customFields
        )
    }
}
