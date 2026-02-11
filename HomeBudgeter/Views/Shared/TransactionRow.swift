import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction
    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        HStack(spacing: 12) {
            // Category icon
            if let category = transaction.category {
                Image(systemName: category.type.icon)
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(category.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "questionmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Description and category
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(transaction.category?.type.rawValue ?? "Uncategorized")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // Date
            Text(transaction.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Amount
            Text(amountText)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(amountColor)
                .frame(minWidth: 80, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var amountText: String {
        let formatted = formatter.format(transaction.amount)
        switch transaction.type {
        case .income:
            return "+\(formatted)"
        case .expense:
            return "-\(formatted)"
        case .transfer:
            return formatted
        }
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: return .green
        case .expense: return .red
        case .transfer: return .blue
        }
    }
}

struct TransactionRowCompact: View {
    let description: String
    let amount: Decimal
    let category: CategoryType
    let date: Date
    let isIncome: Bool

    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(category.color)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(description)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(isIncome ? "+\(formatter.format(amount))" : "-\(formatter.format(amount))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isIncome ? .green : .red)
        }
    }
}

#Preview {
    let category = BudgetCategory(type: .groceries, budgetAmount: 500)
    let transaction = Transaction(
        amount: 45.99,
        descriptionText: "Weekly groceries at Tesco",
        type: .expense,
        isRecurring: true,
        category: category
    )

    return VStack {
        TransactionRow(transaction: transaction)

        Divider()

        TransactionRowCompact(
            description: "Coffee shop",
            amount: 4.50,
            category: .dining,
            date: Date(),
            isIncome: false
        )
    }
    .padding()
    .frame(width: 400)
}
