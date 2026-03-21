import Foundation

/// Manages saved files in the app's Documents directory.
class FileStorage: ObservableObject {
    @Published var files: [SavedFile] = []

    struct SavedFile: Identifiable, Comparable {
        let id = UUID()
        let name: String
        let url: URL
        let date: Date
        let size: Int

        static func < (lhs: SavedFile, rhs: SavedFile) -> Bool {
            lhs.date > rhs.date // newest first
        }
    }

    private var documentsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    init() {
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        let dir = documentsDir

        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            files = []
            return
        }

        files = items.compactMap { url in
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int ?? 0
            let date = attrs?[.creationDate] as? Date ?? Date()
            return SavedFile(name: url.lastPathComponent, url: url, date: date, size: size)
        }.sorted()
    }

    /// Save content as a file. Parses data URLs to save raw binary data if needed.
    @discardableResult
    func save(content: String, filename: String) -> URL {
        let url = uniqueURL(for: filename)
        
        if content.hasPrefix("data:") {
            let parts = content.split(separator: ",", maxSplits: 1)
            if parts.count == 2 {
                let header = parts[0]
                let payload = String(parts[1])
                
                if header.hasSuffix(";base64") {
                    if let data = Data(base64Encoded: payload, options: .ignoreUnknownCharacters) {
                        try? data.write(to: url, options: .atomic)
                        refresh()
                        return url
                    }
                } else if let decodedStr = payload.removingPercentEncoding,
                          let data = decodedStr.data(using: .utf8) {
                    try? data.write(to: url, options: .atomic)
                    refresh()
                    return url
                }
            }
        }
        
        // Fallback to plain text
        try? content.write(to: url, atomically: true, encoding: .utf8)
        refresh()
        return url
    }

    func delete(_ file: SavedFile) {
        try? FileManager.default.removeItem(at: file.url)
        refresh()
    }

    private func uniqueURL(for filename: String) -> URL {
        let base = documentsDir.appendingPathComponent(filename)
        if !FileManager.default.fileExists(atPath: base.path) {
            return base
        }

        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension

        var counter = 1
        var candidate: URL
        repeat {
            let newName = ext.isEmpty ? "\(name)_\(counter)" : "\(name)_\(counter).\(ext)"
            candidate = documentsDir.appendingPathComponent(newName)
            counter += 1
        } while FileManager.default.fileExists(atPath: candidate.path)

        return candidate
    }
}
