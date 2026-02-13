import Foundation
import CryptoKit

/// Generates TOTP codes per RFC 6238
enum TOTPGenerator {

    /// Generate a TOTP code for the given config at the current time
    static func generateCode(config: TOTPConfig, date: Date = Date()) -> String {
        guard let secretData = base32Decode(config.secret) else { return "------" }

        let timeInterval = UInt64(date.timeIntervalSince1970)
        let counter = timeInterval / UInt64(config.period)

        var bigEndianCounter = counter.bigEndian
        let counterData = Data(bytes: &bigEndianCounter, count: 8)

        let hmac: Data
        switch config.algorithm {
        case .sha1:
            let key = SymmetricKey(data: secretData)
            var h = HMAC<Insecure.SHA1>.init(key: key)
            h.update(data: counterData)
            hmac = Data(h.finalize())
        case .sha256:
            let key = SymmetricKey(data: secretData)
            hmac = Data(HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512:
            let key = SymmetricKey(data: secretData)
            hmac = Data(HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        let offset = Int(hmac[hmac.count - 1] & 0x0F)
        let truncated = hmac.withUnsafeBytes { ptr -> UInt32 in
            let slice = ptr.baseAddress!.advanced(by: offset)
            return slice.loadUnaligned(as: UInt32.self).bigEndian & 0x7FFF_FFFF
        }

        let modulus = UInt32(pow(10.0, Double(config.digits)))
        let code = truncated % modulus
        return String(format: "%0\(config.digits)d", code)
    }

    /// Seconds remaining in current TOTP period
    static func secondsRemaining(period: Int, date: Date = Date()) -> Int {
        let elapsed = Int(date.timeIntervalSince1970) % period
        return period - elapsed
    }

    // MARK: - Base32 Decoding

    private static let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    static func base32Decode(_ input: String) -> Data? {
        let cleaned = input.uppercased().replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")
        var bits = ""
        for char in cleaned {
            guard let index = base32Alphabet.firstIndex(of: char) else { return nil }
            let value = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
            bits += String(value, radix: 2).leftPadded(toLength: 5, with: "0")
        }

        var bytes: [UInt8] = []
        var i = bits.startIndex
        while bits.distance(from: i, to: bits.endIndex) >= 8 {
            let end = bits.index(i, offsetBy: 8)
            if let byte = UInt8(bits[i..<end], radix: 2) {
                bytes.append(byte)
            }
            i = end
        }
        return Data(bytes)
    }
}

private extension String {
    func leftPadded(toLength length: Int, with pad: Character) -> String {
        let deficit = length - count
        if deficit <= 0 { return self }
        return String(repeating: pad, count: deficit) + self
    }
}
