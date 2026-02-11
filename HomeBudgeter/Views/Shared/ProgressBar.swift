import SwiftUI

struct ProgressBar: View {
    let progress: Double
    let showPercentage: Bool
    let height: CGFloat
    let backgroundColor: Color
    let foregroundGradient: LinearGradient

    init(
        progress: Double,
        showPercentage: Bool = false,
        height: CGFloat = 8,
        backgroundColor: Color = .gray.opacity(0.2),
        foregroundGradient: LinearGradient? = nil
    ) {
        self.progress = min(max(progress, 0), 100)
        self.showPercentage = showPercentage
        self.height = height
        self.backgroundColor = backgroundColor
        self.foregroundGradient = foregroundGradient ?? Color.budgetGradient(percentage: progress)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)

                // Progress
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(foregroundGradient)
                    .frame(width: min(geometry.size.width * (progress / 100), geometry.size.width), height: height)
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // Percentage label
                if showPercentage {
                    Text("\(Int(progress))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, alignment: progress > 50 ? .trailing : .leading)
                        .offset(x: progress > 50 ? -4 : 4)
                }
            }
        }
        .frame(height: height)
    }
}

struct AnimatedProgressBar: View {
    let progress: Double
    let label: String?
    let valueLabel: String?

    @State private var animatedProgress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                HStack {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let valueLabel = valueLabel {
                        Text(valueLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }

            ProgressBar(progress: animatedProgress)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ProgressBar(progress: 25)
        ProgressBar(progress: 50, showPercentage: true)
        ProgressBar(progress: 75, height: 12)
        ProgressBar(progress: 100)
        ProgressBar(progress: 120) // Over budget

        AnimatedProgressBar(
            progress: 65,
            label: "Housing",
            valueLabel: "€650 / €1,000"
        )
    }
    .padding()
    .frame(width: 300)
}
