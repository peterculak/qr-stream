import Foundation
import Vision
import CoreImage

/// Uses Apple's Vision framework to decode QR codes from buffered raw video frames.
/// This provides a fallback when the secondary metadata detector fails due to motion blur or glare.
class StreamDecoder {
    
    /// Decodes a single pixel buffer and returns the first QR code content found.
    func decode(frame: CVPixelBuffer) -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        
        // Use the most modern revision for better accuracy on distorted/blurry QRs
        if #available(iOS 17.0, *) {
            request.revision = VNDetectBarcodesRequestRevision3
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: frame, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results as? [VNBarcodeObservation],
                  let firstResult = results.first,
                  let payload = firstResult.payloadStringValue else {
                return nil
            }
            
            return payload
        } catch {
            return nil
        }
    }
    
    /// Decodes a sampled batch of frames (e.g. every 4th frame) for efficiency.
    /// Returns the found codes and the count of frames that were actually sampled.
    func decodeBatch(frames: [CVPixelBuffer]) -> (codes: Set<String>, sampledCount: Int) {
        var foundCodes = Set<String>()
        var sampledCount = 0
        
        // Sample every 4th frame to cover the buffer quickly without over-taxing the CPU
        for i in stride(from: frames.count - 1, through: 0, by: -4) {
            sampledCount += 1
            if let code = decode(frame: frames[i]) {
                foundCodes.insert(code)
            }
        }
        
        return (foundCodes, sampledCount)
    }
}
