import Foundation
import SwiftUI

/// A simple diagnostic logger for high-speed QR stream monitoring.
/// Used to track exactly which chunks are being found and from which source.
class DebugLogger: ObservableObject {
    static let shared = DebugLogger()
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        
        var timeString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SS"
            return formatter.string(from: timestamp)
        }
    }
    
    @Published var entries: [LogEntry] = []
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            let entry = LogEntry(timestamp: Date(), message: message)
            self.entries.append(entry)
            
            // Keep only the last 100 entries to maintain performance
            if self.entries.count > 100 {
                self.entries.removeFirst()
            }
        }
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
    }
}
