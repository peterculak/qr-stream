import Foundation
import UIKit
import Compression

// MARK: - Product Data Model

struct ProductData {
    var name: String = ""
    var brand: String = ""
    var category: String = ""
    var servingSize: String = ""
    var calories: UInt16 = 0
    /// Grams × 10 (e.g. 15.5g stored as 155)
    var fat: UInt16 = 0
    var carbs: UInt16 = 0
    var protein: UInt16 = 0
    var sugar: UInt16 = 0
    var fiber: UInt16 = 0
    /// Milligrams
    var sodium: UInt16 = 0
    /// Raw JPEG thumbnail data (tiny, ~32×32)
    var thumbnailData: Data?

    var fatGrams: Double { Double(fat) / 10.0 }
    var carbsGrams: Double { Double(carbs) / 10.0 }
    var proteinGrams: Double { Double(protein) / 10.0 }
    var sugarGrams: Double { Double(sugar) / 10.0 }
    var fiberGrams: Double { Double(fiber) / 10.0 }

    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - TLV Tags

enum ProductTag: UInt8 {
    case name        = 0x01
    case thumbnail   = 0x02
    case calories    = 0x03
    case fat         = 0x04
    case carbs       = 0x05
    case protein     = 0x06
    case sugar       = 0x07
    case fiber       = 0x08
    case sodium      = 0x09
    case servingSize = 0x0A
    case brand       = 0x0B
    case category    = 0x0C
}

// MARK: - Codec

enum ProductQRCodecError: Error, LocalizedError {
    case invalidMagic
    case unsupportedVersion
    case decompressFailed
    case truncatedTLV
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidMagic:       return "Not a Product QR code"
        case .unsupportedVersion: return "Unsupported format version"
        case .decompressFailed:   return "Failed to decompress data"
        case .truncatedTLV:       return "Corrupted data: truncated"
        case .invalidData:        return "Invalid data in QR code"
        }
    }
}

struct ProductQRCodec {
    static let magic: [UInt8] = [0x50, 0x51] // "PQ"
    static let version: UInt8 = 1

    // MARK: - Decode

    static func decode(from data: Data) throws -> ProductData {
        guard data.count >= 3 else { throw ProductQRCodecError.invalidData }

        let bytes = [UInt8](data)
        guard bytes[0] == magic[0], bytes[1] == magic[1] else {
            throw ProductQRCodecError.invalidMagic
        }
        guard bytes[2] == version else {
            throw ProductQRCodecError.unsupportedVersion
        }

        let compressedPayload = Data(bytes[3...])
        guard let decompressed = decompress(compressedPayload) else {
            throw ProductQRCodecError.decompressFailed
        }

        return try parseTLV(decompressed)
    }

    // MARK: - Encode (for test QR generation)

    static func encode(_ product: ProductData) -> Data {
        var tlvData = Data()

        appendString(&tlvData, tag: .name, value: product.name)
        appendString(&tlvData, tag: .brand, value: product.brand)
        appendString(&tlvData, tag: .category, value: product.category)
        appendString(&tlvData, tag: .servingSize, value: product.servingSize)
        appendUInt16(&tlvData, tag: .calories, value: product.calories)
        appendUInt16(&tlvData, tag: .fat, value: product.fat)
        appendUInt16(&tlvData, tag: .carbs, value: product.carbs)
        appendUInt16(&tlvData, tag: .protein, value: product.protein)
        appendUInt16(&tlvData, tag: .sugar, value: product.sugar)
        appendUInt16(&tlvData, tag: .fiber, value: product.fiber)
        appendUInt16(&tlvData, tag: .sodium, value: product.sodium)

        if let thumb = product.thumbnailData, !thumb.isEmpty {
            appendData(&tlvData, tag: .thumbnail, value: thumb)
        }

        let compressed = compress(tlvData) ?? tlvData

        var result = Data()
        result.append(contentsOf: magic)
        result.append(version)
        result.append(compressed)
        return result
    }

    // MARK: - TLV Parsing

    private static func parseTLV(_ data: Data) throws -> ProductData {
        var product = ProductData()
        let bytes = [UInt8](data)
        var offset = 0

        while offset < bytes.count {
            guard offset + 3 <= bytes.count else {
                throw ProductQRCodecError.truncatedTLV
            }

            let tagByte = bytes[offset]
            let length = Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2])
            offset += 3

            guard offset + length <= bytes.count else {
                throw ProductQRCodecError.truncatedTLV
            }

            let valueBytes = Array(bytes[offset..<offset + length])
            offset += length

            guard let tag = ProductTag(rawValue: tagByte) else { continue }

            switch tag {
            case .name:
                product.name = String(bytes: valueBytes, encoding: .utf8) ?? ""
            case .brand:
                product.brand = String(bytes: valueBytes, encoding: .utf8) ?? ""
            case .category:
                product.category = String(bytes: valueBytes, encoding: .utf8) ?? ""
            case .servingSize:
                product.servingSize = String(bytes: valueBytes, encoding: .utf8) ?? ""
            case .thumbnail:
                product.thumbnailData = Data(valueBytes)
            case .calories:
                product.calories = readUInt16(valueBytes)
            case .fat:
                product.fat = readUInt16(valueBytes)
            case .carbs:
                product.carbs = readUInt16(valueBytes)
            case .protein:
                product.protein = readUInt16(valueBytes)
            case .sugar:
                product.sugar = readUInt16(valueBytes)
            case .fiber:
                product.fiber = readUInt16(valueBytes)
            case .sodium:
                product.sodium = readUInt16(valueBytes)
            }
        }

        return product
    }

    // MARK: - TLV Writing Helpers

    private static func appendString(_ data: inout Data, tag: ProductTag, value: String) {
        guard !value.isEmpty, let encoded = value.data(using: .utf8) else { return }
        data.append(tag.rawValue)
        data.append(UInt8((encoded.count >> 8) & 0xFF))
        data.append(UInt8(encoded.count & 0xFF))
        data.append(encoded)
    }

    private static func appendUInt16(_ data: inout Data, tag: ProductTag, value: UInt16) {
        data.append(tag.rawValue)
        data.append(0x00)
        data.append(0x02)
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private static func appendData(_ data: inout Data, tag: ProductTag, value: Data) {
        data.append(tag.rawValue)
        data.append(UInt8((value.count >> 8) & 0xFF))
        data.append(UInt8(value.count & 0xFF))
        data.append(value)
    }

    private static func readUInt16(_ bytes: [UInt8]) -> UInt16 {
        guard bytes.count >= 2 else { return 0 }
        return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
    }

    // MARK: - Compression

    private static func compress(_ data: Data) -> Data? {
        let sourceSize = data.count
        let destSize = sourceSize + 512
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { dest.deallocate() }

        let compressedSize = data.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = source.baseAddress else { return 0 }
            return compression_encode_buffer(
                dest, destSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), sourceSize,
                nil, COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else { return nil }
        return Data(bytes: dest, count: compressedSize)
    }

    private static func decompress(_ data: Data) -> Data? {
        let destSize = 8192 // 8KB should be more than enough for product data
        let dest = UnsafeMutablePointer<UInt8>.allocate(capacity: destSize)
        defer { dest.deallocate() }

        let decompressedSize = data.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = source.baseAddress else { return 0 }
            return compression_decode_buffer(
                dest, destSize,
                baseAddress.assumingMemoryBound(to: UInt8.self), data.count,
                nil, COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else { return nil }
        return Data(bytes: dest, count: decompressedSize)
    }
}
