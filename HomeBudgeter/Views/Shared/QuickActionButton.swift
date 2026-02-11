import SwiftUI

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct QuickActionRow: View {
    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                title: "Add Income",
                icon: "arrow.down.circle.fill",
                color: .green
            ) {
                // Add income action
            }

            QuickActionButton(
                title: "Add Expense",
                icon: "arrow.up.circle.fill",
                color: .red
            ) {
                // Add expense action
            }

            QuickActionButton(
                title: "Upload Doc",
                icon: "doc.badge.plus",
                color: .blue
            ) {
                // Upload document action
            }

            QuickActionButton(
                title: "Transfer",
                icon: "arrow.left.arrow.right",
                color: .purple
            ) {
                // Transfer action
            }
        }
    }
}

struct LargeActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding()
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        QuickActionRow()

        LargeActionButton(
            title: "Add Transaction",
            subtitle: "Record income or expense",
            icon: "plus.circle.fill",
            gradient: Color.incomeGradient
        ) {
            // Action
        }
    }
    .padding()
    .frame(width: 500)
}
