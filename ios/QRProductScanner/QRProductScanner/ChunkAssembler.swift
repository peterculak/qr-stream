import Foundation

/// Collects QR code chunks and tracks progress for high-density data streams.
/// Used to reconstruct a single large data blob from multiple QR segments.
class ChunkAssembler: ObservableObject {
    @Published private(set) var chunks: [Int: Data] = [:]
    @Published private(set) var totalChunks: Int?
    @Published private(set) var filename: String?

    var receivedCount: Int { chunks.count }

    var isComplete: Bool {
        guard let total = totalChunks else { return false }
        return chunks.count >= total
    }
    
    var progress: Double {
        guard let total = totalChunks, total > 0 else { return 0 }
        return Double(chunks.count) / Double(total)
    }

    /// Parse a QR code string and store the chunk.
    /// Returns true if this was a new chunk.
    @discardableResult
    func addChunk(_ rawString: String) -> Bool {
        // We expect chunks to be JSON-encoded: { "i": index, "n": total, "d": base64_data }
        guard let data = rawString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["d"] as? String,
              let payloadData = Data(base64Encoded: payload) else {
            return false
        }
        
        // Handle both Int and String for index/total
        let index: Int
        if let i = json["i"] as? Int {
            index = i
        } else if let s = json["i"] as? String, let i = Int(s) {
            index = i
        } else {
            return false
        }
        
        let total: Int
        if let n = json["n"] as? Int {
            total = n
        } else if let s = json["n"] as? String, let n = Int(s) {
            total = n
        } else {
            return false
        }

        totalChunks = total

        if let f = json["f"] as? String {
            filename = f
        }

        if chunks[index] != nil {
            return false // duplicate
        }

        chunks[index] = payloadData
        return true
    }

    /// Reassemble all chunks in order into a single Data blob.
    func assemble() -> Data {
        let sorted = chunks.sorted { $0.key < $1.key }
        var result = Data()
        for (_, chunk) in sorted {
            result.append(chunk)
        }
        return result
    }

    /// Reset state for a new scan
    func reset() {
        chunks.removeAll()
        totalChunks = nil
        filename = nil
    }
}
