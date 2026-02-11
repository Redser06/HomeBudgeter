//
//  BudgetView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

struct BudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BudgetViewModel()
    @State private var showingAddBudget = false
    @State private var selectedBudget: BudgetCategory?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Budget")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Manage your spending limits")
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button {
                    showingAddBudget = true
                } label: {
                    Label("Add Budget", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Overview Cards
            HStack(spacing: 16) {
                BudgetOverviewCard(
                    title: "Total Budget",
                    amount: viewModel.totalBudget,
                    subtitle: "Monthly allocation",
                    color: .primaryBlue
                )
                BudgetOverviewCard(
                    title: "Spent",
                    amount: viewModel.totalSpent,
                    subtitle: "\(Int(viewModel.spentPercentage))% of budget",
                    color: Color.budgetStatusColor(percentage: viewModel.spentPercentage)
                )
                BudgetOverviewCard(
                    title: "Remaining",
                    amount: viewModel.remaining,
                    subtitle: "Left to spend",
                    color: viewModel.remaining >= 0 ? .budgetHealthy : .budgetDanger
                )
            }
            .padding(.horizontal)

            // Budget Categories List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.budgetCategories.isEmpty {
                        ContentUnavailableView(
                            "No Budgets Set",
                            systemImage: "dollarsign.circle",
                            description: Text("Create your first budget category to start tracking")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.budgetCategories) { category in
                            BudgetCategoryRow(
                                category: category,
                                onTap: {
                                    selectedBudget = category
                                },
                                onBudgetUpdate: { newAmount in
                                    viewModel.updateBudget(for: category, amount: Decimal(newAmount), modelContext: modelContext)
                                }
                            )
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadCategories(modelContext: modelContext)
        }
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $selectedBudget) { budget in
            EditBudgetSheet(viewModel: viewModel, budget: budget, modelContext: modelContext)
        }
    }
}

struct BudgetOverviewCard: View {
    let title: String
    let amount: Double
    let subtitle: String
    let color: Color

    @State private var animatedAmount: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(CurrencyFormatter.shared.format(animatedAmount))
                .font(.system(.title, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animatedAmount = amount
            }
        }
        .onChange(of: amount) { _, newValue in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedAmount = newValue
            }
        }
    }
}

struct BudgetCategoryRow: View {
    let category: BudgetCategory
    let onTap: () -> Void
    let onBudgetUpdate: (Double) -> Void

    @State private var isEditing = false
    @State private var editedAmount: String = ""
    @State private var animatedProgress: Double = 0
    @FocusState private var isTextFieldFocused: Bool

    var progress: Double {
        guard category.budgeted > 0 else { return 0 }
        return min((category.spent / category.budgeted) * 100, 100)
    }

    var progressColor: Color {
        Color.budgetStatusColor(percentage: progress)
    }

    var categoryColor: Color {
        category.type.color
    }

    var body: some View {
        HStack(spacing: 16) {
            // Category Icon with category-specific color
            Image(systemName: category.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(categoryColor)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Edit button
                    Button {
                        onTap()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Progress Bar with animation
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        // Progress with animation
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * (animatedProgress / 100), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    // Spent amount
                    Text("\(CurrencyFormatter.shared.format(category.spent)) spent")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Budgeted amount - inline editable
                    if isEditing {
                        HStack(spacing: 4) {
                            Text(CurrencyFormatter.shared.currencySymbol)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Amount", text: $editedAmount)
                                .font(.caption)
                                .frame(width: 80)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTextFieldFocused)
                                .onSubmit {
                                    saveEditedAmount()
                                }
                                .onExitCommand {
                                    cancelEditing()
                                }
                        }
                    } else {
                        Text("\(CurrencyFormatter.shared.format(category.budgeted)) budgeted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                startEditing()
                            }
                    }
                }
            }

            Spacer()

            // Remaining amount
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.shared.format(category.remaining))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(category.remaining >= 0 ? .budgetHealthy : .budgetDanger)
                Text(category.remaining >= 0 ? "remaining" : "over budget")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Percentage indicator
                Text("\(Int(100 - progress))% left")
                    .font(.caption2)
                    .foregroundColor(progressColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(progressColor.opacity(0.15))
                    .cornerRadius(4)
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }

    private func startEditing() {
        editedAmount = String(format: "%.2f", category.budgeted)
        isEditing = true
        isTextFieldFocused = true
    }

    private func saveEditedAmount() {
        if let amount = Double(editedAmount), amount > 0 {
            onBudgetUpdate(amount)
        }
        isEditing = false
    }

    private func cancelEditing() {
        isEditing = false
        editedAmount = ""
    }
}

struct AddBudgetSheet: View {
    var viewModel: BudgetViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: CategoryType = .other
    @State private var amount: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Budget Category")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Picker("Category", selection: $selectedType) {
                    ForEach(CategoryType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(type.color)
                            Text(type.rawValue)
                        }
                        .tag(type)
                    }
                }

                HStack {
                    Text("Monthly Budget")
                    Spacer()
                    TextField("Amount", value: $amount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                // Preview card
                Section("Preview") {
                    HStack {
                        Image(systemName: selectedType.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedType.color)
                            .cornerRadius(10)

                        VStack(alignment: .leading) {
                            Text(selectedType.rawValue)
                                .font(.headline)
                            Text(CurrencyFormatter.shared.format(amount))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Add Budget") {
                    viewModel.addBudget(name: selectedType.rawValue, amount: amount, icon: selectedType.icon, modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount <= 0)
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}

struct EditBudgetSheet: View {
    var viewModel: BudgetViewModel
    let budget: BudgetCategory
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double
    @State private var showingDeleteConfirmation = false

    init(viewModel: BudgetViewModel, budget: BudgetCategory, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.budget = budget
        self.modelContext = modelContext
        _amount = State(initialValue: budget.budgeted)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header with category icon and name
            HStack {
                Image(systemName: budget.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(budget.type.color)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Edit Budget")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(budget.name)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 8)

            Form {
                Section("Budget Amount") {
                    HStack {
                        Text("Monthly Budget")
                        Spacer()
                        TextField("Amount", value: $amount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Current Status") {
                    LabeledContent("Spent This Month", value: CurrencyFormatter.shared.format(budget.spent))
                    LabeledContent("Remaining") {
                        Text(CurrencyFormatter.shared.format(budget.remaining))
                            .foregroundColor(budget.remaining >= 0 ? .budgetHealthy : .budgetDanger)
                    }
                    LabeledContent("Usage") {
                        Text("\(Int(budget.percentageUsed))%")
                            .foregroundColor(budget.statusColor)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    viewModel.updateBudget(budget, name: budget.name, amount: amount, modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount <= 0)
            }
        }
        .padding()
        .frame(width: 380, height: 400)
        .confirmationDialog(
            "Delete Budget?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteBudget(budget, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the \(budget.name) budget. Your transactions will not be deleted.")
        }
    }
}

#Preview {
    BudgetView()
}
