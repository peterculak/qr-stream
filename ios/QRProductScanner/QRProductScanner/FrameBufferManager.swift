import Foundation
import AVFoundation
import CoreImage

/// Manages a circular buffer of raw video frames (CVPixelBuffer).
/// This allows the app to perform multi-pass decoding on recently seen video segments.
class FrameBufferManager: ObservableObject {
    /// Maximum number of frames to keep in memory (~2 seconds at 60fps)
    private let capacity: Int
    
    /// Thread-safe circular storage for pixel buffers
    private var buffer: [CVPixelBuffer] = []
    private let lock = NSRecursiveLock()
    
    @Published var frameCount: Int = 0
    
    init(capacity: Int = 120) {
        self.capacity = capacity
    }
    
    /// Adds a new frame to the circular buffer.
    /// Converts CMSampleBuffer to CVPixelBuffer and manages capacity.
    func addFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        lock.lock()
        defer { lock.unlock() }
        
        // Add to the end
        buffer.append(pixelBuffer)
        
        // Enforce circularity
        if buffer.count > capacity {
            buffer.removeFirst()
        }
        
        // Update published count on main thread if changed
        let count = buffer.count
        DispatchQueue.main.async {
            self.frameCount = count
        }
    }
    
    /// Retrieves all currently buffered frames for analysis.
    /// Returns a copy of the current buffer to avoid thread contention during decoding.
    func getAllFrames() -> [CVPixelBuffer] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }
    
    /// Clears the buffer (e.g. after a successful assembly)
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer.removeAll()
        DispatchQueue.main.async {
            self.frameCount = 0
        }
    }
}
