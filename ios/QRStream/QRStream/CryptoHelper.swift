import Foundation
import CommonCrypto
import CryptoKit
import Compression

enum CryptoError: LocalizedError {
    case dataCorrupted
    case decryptionFailed
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .dataCorrupted: return "Data is corrupted or too short"
        case .decryptionFailed: return "Decryption failed — wrong password?"
        case .decompressionFailed: return "Decompression failed"
        }
    }
}

/// Matches the server's crypto pipeline.
/// Detects encrypted vs plain via magic bytes:
///   0xE1C0 = encrypted (AES-256-GCM)
///   0xDA7A = plain (just compressed)
struct CryptoHelper {

    private static let pbkdf2Iterations: UInt32 = 100_000
    private static let keyLength = 32
    private static let saltLength = 16
    private static let ivLength = 12
    private static let authTagLength = 16

    private static let encryptedMagic: [UInt8] = [0xE1, 0xC0]
    private static let plainMagic: [UInt8] = [0xDA, 0x7A]

    /// Decrypt/decompress assembled data. Password can be empty for unencrypted data.
    static func decrypt(assembledData data: Data, password: String) throws -> String {
        guard data.count >= 3 else {
            throw CryptoError.dataCorrupted
        }

        let magic = [data[0], data[1]]
        let payload = data[2...]

        let compressed: Data

        if magic == encryptedMagic {
            // Encrypted path
            guard !password.isEmpty else {
                throw CryptoError.decryptionFailed
            }
            let minLen = saltLength + ivLength + authTagLength + 1
            guard payload.count >= minLen else {
                throw CryptoError.dataCorrupted
            }

            let base = payload.startIndex
            let salt = payload[base..<(base + saltLength)]
            let iv = payload[(base + saltLength)..<(base + saltLength + ivLength)]
            let authTag = payload[(base + saltLength + ivLength)..<(base + saltLength + ivLength + authTagLength)]
            let ciphertext = payload[(base + saltLength + ivLength + authTagLength)...]

            let key = try deriveKey(password: password, salt: Data(salt))
            let symmetricKey = SymmetricKey(data: key)
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: ciphertext,
                tag: authTag
            )
            compressed = try AES.GCM.open(sealedBox, using: symmetricKey)
        } else if magic == plainMagic {
            // Plain (no encryption)
            compressed = Data(payload)
        } else {
            throw CryptoError.dataCorrupted
        }

        guard let decompressed = zlibInflate(compressed) else {
            throw CryptoError.decompressionFailed
        }

        guard let result = String(data: decompressed, encoding: .utf8) else {
            throw CryptoError.decompressionFailed
        }

        return result
    }

    // MARK: - PBKDF2

    private static func deriveKey(password: String, salt: Data) throws -> Data {
        let passwordData = password.data(using: .utf8)!
        var derivedKey = Data(count: keyLength)

        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw CryptoError.decryptionFailed
        }

        return derivedKey
    }

    // MARK: - Zlib inflate

    private static func zlibInflate(_ data: Data) -> Data? {
        let bufferSize = max(data.count * 10, 4096)
        let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destinationBuffer.deallocate() }

        let decompressedSize = data.withUnsafeBytes { sourceBytes -> Int in
            guard let baseAddress = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            return compression_decode_buffer(
                destinationBuffer,
                bufferSize,
                baseAddress,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: destinationBuffer, count: decompressedSize)
    }
}
