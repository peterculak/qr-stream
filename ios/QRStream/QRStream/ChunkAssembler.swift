import Foundation

/// Collects QR code chunks and tracks progress with transfer speed.
class ChunkAssembler: ObservableObject {
    @Published private var chunks: [Int: Data] = [:]
    @Published private(set) var totalChunks: Int?
    @Published private(set) var filename: String?

    private var startTime: Date?
    private var totalBytesReceived: Int = 0

    var receivedCount: Int { chunks.count }

    var isComplete: Bool {
        guard let total = totalChunks else { return false }
        return chunks.count >= total
    }
    
    var missingIndices: [Int] {
        guard let total = totalChunks, !isComplete else { return [] }
        var missing = [Int]()
        for i in 0..<total {
            if chunks[i] == nil {
                missing.append(i)
            }
        }
        return missing
    }

    /// Bytes received so far
    var bytesReceived: Int { totalBytesReceived }

    /// Transfer speed in bytes per second
    var bytesPerSecond: Double {
        guard let start = startTime else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        return Double(totalBytesReceived) / elapsed
    }

    /// Formatted transfer speed string
    var speedString: String {
        let bps = bytesPerSecond
        if bps < 1024 {
            return String(format: "%.0f B/s", bps)
        } else {
            return String(format: "%.1f KB/s", bps / 1024.0)
        }
    }

    /// Elapsed time since first chunk
    var elapsedSeconds: Double {
        guard let start = startTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Parse a QR code string and store the chunk.
    /// Returns true if this was a new chunk.
    @discardableResult
    func addChunk(_ rawString: String) -> Bool {
        guard let data = rawString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let index = json["i"] as? Int,
              let total = json["n"] as? Int,
              let payload = json["d"] as? String,
              let payloadData = Data(base64Encoded: payload) else {
            return false
        }

        totalChunks = total

        if let f = json["f"] as? String {
            filename = f
        }

        if chunks[index] != nil {
            return false // duplicate
        }

        if startTime == nil {
            startTime = Date()
        }

        chunks[index] = payloadData
        totalBytesReceived += payloadData.count
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
        startTime = nil
        totalBytesReceived = 0
    }
}
