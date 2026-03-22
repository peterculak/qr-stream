import SwiftUI
import AVFoundation
import WebKit

/// A SwiftUI-wrapped fullscreen camera view that detects QR codes.
/// Reports the raw string content of detected QR codes.
struct CameraScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    let onFrameCaptured: (CMSampleBuffer) -> Void
    var appHtml: String? // Pass broadcasted HTML app directly

    func makeUIViewController(context: Context) -> CameraScannerViewController {
        let vc = CameraScannerViewController()
        vc.onCodeScanned = onCodeScanned
        vc.onFrameCaptured = onFrameCaptured
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraScannerViewController, context: Context) {
        uiViewController.appHtml = appHtml
    }
}

class CameraScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onCodeScanned: ((String) -> Void)?
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    
    var appHtml: String? {
        didSet {
            if appHtml != oldValue {
                updateARApp()
            }
        }
    }

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var webView: WKWebView?
    private var lastLoadedHtml: String?

    private var lastScannedCode: String?
    private var lastScanTime: Date = .distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    private func setupARWebView() {
        guard webView == nil else { return }
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: view.bounds, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.isHidden = true
        wv.alpha = 0
        
        view.addSubview(wv)
        self.webView = wv
    }
    
    private func updateARApp() {
        if webView == nil && appHtml != nil {
            setupARWebView()
        }
        
        guard let wv = webView else { return }
        if appHtml == lastLoadedHtml { return }
        
        if let html = appHtml {
            setCameraFPS(30) // Conserve resources for WebContent process
            lastLoadedHtml = html
            wv.loadHTMLString(html, baseURL: nil)
            wv.isHidden = false
            UIView.animate(withDuration: 0.3) { wv.alpha = 1 }
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                wv.alpha = 0
            }) { _ in 
                wv.isHidden = true
                wv.loadHTMLString("", baseURL: nil)
                self.lastLoadedHtml = nil
                self.setCameraFPS(60)
            }
        }
    }
    
    private func setCameraFPS(_ fps: Int) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        try? device.lockForConfiguration()
        let duration = CMTime(value: 1, timescale: CMTimeScale(fps))
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported else { return }

        let windowScene = view.window?.windowScene
        let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait

        let videoOrientation: AVCaptureVideoOrientation
        switch interfaceOrientation {
        case .landscapeLeft:      videoOrientation = .landscapeLeft
        case .landscapeRight:     videoOrientation = .landscapeRight
        case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
        default:                  videoOrientation = .portrait
        }

        connection.videoOrientation = videoOrientation
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            return
        }

        captureSession.addInput(input)

        // Optimize for 60fps if available at 1080p
        do {
            try device.lockForConfiguration()
            
            // Find a 60fps format (preferably 1080p)
            let formats = device.formats
            let bestFormat = formats.first { format in
                let desc = format.formatDescription
                let dims = CMVideoFormatDescriptionGetDimensions(desc)
                let ranges = format.videoSupportedFrameRateRanges
                let is60fps = ranges.contains { $0.maxFrameRate >= 60 }
                return is60fps && dims.width >= 1920 && dims.height >= 1080
            } ?? formats.first { format in
                format.videoSupportedFrameRateRanges.contains { $0.maxFrameRate >= 60 }
            }
            
            if let format = bestFormat {
                device.activeFormat = format
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
            }
            
            // Set auto-focus and exposure for high speed (minimize blur)
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Could not configure device for 60fps: \(error)")
        }

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else { return }

        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]

        // RAW VIDEO OUTPUT for buffering
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing", qos: .userInitiated))
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    // Reset scanner to allow re-scanning
    func resetScanner() {
        lastScannedCode = nil
        lastScanTime = .distantPast
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for metadataObject in metadataObjects {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { continue }

            // Debounce: don't re-report the same code within 0.4 seconds
            let now = Date()
            if stringValue == lastScannedCode && now.timeIntervalSince(lastScanTime) < 0.4 {
                continue
            }

            lastScannedCode = stringValue
            lastScanTime = now
            onCodeScanned?(stringValue)
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrameCaptured?(sampleBuffer)
    }
}
