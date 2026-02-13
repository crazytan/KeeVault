import Foundation
import CryptoKit
import CommonCrypto

// MARK: - Argon2 Bridge (calls C libargon2)

enum Argon2Variant: UInt32, Sendable {
    case d = 0    // Argon2d
    case id = 2   // Argon2id
}

enum Argon2 {
    enum Argon2Error: Error {
        case hashFailed(Int32)
    }

    /// Derive key using Argon2d or Argon2id
    static func hash(
        password: Data,
        salt: Data,
        timeCost: UInt32,
        memoryCost: UInt32, // in KiB
        parallelism: UInt32,
        hashLength: Int = 32,
        variant: Argon2Variant
    ) throws -> Data {
        var output = Data(count: hashLength)
        let rc = output.withUnsafeMutableBytes { outPtr in
            password.withUnsafeBytes { pwdPtr in
                salt.withUnsafeBytes { saltPtr in
                    argon2_hash(
                        timeCost,
                        memoryCost,
                        parallelism,
                        pwdPtr.baseAddress, password.count,
                        saltPtr.baseAddress, salt.count,
                        outPtr.baseAddress, hashLength,
                        nil, 0, // encoded output — not needed
                        argon2_type(variant.rawValue),
                        UInt32(0x13) // ARGON2_VERSION_13
                    )
                }
            }
        }
        guard rc == 0 else { throw Argon2Error.hashFailed(rc) }
        return output
    }
}

// MARK: - KDBXCrypto

enum KDBXCrypto {
    enum CryptoError: Error, LocalizedError {
        case invalidKey
        case decryptionFailed
        case hmacMismatch
        case unsupportedCipher(String)
        case unsupportedKDF(String)
        case decompressionFailed

        var errorDescription: String? {
            switch self {
            case .invalidKey: "Invalid master key"
            case .decryptionFailed: "Decryption failed — wrong password?"
            case .hmacMismatch: "HMAC verification failed — file corrupted or wrong password"
            case .unsupportedCipher(let c): "Unsupported cipher: \(c)"
            case .unsupportedKDF(let k): "Unsupported KDF: \(k)"
            case .decompressionFailed: "Decompression failed"
            }
        }
    }

    // MARK: - SHA-256

    static func sha256(_ data: Data) -> Data {
        Data(CryptoKit.SHA256.hash(data: data))
    }

    static func sha512(_ data: Data) -> Data {
        Data(CryptoKit.SHA512.hash(data: data))
    }

    // MARK: - HMAC-SHA256

    static func hmacSHA256(key: Data, data: Data) -> Data {
        let symKey = SymmetricKey(data: key)
        return Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: data, using: symKey))
    }

    // MARK: - Composite Key

    /// Build the composite key from master password (hash of hash)
    static func compositeKey(password: String) -> Data {
        let pwdData = Data(password.utf8)
        let hash = sha256(pwdData)
        return sha256(hash)
    }

    // MARK: - AES-256-CBC Decrypt

    static func decryptAES256CBC(data: Data, key: Data, iv: Data) throws -> Data {
        var outLength = data.count + kCCBlockSizeAES128
        var outData = Data(count: outLength)
        var bytesWritten: Int = 0

        let status = outData.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            outPtr.baseAddress, outLength,
                            &bytesWritten
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else { throw CryptoError.decryptionFailed }
        outData.count = bytesWritten
        return outData
    }

    // MARK: - ChaCha20-Poly1305 Decrypt (CryptoKit)

    static func decryptChaCha20Poly1305(data: Data, key: Data, nonce: Data) throws -> Data {
        let symKey = SymmetricKey(data: key)
        // KDBX uses ChaCha20 combined box: nonce(12) + ciphertext + tag(16)
        // But the caller gives us raw ciphertext — we handle differently
        // In KDBX4, outer encryption uses 12-byte nonce from header
        guard nonce.count == 12 else { throw CryptoError.decryptionFailed }

        // Last 16 bytes are the Poly1305 tag
        guard data.count > 16 else { throw CryptoError.decryptionFailed }
        let ciphertext = data.prefix(data.count - 16)
        let tag = data.suffix(16)

        let sealedBox = try CryptoKit.ChaChaPoly.SealedBox(
            nonce: ChaChaPoly.Nonce(data: nonce),
            ciphertext: ciphertext,
            tag: tag
        )
        return try Data(ChaChaPoly.open(sealedBox, using: symKey))
    }

    // MARK: - ChaCha20 stream cipher (inner random stream)

    static func chacha20Stream(key: Data, nonce: Data, data: Data) -> Data {
        // ChaCha20 is XOR-based; encrypt == decrypt
        // Use CommonCrypto / raw implementation for stream-only (no Poly1305)
        // CryptoKit only supports ChaCha20-Poly1305 AEAD, so we use CryptoSwift or manual
        // For inner stream, KDBX uses raw ChaCha20 without authentication
        return chacha20XOR(key: key, nonce: nonce, data: data)
    }

    /// Raw ChaCha20 quarter-round based implementation for inner stream cipher
    private static func chacha20XOR(key: Data, nonce: Data, data: Data) -> Data {
        guard key.count == 32, nonce.count == 12 else { return data }

        var state = [UInt32](repeating: 0, count: 16)
        // "expand 32-byte k"
        state[0] = 0x61707865
        state[1] = 0x3320646e
        state[2] = 0x79622d32
        state[3] = 0x6b206574

        key.withUnsafeBytes { ptr in
            for i in 0..<8 {
                state[4 + i] = ptr.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self).littleEndian
            }
        }

        state[12] = 0 // counter
        nonce.withUnsafeBytes { ptr in
            for i in 0..<3 {
                state[13 + i] = ptr.loadUnaligned(fromByteOffset: i * 4, as: UInt32.self).littleEndian
            }
        }

        var output = Data(count: data.count)
        var offset = 0

        while offset < data.count {
            var working = state
            for _ in 0..<10 {
                quarterRound(&working, 0, 4, 8, 12)
                quarterRound(&working, 1, 5, 9, 13)
                quarterRound(&working, 2, 6, 10, 14)
                quarterRound(&working, 3, 7, 11, 15)
                quarterRound(&working, 0, 5, 10, 15)
                quarterRound(&working, 1, 6, 11, 12)
                quarterRound(&working, 2, 7, 8, 13)
                quarterRound(&working, 3, 4, 9, 14)
            }
            for i in 0..<16 { working[i] = working[i] &+ state[i] }

            let blockBytes = working.withUnsafeBytes { Data($0) }
            let remaining = min(64, data.count - offset)
            for i in 0..<remaining {
                output[offset + i] = data[offset + i] ^ blockBytes[i]
            }

            offset += 64
            state[12] &+= 1
        }

        return output
    }

    private static func quarterRound(_ s: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        s[a] = s[a] &+ s[b]; s[d] ^= s[a]; s[d] = (s[d] << 16) | (s[d] >> 16)
        s[c] = s[c] &+ s[d]; s[b] ^= s[c]; s[b] = (s[b] << 12) | (s[b] >> 20)
        s[a] = s[a] &+ s[b]; s[d] ^= s[a]; s[d] = (s[d] << 8) | (s[d] >> 24)
        s[c] = s[c] &+ s[d]; s[b] ^= s[c]; s[b] = (s[b] << 7) | (s[b] >> 25)
    }

    // MARK: - GZip Decompression

    static func gunzip(_ data: Data) throws -> Data {
        // Use Compression framework (Apple built-in)
        guard data.count > 2 else { throw CryptoError.decompressionFailed }

        // Skip gzip header if present
        var startOffset = 0
        if data[0] == 0x1F && data[1] == 0x8B {
            // Parse gzip header to find where deflate data starts
            startOffset = 10
            let flags = data[3]
            if flags & 0x04 != 0 { // FEXTRA
                let extraLen = Int(data[startOffset]) | (Int(data[startOffset + 1]) << 8)
                startOffset += 2 + extraLen
            }
            if flags & 0x08 != 0 { // FNAME
                while startOffset < data.count && data[startOffset] != 0 { startOffset += 1 }
                startOffset += 1
            }
            if flags & 0x10 != 0 { // FCOMMENT
                while startOffset < data.count && data[startOffset] != 0 { startOffset += 1 }
                startOffset += 1
            }
            if flags & 0x02 != 0 { startOffset += 2 } // FHCRC
        }

        let compressed = data.subdata(in: startOffset..<(data.count - 8)) // strip trailer
        return try decompressRawDeflate(compressed)
    }

    private static func decompressRawDeflate(_ data: Data) throws -> Data {
        let bufferSize = data.count * 4
        var result = Data()

        try data.withUnsafeBytes { srcPtr in
            let filter = try OutputFilter(.decompress, using: .zlib) { (outData: Data?) in
                if let outData { result.append(outData) }
            }
            // Feed in chunks
            var offset = 0
            let chunkSize = 65536
            while offset < data.count {
                let end = min(offset + chunkSize, data.count)
                let chunk = data.subdata(in: offset..<end)
                try filter.write(chunk)
                offset = end
            }
            try filter.finalize()
        }

        if result.isEmpty { throw CryptoError.decompressionFailed }
        return result
    }
}

// MARK: - Compression OutputFilter

import Compression

private class OutputFilter {
    enum Operation { case compress, decompress }

    private let algorithm: Algorithm
    private let operation: Operation
    private let callback: (Data?) throws -> Void
    private var stream: compression_stream
    private let bufferSize = 65536

    init(_ operation: Operation, using algorithm: Algorithm, writingTo callback: @escaping (Data?) throws -> Void) throws {
        self.operation = operation
        self.algorithm = algorithm
        self.callback = callback
        self.stream = compression_stream(dst_ptr: UnsafeMutablePointer<UInt8>.allocate(capacity: 0), dst_size: 0, src_ptr: UnsafeMutablePointer<UInt8>.allocate(capacity: 0), src_size: 0, state: nil)

        let op: compression_stream_operation = operation == .compress ? COMPRESSION_STREAM_ENCODE : COMPRESSION_STREAM_DECODE
        let algo: compression_algorithm
        switch algorithm {
        case .zlib: algo = COMPRESSION_ZLIB
        }

        let status = compression_stream_init(&stream, op, algo)
        guard status == COMPRESSION_STATUS_OK else {
            throw KDBXCrypto.CryptoError.decompressionFailed
        }
    }

    deinit {
        compression_stream_destroy(&stream)
    }

    func write(_ data: Data) throws {
        try data.withUnsafeBytes { ptr in
            stream.src_ptr = ptr.bindMemory(to: UInt8.self).baseAddress!
            stream.src_size = data.count

            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }

            let flags: Int32 = 0
            while stream.src_size > 0 {
                stream.dst_ptr = buffer
                stream.dst_size = bufferSize
                let status = compression_stream_process(&stream, flags)
                let produced = bufferSize - stream.dst_size
                if produced > 0 {
                    try callback(Data(bytes: buffer, count: produced))
                }
                if status == COMPRESSION_STATUS_ERROR {
                    throw KDBXCrypto.CryptoError.decompressionFailed
                }
            }
        }
    }

    func finalize() throws {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        stream.src_size = 0
        repeat {
            stream.dst_ptr = buffer
            stream.dst_size = bufferSize
            let status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
            let produced = bufferSize - stream.dst_size
            if produced > 0 {
                try callback(Data(bytes: buffer, count: produced))
            }
            if status == COMPRESSION_STATUS_END { break }
            if status == COMPRESSION_STATUS_ERROR {
                throw KDBXCrypto.CryptoError.decompressionFailed
            }
        } while true

        try callback(nil)
    }

    enum Algorithm { case zlib }
}
