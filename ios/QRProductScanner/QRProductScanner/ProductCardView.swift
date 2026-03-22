import SwiftUI

/// Displays a product card with thumbnail and nutritional information.
/// Appears as a floating card over the camera feed after scanning.
struct ProductCardView: View {
    let product: ProductData
    let onDismiss: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var appeared = false

    private var theme: AppTheme { themeManager.currentTheme }

    var body: some View {
        VStack(spacing: 0) {
            // Header with thumbnail & product name
            HStack(spacing: 16) {
                // Thumbnail
                Group {
                    if let image = product.thumbnailImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 28))
                            .foregroundColor(theme.accentColor)
                    }
                }
                .frame(width: 64, height: 64)
                .background(theme.backgroundColor.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.primaryColor.opacity(0.3), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name.isEmpty ? "Unknown Product" : product.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(theme.textColor)
                        .lineLimit(2)

                    if !product.brand.isEmpty {
                        Text(product.brand)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(theme.subtextColor)
                    }

                    if !product.category.isEmpty {
                        Text(product.category.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(theme.accentColor.opacity(0.15))
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.75))
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Nutritional info
            VStack(spacing: 0) {
                // Serving size header
                if !product.servingSize.isEmpty {
                    HStack {
                        Text("Per \(product.servingSize)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(theme.subtextColor)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 8)
                }

                // Calories hero
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CALORIES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.subtextColor)
                            .tracking(2)
                        Text("\(product.calories)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(theme.accentColor)
                        Text("kcal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.subtextColor)
                    }

                    Spacer()

                    // Macro ring
                    MacroRing(product: product, theme: theme)
                        .frame(width: 80, height: 80)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.75))
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Nutrient grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    NutrientCell(label: "Fat", value: formatGrams(product.fatGrams), unit: "g", theme: theme)
                    NutrientCell(label: "Carbs", value: formatGrams(product.carbsGrams), unit: "g", theme: theme)
                    NutrientCell(label: "Protein", value: formatGrams(product.proteinGrams), unit: "g", theme: theme)
                    NutrientCell(label: "Sugar", value: formatGrams(product.sugarGrams), unit: "g", theme: theme)
                    NutrientCell(label: "Fiber", value: formatGrams(product.fiberGrams), unit: "g", theme: theme)
                    NutrientCell(label: "Sodium", value: "\(product.sodium)", unit: "mg", theme: theme)
                }
                .padding(20)
            }

            // Dismiss hint
            HStack {
                Spacer()
                Text("Tap anywhere to dismiss")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(theme.subtextColor.opacity(0.5))
                Spacer()
            }
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                appeared = true
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appeared = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }

    private func formatGrams(_ value: Double) -> String {
        if value == Double(Int(value)) {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Nutrient Cell

private struct NutrientCell: View {
    let label: String
    let value: String
    let unit: String
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(theme.subtextColor)
                .tracking(1)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.textColor)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.subtextColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
}

// MARK: - Macro Ring

private struct MacroRing: View {
    let product: ProductData
    let theme: AppTheme

    var body: some View {
        let total = product.fatGrams * 9 + product.carbsGrams * 4 + product.proteinGrams * 4
        let fatFrac = total > 0 ? (product.fatGrams * 9) / total : 0.33
        let carbsFrac = total > 0 ? (product.carbsGrams * 4) / total : 0.33
        let protFrac = total > 0 ? (product.proteinGrams * 4) / total : 0.34

        ZStack {
            // Fat arc
            Circle()
                .trim(from: 0, to: fatFrac)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Carbs arc
            Circle()
                .trim(from: fatFrac, to: fatFrac + carbsFrac)
                .stroke(theme.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Protein arc
            Circle()
                .trim(from: fatFrac + carbsFrac, to: fatFrac + carbsFrac + protFrac)
                .stroke(theme.secondaryColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("F•C•P")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.subtextColor)
            }
        }
    }
}
