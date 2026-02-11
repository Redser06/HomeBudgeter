import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let primaryAccent = Color("PrimaryAccent", bundle: nil)
    static let secondaryAccent = Color("SecondaryAccent", bundle: nil)

    // MARK: - Semantic Colors
    static let income = Color.green
    static let expense = Color.red
    static let transfer = Color.blue
    static let neutral = Color.gray

    // MARK: - Budget Status Colors (Design Spec)
    static let budgetHealthy = Color(red: 34/255, green: 197/255, blue: 94/255)   // #22C55E Success Green
    static let budgetWarning = Color(red: 245/255, green: 158/255, blue: 11/255)  // #F59E0B Warning Amber
    static let budgetDanger = Color(red: 239/255, green: 68/255, blue: 68/255)    // #EF4444 Danger Red

    // MARK: - Primary Accent (Design Spec)
    static let primaryBlue = Color(red: 59/255, green: 130/255, blue: 246/255)    // #3B82F6 Primary Blue
    static let neutralGray = Color(red: 107/255, green: 114/255, blue: 128/255)   // #6B7280 Neutral Gray

    // MARK: - Background Colors
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let appBackground = Color(nsColor: .windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: .underPageBackgroundColor)

    // MARK: - Text Colors
    static let primaryText = Color(nsColor: .labelColor)
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Fintech Palette
    static let fintechPrimary = Color(red: 0.0, green: 0.478, blue: 1.0)      // Vibrant blue
    static let fintechSecondary = Color(red: 0.345, green: 0.337, blue: 0.839) // Purple
    static let fintechSuccess = Color(red: 0.196, green: 0.843, blue: 0.294)   // Green
    static let fintechWarning = Color(red: 1.0, green: 0.584, blue: 0.0)       // Orange
    static let fintechError = Color(red: 1.0, green: 0.231, blue: 0.188)       // Red

    // MARK: - Chart Colors
    static let chartColors: [Color] = [
        .blue, .green, .orange, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .yellow, .gray
    ]

    // MARK: - Gradient Helpers
    static func budgetGradient(percentage: Double) -> LinearGradient {
        let color: Color
        if percentage >= 90 {
            color = .budgetDanger
        } else if percentage >= 75 {
            color = .budgetWarning
        } else {
            color = .budgetHealthy
        }

        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Returns a solid color based on budget percentage thresholds
    static func budgetStatusColor(percentage: Double) -> Color {
        if percentage >= 90 { return .budgetDanger }
        if percentage >= 75 { return .budgetWarning }
        return .budgetHealthy
    }

    static var incomeGradient: LinearGradient {
        LinearGradient(
            colors: [.green.opacity(0.7), .green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var expenseGradient: LinearGradient {
        LinearGradient(
            colors: [.red.opacity(0.7), .red],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var netWorthGradient: LinearGradient {
        LinearGradient(
            colors: [.fintechPrimary.opacity(0.7), .fintechSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - View Modifiers
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func statCardStyle() -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}
