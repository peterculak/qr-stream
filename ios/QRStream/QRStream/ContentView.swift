import SwiftUI

extension Color {
    static let neonGreen = Color(red: 0.0, green: 1.0, blue: 0.0)
}

import QuickLook

enum AppTab { case scan, files }

struct ContentView: View {
    @StateObject private var fileStorage = FileStorage()
    @State private var selectedTab: AppTab = .scan

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ScannerTab(fileStorage: fileStorage)
                    .opacity(selectedTab == .scan ? 1 : 0)
                    .allowsHitTesting(selectedTab == .scan)

                FilesTab(fileStorage: fileStorage)
                    .opacity(selectedTab == .files ? 1 : 0)
                    .allowsHitTesting(selectedTab == .files)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom Retro Tab Bar
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.neonGreen)
                    .frame(height: 2)

                HStack(spacing: 0) {
                    TabBarButton(title: "SCANNER", isSelected: selectedTab == .scan) {
                        selectedTab = .scan
                    }

                    TabBarButton(title: "ARCHIVE", isSelected: selectedTab == .files) {
                        selectedTab = .files
                    }
                }
                .frame(height: 60)
                .background(Color.black)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct TabBarButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isSelected ? "[ \(title) ]" : "  \(title)  ")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(isSelected ? .black : .neonGreen)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .background(isSelected ? Color.neonGreen : Color.black)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scanner Tab

struct ScannerTab: View {
    @ObservedObject var fileStorage: FileStorage

    enum ScanState {
        case setup
        case scanning
        case complete(String, String, URL) // (content, filename, fileURL)
        case error(String)
    }

    @State private var password = ""
    @State private var scanState: ScanState = .setup
    @StateObject private var assembler = ChunkAssembler()
    @State private var speedDisplay = ""
    @State private var speedTimer: Timer?
    @State private var showSuccess = false
    @State private var showFilePreview = false
    @State private var savedFileURL: URL?
    @State private var quickLookURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch scanState {
                case .setup:
                    setupView
                case .scanning:
                    scanningView
                case .complete(_, let filename, let url):
                    completeView(filename: filename, fileURL: url)
                case .error(let msg):
                    errorView(message: msg)
                }
            }
            .navigationTitle("QR Stream")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Setup
    private var setupView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("[ QR STREAM ]")
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .foregroundColor(.neonGreen)

            Text("READY_TO_SCAN")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(.neonGreen.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                Text("> SECURE_KEY (OPTIONAL)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.neonGreen.opacity(0.7))

                SecureField("", text: $password, prompt: Text("_leave_empty_for_public").foregroundColor(.neonGreen.opacity(0.4)))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.neonGreen)
                    .padding()
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.neonGreen, lineWidth: 1)
                    )
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Button(action: {
                assembler.reset()
                scanState = .scanning
                speedDisplay = "0 B/s"
                startSpeedTimer()
            }) {
                Text("EXECUTE_SCAN")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.neonGreen)
                    .cornerRadius(2)
            }
            .padding(.horizontal, 32)
            .padding(.top, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Scanning
    private var scanningView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            QRScannerView { scannedString in
                handleScannedCode(scannedString)
            }
            .ignoresSafeArea()
            .opacity(0.5)
            .overlay(
                Rectangle()
                    .stroke(Color.neonGreen.opacity(0.8), lineWidth: 2)
                    .padding(30)
            )

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    if let total = assembler.totalChunks {
                        let received = assembler.receivedCount
                        let percent = min(1.0, Double(received) / Double(total))
                        let barWidth = 20
                        let filled = Int(percent * Double(barWidth))
                        let empty = max(0, barWidth - filled)
                        
                        Text("[\(String(repeating: "█", count: filled))\(String(repeating: "-", count: empty))]")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.neonGreen)
                            
                        Text(String(format: "%02d%% COMPLETE", Int(percent * 100)))
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.neonGreen)

                        HStack(spacing: 20) {
                            if let name = assembler.filename {
                                Text("FILE:\(name)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.neonGreen)
                                    .lineLimit(1)
                            }

                            if !speedDisplay.isEmpty {
                                Text("SPD:\(speedDisplay)")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.neonGreen)
                            }
                        }

                        Text("RCV: \(formatBytes(assembler.bytesReceived))")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.neonGreen)
                    } else {
                        Text("AWAITING_SIGNAL...")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.neonGreen)
                            .padding(.vertical, 10)
                    }

                    Button(action: {
                        stopSpeedTimer()
                        scanState = .setup
                    }) {
                        Text("[ ABORT ]")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.neonGreen)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.neonGreen, lineWidth: 1)
                )
                .padding()
            }
        }
    }

    // MARK: - Complete
    private func completeView(filename: String, fileURL: URL) -> some View {
        VStack(spacing: 32) {
            Spacer()

            Text("[ TRANSFER_COMPLETE ]")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.neonGreen)

            VStack(spacing: 8) {
                Text("FILE_SAVED_AS:")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.neonGreen.opacity(0.7))

                Text(filename)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.neonGreen)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.neonGreen.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    if isTextFile(url: fileURL) {
                        savedFileURL = fileURL
                        showFilePreview = true
                    } else {
                        quickLookURL = fileURL
                    }
                }) {
                    Text("> OPEN_FILE")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neonGreen)
                        .cornerRadius(2)
                }

                Button(action: {
                    showSuccess = false
                    scanState = .setup
                    password = ""
                    assembler.reset()
                }) {
                    Text("> SCAN_ANOTHER")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.neonGreen)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.neonGreen, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            showSuccess = true
            // Auto-open file after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if isTextFile(url: fileURL) {
                    savedFileURL = fileURL
                    showFilePreview = true
                } else {
                    quickLookURL = fileURL
                }
            }
        }
        .sheet(isPresented: $showFilePreview) {
            if let url = savedFileURL {
                FileViewerSheet(url: url, filename: filename)
            }
        }
        .quickLookPreview($quickLookURL)
    }

    private func isTextFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExtensions: Set<String> = [
            "txt", "md", "json", "csv", "xml", "html", "htm", "css", "js", "ts", "py", "sh",
            "yaml", "yml", "toml", "cfg", "ini", "log", "swift", "c", "cpp", "h", "java", "php"
        ]
        return textExtensions.contains(ext)
    }

    // MARK: - Error
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text("[ SYSTEM_ERROR ]")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.neonGreen)
                .padding()
                .overlay(
                    Rectangle()
                        .stroke(Color.neonGreen, style: StrokeStyle(lineWidth: 2, dash: [4]))
                )

            Text(message)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundColor(.neonGreen)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: {
                scanState = .setup
                assembler.reset()
            }) {
                Text("> RETRY")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.neonGreen)
                    .cornerRadius(2)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Logic
    private func handleScannedCode(_ code: String) {
        let added = assembler.addChunk(code)
        if added && assembler.isComplete {
            stopSpeedTimer()
            do {
                let decoded = try CryptoHelper.decrypt(
                    assembledData: assembler.assemble(),
                    password: password
                )
                let filename = assembler.filename ?? "received.txt"
                let url = fileStorage.save(content: decoded, filename: filename)
                showSuccess = false
                scanState = .complete(decoded, filename, url)
            } catch {
                scanState = .error(error.localizedDescription)
            }
        }
    }

    private func startSpeedTimer() {
        speedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            speedDisplay = assembler.speedString
        }
    }

    private func stopSpeedTimer() {
        speedTimer?.invalidate()
        speedTimer = nil
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        return String(format: "%.1f KB", Double(bytes) / 1024.0)
    }
}

// MARK: - Files Tab

struct FilesTab: View {
    @ObservedObject var fileStorage: FileStorage
    
    @State private var showFilePreview = false
    @State private var savedFileURL: URL?
    @State private var quickLookURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if fileStorage.files.isEmpty {
                    VStack(spacing: 12) {
                        Text("NO_FILES_FOUND")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.neonGreen.opacity(0.5))
                        Text("> AWAITING_DATA...")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.neonGreen.opacity(0.3))
                    }
                } else {
                    List {
                        ForEach(fileStorage.files) { file in
                            Button {
                                if isTextFile(url: file.url) {
                                    savedFileURL = file.url
                                    showFilePreview = true
                                } else {
                                    quickLookURL = file.url
                                }
                            } label: {
                                HStack {
                                    Text(">")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.neonGreen)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(file.name)
                                            .foregroundColor(.neonGreen)
                                            .font(.system(.body, design: .monospaced))
                                        Text("\(formatSize(file.size)) | \(formatDate(file.date))")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundColor(.neonGreen.opacity(0.6))
                                    }

                                    Spacer()

                                    // Real native ShareLink component
                                    ShareLink(item: file.url) {
                                        Image(systemName: "square.and.arrow.up")
                                            .foregroundColor(.neonGreen)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.black)
                            .listRowSeparatorTint(.neonGreen.opacity(0.3))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    fileStorage.delete(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.neonGreen)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("DATA_ARCHIVE")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePreview) {
                if let url = savedFileURL {
                    FileViewerSheet(url: url, filename: url.lastPathComponent)
                }
            }
            .quickLookPreview($quickLookURL)
            .onAppear {
                fileStorage.refresh()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func isTextFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExtensions: Set<String> = [
            "txt", "md", "json", "csv", "xml", "html", "htm", "css", "js", "ts", "py", "sh",
            "yaml", "yml", "toml", "cfg", "ini", "log", "swift", "c", "cpp", "h", "java", "php"
        ]
        return textExtensions.contains(ext)
    }

    private func iconForFile(_ name: String) -> String {
        if name.hasSuffix(".md") { return "doc.text" }
        if name.hasSuffix(".txt") { return "doc.plaintext" }
        if name.hasSuffix(".json") { return "curlybraces" }
        return "doc"
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        return "\(bytes / 1024) KB"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - File Viewer

struct FileViewerSheet: View {
    let url: URL
    let filename: String
    @Environment(\.dismiss) var dismiss
    @State private var copied = false

    private var content: String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? "Unable to read file"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // File info header
                    HStack(spacing: 12) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.purple)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(filename)
                                .font(.headline)
                                .foregroundColor(.white)

                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                            Text("\(size) bytes · \(content.components(separatedBy: .newlines).count) lines")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.03))

                    Divider().background(Color.white.opacity(0.1))

                    // Content with line numbers
                    VStack(alignment: .leading, spacing: 0) {
                        let lines = content.components(separatedBy: .newlines)
                        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 36, alignment: .trailing)
                                    .padding(.trailing, 8)

                                Text(line.isEmpty ? " " : line)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            .padding(.vertical, 1)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
            .navigationTitle(filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            UIPasteboard.general.string = content
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundColor(copied ? .neonGreen : .white)
                        }

                        ShareLink(item: url)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
