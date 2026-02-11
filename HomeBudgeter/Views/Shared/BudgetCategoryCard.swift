import SwiftUI

struct BudgetCategoryCard: View {
    @Bindable var category: BudgetCategory
    @State private var isEditing = false
    @State private var editedBudget: String = ""
    @Environment(\.currencyFormatter) private var formatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                // Category icon and name
                HStack(spacing: 10) {
                    Image(systemName: category.type.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(category.type.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text(category.type.rawValue)
                        .font(.headline)
                }

                Spacer()

                // Edit button
                Button(action: {
                    isEditing.toggle()
                    if isEditing {
                        editedBudget = "\(category.budgetAmount)"
                    }
                }) {
                    Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil.circle")
                        .foregroundStyle(isEditing ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Budget input or display
            if isEditing {
                HStack {
                    Text(formatter.currencySymbol)
                        .foregroundStyle(.secondary)
                    TextField("Budget", text: $editedBudget)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            if let value = Decimal(string: editedBudget) {
                                category.budgetAmount = value
                            }
                            isEditing = false
                        }
                }
            } else {
                // Progress section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(formatter.format(category.spentAmount))
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("of \(formatter.format(category.budgetAmount))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(category.isOverBudget ? "Over!" : "\(Int(100 - category.percentageUsed))% left")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(category.statusColor)
                    }

                    ProgressBar(
                        progress: category.percentageUsed,
                        height: 10
                    )
                }
            }

            // Remaining amount
            if !isEditing {
                HStack {
                    if category.isOverBudget {
                        Label(
                            "\(formatter.format(abs(category.remainingAmount))) over budget",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    } else {
                        Label(
                            "\(formatter.format(category.remainingAmount)) remaining",
                            systemImage: "checkmark.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.green)
                    }

                    Spacer()

                    Text("\(category.transactions?.count ?? 0) transactions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(category.isOverBudget ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    let category = BudgetCategory(
        type: .groceries,
        budgetAmount: 500,
        spentAmount: 420
    )

    return BudgetCategoryCard(category: category)
        .frame(width: 320)
        .padding()
}
