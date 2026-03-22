import SwiftUI
import Foundation
import UIKit

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
        case webApp
        case initializing // New: For the fake loader/splash

        static func == (lhs: ScanState, rhs: ScanState) -> Bool {
            switch (lhs, rhs) {
            case (.scanning, .scanning): return true
            case (.loaded, .loaded): return true
            case (.webApp, .webApp): return true
            case (.initializing, .initializing): return true
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
    @State private var receivedHtml: String = ""
    @StateObject private var logger = DebugLogger.shared
    @State private var showLogs = false
    @State private var showLibrary = false
    @State private var splashProgress: CGFloat = 0.0
    @State private var isReadyToStart = false
    
    // Multi-QR Assembly
    @State private var chunks: [Int: String] = [:]
    @State private var totalChunks: Int = 0
    @State private var assemblyProgress: Double = 0.0

    @State private var savedApps: [SavedApp] = []

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // MARK: - Camera Layer (always visible)
            CameraScannerView(
                onCodeScanned: { scannedString in
                    handleScannedCode(scannedString)
                },
                appHtml: scanState == .webApp ? receivedHtml : nil
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
                
                // Assembly Progress HUD
                if totalChunks > 0 {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text("LINKING_TACTICAL_CHUNKS")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(theme.accentColor)
                            
                            HStack(spacing: 4) {
                                ForEach(Array(0..<totalChunks), id: \.self) { idx in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(chunks[idx] != nil ? theme.accentColor : Color.white.opacity(0.2))
                                        .frame(width: 20, height: 4)
                                }
                            }
                            
                            Text("\(chunks.count) / \(totalChunks)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.bottom, 120)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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

            // MARK: - Web App / Game Overlay (Controls)
            if scanState == .webApp {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                scanState = .scanning
                                receivedHtml = ""
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(theme.accentColor)
                                .padding(20)
                        }
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            // MARK: - Mission Start / Splash Overlay
            if scanState == .initializing {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(theme.accentColor)
                        
                        Text("MISSION_BRIEFING")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                            .tracking(4)
                        
                        // Controls Tutorial
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "arrow.left.and.right")
                                Text("DRAG: MOVE")
                            }
                            HStack {
                                Image(systemName: "arrow.down")
                                Text("PULL: FALL")
                            }
                            HStack {
                                Image(systemName: "hand.tap")
                                Text("TAP: ROTATE")
                            }
                        }
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        
                        VStack(spacing: 20) {
                            // Boot Logs
                            VStack(alignment: .leading, spacing: 4) {
                                Text("> AUTHENTICATING_APP_SIGNATURE...")
                                Text("> DECRYPTING_AR_PAYLOAD_CHUNK_0...")
                                Text("> STABILIZING_GRAPHICS_BUFFER...")
                                    .opacity(splashProgress > 0.5 ? 1 : 0)
                                Text("> LINK_ESTABLISHED: READY_TO_BOOT")
                                    .opacity(splashProgress > 0.9 ? 1 : 0)
                            }
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentColor.opacity(0.6))
                            .frame(width: 240, alignment: .leading)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("NEURAL_LINK")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                    Spacer()
                                    Text("\(Int((totalChunks > 0 ? (assemblyProgress * 100) : (splashProgress * 100))))%")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(theme.accentColor)
                                
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 240, height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(theme.accentColor)
                                        .frame(width: 240 * (totalChunks > 0 ? assemblyProgress : splashProgress), height: 8)
                                        .shadow(color: theme.accentColor, radius: 15)
                                }
                            }
                            
                            // Start Button
                            if isReadyToStart {
                                Button {
                                    withAnimation(.easeOut(duration: 0.8)) {
                                        scanState = .webApp
                                    }
                                } label: {
                                    Text("START THE GAME")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 40)
                                        .padding(.vertical, 15)
                                        .background(theme.accentColor)
                                        .cornerRadius(8)
                                        .shadow(color: theme.accentColor, radius: 20)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.top, 30)
                    }
                }
                .transition(.opacity)
                .zIndex(25)
            }

            // MARK: - AR Library Overlay
            if showLibrary {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { showLibrary = false } }
                    
                    VStack(spacing: 0) {
                        HStack {
                            Text("AR_LIBRARY")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.accentColor)
                            Spacer()
                            Button("CLOSE") { withAnimation { showLibrary = false } }
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.accentColor)
                        }
                        .padding()
                        .background(Color.black.opacity(0.85))
                        
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(savedApps) { app in
                                    Button(action: { launchApp(app.payload) }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(app.name)
                                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                                    .foregroundColor(.white)
                                                Text(app.dateString)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.white.opacity(0.5))
                                            }
                                            Spacer()
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(theme.accentColor)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                    }
                                }
                                
                                if savedApps.isEmpty {
                                    Text("NO_APPS_SCANNED")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                        .padding(40)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                    }
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.accentColor.opacity(0.3), lineWidth: 1))
                    .padding(30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(35)
            }

            // MARK: - Processing Overlay
            if isProcessing {
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
                                .frame(width: 200 * scanProgress, height: 4)
                                .shadow(color: theme.accentColor.opacity(0.5), radius: 4)
                        }
                        
                        Text("DECODING")
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
                        
                        Button(action: { withAnimation { showLibrary = true } }) {
                            HStack {
                                Image(systemName: "square.grid.2x2.fill")
                                Text("OPEN AR LIBRARY")
                            }
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(theme.accentColor)
                            .cornerRadius(4)
                        }
                        .padding(.bottom, 8)
                        
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
        .statusBarHidden(true)
        .onAppear { loadSavedApps() }
    }

    // MARK: - QR Code Handling

    private func handleScannedCode(_ code: String) {
        // Don't process while card is showing or menu is open
        guard scanState == .scanning, !showMenu else { return }

        // 1. Check for Multi-QR Chunks (Format: AR:IDX:TOTAL:BASE64)
        if code.hasPrefix("AR:") {
            let parts = code.components(separatedBy: ":")
            if parts.count == 4, 
               let idx = Int(parts[1]), 
               let total = Int(parts[2]) {
                
                if total != totalChunks {
                    chunks = [:] // New assembly session
                    totalChunks = total
                }
                
                chunks[idx] = parts[3]
                assemblyProgress = Double(chunks.count) / Double(totalChunks)
                logger.log("SCAN: Chunk \(idx+1)/\(total) received")
                
                if chunks.count == totalChunks {
                    // Assemble
                    let fullBase64 = (0..<totalChunks).compactMap { chunks[$0] }.joined()
                    if let data = Data(base64Encoded: fullBase64),
                       let html = String(data: data, encoding: .utf8) {
                        launchApp(html)
                        chunks = [:] // Reset
                        totalChunks = 0
                        assemblyProgress = 0
                    }
                }
            }
            return
        }

        // 2. Fallback for Legacy Single-QR (APP:BASE64)
        if code.hasPrefix("APP:") {
            let base64Part = String(code.dropFirst(4))
            if let decodedData = Data(base64Encoded: base64Part),
               let htmlString = String(data: decodedData, encoding: .utf8) {
                saveApp(html: htmlString)
                launchApp(htmlString)
                return
            }
        }

        // 2. Try as a Stream Chunk (Deprecated in this branch)
        /*
        if assembler.addChunk(code) {
           ...
        }
        */

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


    // MARK: - AR App Helpers
    
    private func launchApp(_ html: String) {
        logger.log("AR_HUD: Initializing launch sequence...")
        withAnimation(.spring()) {
            isScanSuccess = true
            receivedHtml = html
            scanState = .initializing
            showLibrary = false
            splashProgress = 0
        }
        
        // Animate the "Neural Link" progress bar
        withAnimation(.linear(duration: 1.5)) {
            splashProgress = 1.0
        }
        
        // Start Button Preparation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
                isReadyToStart = true
            }
        }
    }
    
    private func saveApp(html: String) {
        let newApp = SavedApp(name: "AR_TETRIS_01", payload: html, date: Date())
        if !savedApps.contains(where: { $0.payload == html }) {
            savedApps.insert(newApp, at: 0)
            if savedApps.count > 10 { savedApps = Array(savedApps.prefix(10)) }
            
            // Persist
            if let data = try? JSONEncoder().encode(savedApps) {
                UserDefaults.standard.set(data, forKey: "ar_library_v3")
                logger.log("LIBRARY: App saved to persistent storage")
            }
        }
    }
    
    private func loadSavedApps() {
        if let data = UserDefaults.standard.data(forKey: "ar_library_v3"),
           let decoded = try? JSONDecoder().decode([SavedApp].self, from: data) {
            savedApps = decoded
            logger.log("LIBRARY: Loaded \(savedApps.count) saved apps")
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

// MARK: - Supporting Types

struct SavedApp: Identifiable, Codable {
    let id: UUID
    let name: String
    let payload: String
    let date: Date
    
    init(id: UUID = UUID(), name: String, payload: String, date: Date) {
        self.id = id
        self.name = name
        self.payload = payload
        self.date = date
    }
    
    var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}
