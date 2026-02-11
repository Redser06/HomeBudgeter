import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let trend: Trend?
    let trendValue: String?
    let accentColor: Color

    enum Trend {
        case up, down, neutral

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "arrow.right"
            }
        }

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }
    }

    init(
        title: String,
        value: String,
        icon: String,
        trend: Trend? = nil,
        trendValue: String? = nil,
        accentColor: Color = .fintechPrimary
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.trend = trend
        self.trendValue = trendValue
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(accentColor)

                Spacer()

                if let trend = trend, let trendValue = trendValue {
                    HStack(spacing: 4) {
                        Image(systemName: trend.icon)
                            .font(.caption)
                        Text(trendValue)
                            .font(.caption)
                    }
                    .foregroundStyle(trend.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trend.color.opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .statCardStyle()
    }
}

#Preview {
    HStack(spacing: 16) {
        StatCard(
            title: "Monthly Income",
            value: "€4,250.00",
            icon: "arrow.down.circle.fill",
            trend: .up,
            trendValue: "+5.2%",
            accentColor: .green
        )

        StatCard(
            title: "Total Spending",
            value: "€2,847.32",
            icon: "arrow.up.circle.fill",
            trend: .down,
            trendValue: "-12%",
            accentColor: .red
        )

        StatCard(
            title: "Net Worth",
            value: "€45,230",
            icon: "chart.line.uptrend.xyaxis",
            trend: .up,
            trendValue: "+2.1%",
            accentColor: .fintechPrimary
        )
    }
    .padding()
}
