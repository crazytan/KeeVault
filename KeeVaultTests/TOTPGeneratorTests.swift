import XCTest
@testable import KeeVault

final class TOTPGeneratorTests: XCTestCase {
    func testGenerateCodeSHA1RFC6238Vector() {
        let config = TOTPConfig(
            secret: "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ",
            period: 30,
            digits: 8,
            algorithm: .sha1
        )

        let code = TOTPGenerator.generateCode(config: config, date: Date(timeIntervalSince1970: 59))

        XCTAssertEqual(code, "94287082")
    }

    func testGenerateCodeReturnsPlaceholderForInvalidBase32Secret() {
        let config = TOTPConfig(secret: "not_base32***", period: 30, digits: 6, algorithm: .sha1)

        let code = TOTPGenerator.generateCode(config: config, date: Date(timeIntervalSince1970: 1_700_000_000))

        XCTAssertEqual(code, "------")
    }

    func testSecondsRemainingAtBoundaryReturnsFullPeriod() {
        let date = Date(timeIntervalSince1970: 60)

        let remaining = TOTPGenerator.secondsRemaining(period: 30, date: date)

        XCTAssertEqual(remaining, 30)
    }

    func testSecondsRemainingMidPeriodReturnsExpectedValue() {
        let date = Date(timeIntervalSince1970: 74)

        let remaining = TOTPGenerator.secondsRemaining(period: 30, date: date)

        XCTAssertEqual(remaining, 16)
    }

    func testBase32DecodeAcceptsLowercaseWhitespaceAndPadding() throws {
        let canonical = try XCTUnwrap(TOTPGenerator.base32Decode("JBSWY3DPEHPK3PXP"))
        let normalized = try XCTUnwrap(TOTPGenerator.base32Decode("jbsw y3dp ehpk3pxp===="))

        XCTAssertEqual(normalized, canonical)
    }

    func testBase32DecodeRejectsInvalidCharacters() {
        XCTAssertNil(TOTPGenerator.base32Decode("ABC$DEF"))
    }
}
