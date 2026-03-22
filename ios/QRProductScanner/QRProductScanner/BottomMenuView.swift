import SwiftUI

/// A slide-up bottom menu containing theme selection.
/// Appears when user taps on the camera view (when no card is showing).
struct BottomMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager

    @State private var dragOffset: CGFloat = 0

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dimmed background
            if isPresented {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }
                    .transition(.opacity)
            }

            // Menu panel
            if isPresented {
                VStack(spacing: 0) {
                    // Drag handle
                    Capsule()
                        .fill(theme.textColor.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    // Title
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(theme.accentColor)
                            .font(.system(size: 18))

                        Text("Appearance")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(theme.textColor)

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // Theme selector
                    VStack(spacing: 12) {
                        ForEach(AppTheme.allCases) { appTheme in
                            ThemeRow(
                                appTheme: appTheme,
                                isSelected: themeManager.currentTheme == appTheme,
                                currentTheme: theme
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    themeManager.currentTheme = appTheme
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Version info
                    Text("QR Product Scanner v1.0")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.subtextColor.opacity(0.4))
                        .padding(.bottom, 8)
                }
                .padding(.bottom, 20)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(theme.cardBackground)
                        .shadow(color: .black.opacity(0.4), radius: 30, y: -10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                )
                .offset(y: max(0, dragOffset))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            if value.translation.height > 100 {
                                dismiss()
                            } else {
                                withAnimation(.spring(response: 0.3)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
    }

    private func dismiss() {
        dragOffset = 0
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}

// MARK: - Theme Row

private struct ThemeRow: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let currentTheme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Color swatches
                HStack(spacing: 4) {
                    ForEach(Array(appTheme.swatchColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                    }
                }

                // Theme icon
                Image(systemName: appTheme.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? appTheme.accentColor : currentTheme.subtextColor)
                    .frame(width: 22)

                // Theme name
                Text(appTheme.displayName)
                    .font(.system(size: 15, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? appTheme.primaryColor : currentTheme.textColor)

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(appTheme.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? appTheme.primaryColor.opacity(0.12) : currentTheme.backgroundColor.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? appTheme.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
