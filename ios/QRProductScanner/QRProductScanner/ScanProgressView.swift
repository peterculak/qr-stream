import SwiftUI
import Foundation

/// A subtle scanning progress indicator displayed in the center of the camera view.
/// Shows a pulsing/scanning animation while the app is looking for QR codes.
struct ScanProgressView: View {
    @EnvironmentObject var themeManager: ThemeManager

    @State private var isAnimating = false
    @State private var scanLineOffset: CGFloat = -60
    @State private var pulseOpacity: Double = 0.3
    @State private var successScale: CGFloat = 1.0

    var isSuccess: Bool = false
    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ZStack {
            // Outer reticle
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSuccess ? Color.green : theme.primaryColor.opacity(pulseOpacity),
                    lineWidth: 2
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isSuccess ? CGFloat(1.05) : successScale)

            // Corner accents
            ForEach(0..<4, id: \.self) { corner in
                CornerAccent(corner: corner, color: isSuccess ? Color.green : theme.accentColor)
                    .scaleEffect(isSuccess ? CGFloat(1.1) : CGFloat(1.0))
            }

            // Scanning line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            theme.accentColor.opacity(0),
                            theme.accentColor.opacity(0.8),
                            theme.accentColor.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 160, height: 2)
                .offset(y: scanLineOffset)

            // Center dot
            Circle()
                .fill(theme.accentColor.opacity(0.4))
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.3 : 0.8)

            // Label
            VStack {
                Spacer()
                    .frame(height: 130)

                Text("SCANNING")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(theme.accentColor.opacity(0.7))
                    .tracking(4)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scanLineOffset = 60
                pulseOpacity = 0.7
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Corner Accent

private struct CornerAccent: View {
    let corner: Int
    let color: Color

    private let size: CGFloat = 24
    private let thickness: CGFloat = 3

    var body: some View {
        Canvas { context, canvasSize in
            var path = Path()

            switch corner {
            case 0: // Top-left
                path.move(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
            case 1: // Top-right
                path.move(to: CGPoint(x: canvasSize.width - size, y: 0))
                path.addLine(to: CGPoint(x: canvasSize.width, y: 0))
                path.addLine(to: CGPoint(x: canvasSize.width, y: size))
            case 2: // Bottom-left
                path.move(to: CGPoint(x: 0, y: canvasSize.height - size))
                path.addLine(to: CGPoint(x: 0, y: canvasSize.height))
                path.addLine(to: CGPoint(x: size, y: canvasSize.height))
            case 3: // Bottom-right
                path.move(to: CGPoint(x: canvasSize.width - size, y: canvasSize.height))
                path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
                path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height - size))
            default:
                break
            }

            context.stroke(path, with: .color(color), lineWidth: thickness)
        }
        .frame(width: 200, height: 200)
    }
}
