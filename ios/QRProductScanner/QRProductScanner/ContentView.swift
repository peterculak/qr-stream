import SwiftUI
import Foundation

/// Root view managing the app state machine:
/// - `.scanning` — fullscreen camera + scanning progress indicator
/// - `.loaded(ProductData)` — camera dimmed + product card overlay
///
/// Tap gesture toggles the bottom menu when in scanning mode.
struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager

    enum ScanState: Equatable {
        case scanning
        case loaded

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.scanning, .scanning): return true
            case (.loaded, .loaded): return true
            default: return false
            }
        }
    }

    @State private var scanState: ScanState = .scanning
    @State private var scannedProduct: ProductData?
    @State private var lastScannedProduct: ProductData?
    @State private var showMenu = false
    @State private var showError = false
    @State private var isProcessing = false
    @State private var isScanSuccess = false
    @State private var scanProgress: CGFloat = 0.0
    @State private var errorMessage = ""
    
    @StateObject private var bufferManager = FrameBufferManager()
    @StateObject private var assembler = ChunkAssembler()
    @StateObject private var logger = DebugLogger.shared
    private let decoder = StreamDecoder()
    @State private var isAnalyzing = false
    @State private var showLogs = false
    
    // Timer to proactively analyze the buffer while a stream is in progress
    // Accelerates when near completion
    private var timerInterval: Double {
        (assembler.progress > 0.8 && !assembler.isComplete) ? 0.4 : 0.8
    }
    let analysisTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    @State private var lastAnalysisTime: Date = .distantPast

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // MARK: - Camera Layer (always visible)
            CameraScannerView(
                onCodeScanned: { scannedString in
                    handleScannedCode(scannedString)
                },
                onFrameCaptured: { sampleBuffer in
                    bufferManager.addFrame(sampleBuffer)
                }
            )
            .ignoresSafeArea()

            // Subtle theme tint overlay on camera
            theme.backgroundColor.opacity(0.15)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // MARK: - Scanning State
            if scanState == .scanning {
                ScanProgressView(isSuccess: isScanSuccess)
                    .transition(.opacity)
            }

            // MARK: - Product Card
            if scanState == .loaded, let product = scannedProduct {
                // Invisible background to catch taps anywhere to dismiss
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4)) {
                            scanState = .scanning
                            scannedProduct = nil
                            assembler.reset()
                            bufferManager.clear()
                        }
                    }

                VStack {
                    Spacer()
                    ProductCardView(product: product) {
                        withAnimation(.spring(response: 0.4)) {
                            scanState = .scanning
                            scannedProduct = nil
                            isScanSuccess = false
                        }
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            // MARK: - Processing Overlay
            if isProcessing || (assembler.receivedCount > 0 && !assembler.isComplete) {
                ZStack {
                    // Semi-transparent background dim
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    // Deterministic Progress Bar
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textColor.opacity(0.2))
                                .frame(width: 200, height: 4)
                            
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.accentColor)
                                .frame(width: 200 * (assembler.receivedCount > 0 ? CGFloat(assembler.progress) : scanProgress), height: 4)
                                .shadow(color: theme.accentColor.opacity(0.5), radius: 4)
                        }
                        
                        Text(assembler.receivedCount > 0 ? "STREAMING (\(assembler.receivedCount)/\(assembler.totalChunks ?? 0))" : "DECODING")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                            .tracking(2)
                    }
                    .offset(y: 140) // Positioned below the 200x200 scanner reticle
                }
                .transition(.opacity)
                .zIndex(20)
            }

            // MARK: - Error Toast
            if showError {
                VStack {
                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                            .shadow(color: .black.opacity(0.4), radius: 10)
                    )
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(5)
            }

            // MARK: - Bottom Menu
            BottomMenuView(isPresented: $showMenu)
                .zIndex(10)

            // MARK: - Tap Gesture Layer (only when scanning and no menu/card)
            if scanState == .scanning && !showMenu {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            showMenu = true
                        }
                    }
                    .onLongPressGesture(minimumDuration: 1.0) {
                        withAnimation { showLogs.toggle() }
                        if showLogs { logger.log("Diagnostic overlay enabled") }
                    }
                    .ignoresSafeArea()
            }
            
            // MARK: - Debug Log Overlay
            if showLogs {
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("DIAGNOSTIC LOGS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                            Spacer()
                            Button("CLEAR") { logger.clear() }
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(theme.accentColor)
                        .padding(.bottom, 4)
                        
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(logger.entries) { entry in
                                        Text("[\(entry.timeString)] \(entry.message)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.8))
                                            .id(entry.id)
                                    }
                                }
                                .onChange(of: logger.entries.count) { _ in
                                    if let last = logger.entries.last {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(height: 180)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.accentColor.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom))
                .zIndex(30)
            }
        }
        .onReceive(analysisTimer) { _ in
            let now = Date()
            if assembler.receivedCount > 0 && !assembler.isComplete && scanState == .scanning {
                if now.timeIntervalSince(lastAnalysisTime) >= timerInterval {
                    lastAnalysisTime = now
                    analyzeBufferBackground()
                }
            }
        }
        .statusBarHidden(true)
    }

    // MARK: - QR Code Handling

    private func handleScannedCode(_ code: String) {
        // Don't process while card is showing or menu is open
        guard scanState == .scanning, !showMenu else { return }

        // 1. Try as a Stream Chunk
        if assembler.addChunk(code) {
            logger.log("LIVE: Found chunk (\(assembler.receivedCount)/\(assembler.totalChunks ?? 0))")
            // Snappy detection pulse
            withAnimation(.spring(response: 0.2)) {
                isScanSuccess = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isScanSuccess = false
            }

            if assembler.isComplete {
                let fullData = assembler.assemble()
                processFinalData(fullData)
                assembler.reset()
                bufferManager.clear()
            } else {
                // Start filling gaps from buffer in background
                analyzeBufferBackground()
            }
            return
        }

        // Try decoding as base64-encoded binary ProductQR data
        if let binaryData = Data(base64Encoded: code) {
            do {
                let product = try ProductQRCodec.decode(from: binaryData)
                
                // If it's the SAME product we recently had, skip the progress bar and show instantly
                if let last = lastScannedProduct, last.name == product.name && last.brand == product.brand {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        scannedProduct = product
                        lastScannedProduct = product
                        scanState = .loaded
                        isProcessing = false
                        isScanSuccess = false
                    }
                    return
                }
                
                // NEW Product: Show snappy success + progress bar
                withAnimation(.spring(response: 0.3)) {
                    isScanSuccess = true
                }
                
                isProcessing = true
                scanProgress = 0
                
                withAnimation(.linear(duration: 0.8)) {
                    scanProgress = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scannedProduct = product
                        lastScannedProduct = product
                        scanState = .loaded
                        isProcessing = false
                        scanProgress = 0
                        isScanSuccess = false
                    }
                }
                return
            } catch {
                showErrorToast("Not a product QR: \(error.localizedDescription)")
            }
        }

        // Try decoding the raw string bytes as ProductQR
        if let rawData = code.data(using: .isoLatin1) {
            do {
                let product = try ProductQRCodec.decode(from: rawData)
                
                if let last = lastScannedProduct, last.name == product.name && last.brand == product.brand {
                    withAnimation(.spring(response: 0.4)) {
                        scannedProduct = product
                        lastScannedProduct = product
                        scanState = .loaded
                        isProcessing = false
                        isScanSuccess = false
                    }
                    return
                }
                
                withAnimation(.spring(response: 0.3)) {
                    isScanSuccess = true
                }
                
                isProcessing = true
                scanProgress = 0
                
                withAnimation(.linear(duration: 0.8)) {
                    scanProgress = 1.0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        scannedProduct = product
                        lastScannedProduct = product
                        scanState = .loaded
                        isProcessing = false
                        scanProgress = 0
                        isScanSuccess = false
                    }
                }
                return
            } catch {
                // Ignore
            }
        }

        // If we got here with base64 data that failed, error was already shown
        // For other random QR codes, show a brief hint
        if Data(base64Encoded: code) == nil {
            showErrorToast("Not a Product QR code")
        }
    }

    private func processFinalData(_ data: Data) {
        logger.log("STREAM: Assembly complete. Decoding product...")
        do {
            let product = try ProductQRCodec.decode(from: data)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                scannedProduct = product
                lastScannedProduct = product
                scanState = .loaded
                isProcessing = false
                isScanSuccess = false
            }
        } catch {
            showErrorToast("Corrupted stream: \(error.localizedDescription)")
        }
    }

    private func analyzeBufferBackground() {
        // Guard against multiple overlapping analysis tasks
        guard !isAnalyzing && !isProcessing else { return }
        
        let frames = bufferManager.getAllFrames()
        guard !frames.isEmpty else { return }
        
        isAnalyzing = true
        
        Task.detached(priority: .utility) {
            let result = decoder.decodeBatch(frames: frames)
            let codes = result.codes
            
            if !codes.isEmpty {
                await MainActor.run {
                    self.logger.log("BUFFER: Analyst found \(codes.count) codes in \(result.sampledCount) frames")
                }
            }
            
            for code in codes {
                await MainActor.run {
                    self.handleScannedCode(code)
                }
            }
            await MainActor.run {
                self.isAnalyzing = false
            }
        }
    }

    private func showErrorToast(_ message: String) {
        errorMessage = message
        withAnimation(.spring(response: 0.3)) {
            showError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showError = false
            }
        }
    }
}
