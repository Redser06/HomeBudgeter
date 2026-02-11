//
//  SavingsGoalView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

struct SavingsGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SavingsGoalViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Goals")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Track progress toward your financial goals")
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button {
                    viewModel.showingCreateSheet = true
                } label: {
                    Label("Add Goal", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Overview Cards
            HStack(spacing: 16) {
                SavingsOverviewCard(
                    title: "Total Saved",
                    amount: Double(truncating: viewModel.totalSaved as NSNumber),
                    subtitle: "Across all goals",
                    color: .budgetHealthy
                )
                SavingsOverviewCard(
                    title: "Total Target",
                    amount: Double(truncating: viewModel.totalTarget as NSNumber),
                    subtitle: "Combined goal amount",
                    color: .primaryBlue
                )
                SavingsOverviewCard(
                    title: "Active Goals",
                    value: "\(viewModel.activeGoals.count)",
                    subtitle: "\(viewModel.completedGoals.count) completed",
                    color: .orange
                )
            }
            .padding(.horizontal)

            // Goals List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.goals.isEmpty {
                        ContentUnavailableView(
                            "No Savings Goals",
                            systemImage: "target",
                            description: Text("Create your first savings goal to start tracking")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.goals) { goal in
                            SavingsGoalRow(goal: goal) {
                                viewModel.selectedGoal = goal
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadGoals(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            AddSavingsGoalSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $viewModel.selectedGoal) { goal in
            EditSavingsGoalSheet(viewModel: viewModel, goal: goal, modelContext: modelContext)
        }
    }
}

// MARK: - Overview Card

struct SavingsOverviewCard: View {
    let title: String
    var amount: Double? = nil
    var value: String? = nil
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let amount = amount {
                Text(CurrencyFormatter.shared.format(amount))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else if let value = value {
                Text(value)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Goal Row

struct SavingsGoalRow: View {
    let goal: SavingsGoal
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0

    var progressColor: Color {
        let pct = goal.progressPercentage
        if pct >= 90 { return .budgetDanger }
        if pct >= 75 { return .orange }
        return .budgetHealthy
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: goal.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(goal.priority.color)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(goal.name)
                        .font(.headline)

                    if goal.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    Spacer()

                    Text(goal.priority.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(goal.priority.color.opacity(0.15))
                        .foregroundColor(goal.priority.color)
                        .cornerRadius(4)
                }

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressColor)
                            .frame(width: geometry.size.width * (animatedProgress / 100), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(CurrencyFormatter.shared.format(Double(truncating: goal.currentAmount as NSNumber))) saved")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(CurrencyFormatter.shared.format(Double(truncating: goal.targetAmount as NSNumber))) target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Right side info
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(goal.progressPercentage))%")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(progressColor)

                if let days = goal.daysRemaining {
                    Text(days > 0 ? "\(days)d left" : "Overdue")
                        .font(.caption)
                        .foregroundColor(days > 0 ? .secondary : .red)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                animatedProgress = goal.progressPercentage
            }
        }
        .onChange(of: goal.progressPercentage) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Add Goal Sheet

struct AddSavingsGoalSheet: View {
    var viewModel: SavingsGoalViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var targetAmount: Double = 0
    @State private var hasDeadline = false
    @State private var deadline = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var priority: GoalPriority = .medium
    @State private var selectedIcon = "target"
    @State private var notes = ""

    private let iconOptions = ["target", "house.fill", "car.fill", "airplane", "banknote", "laptopcomputer", "gift", "heart.fill", "graduationcap.fill", "briefcase.fill"]

    var body: some View {
        VStack(spacing: 20) {
            Text("New Savings Goal")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Goal Name", text: $name)

                HStack {
                    Text("Target Amount")
                    Spacer()
                    TextField("Amount", value: $targetAmount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                Picker("Priority", selection: $priority) {
                    ForEach(GoalPriority.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }

                Picker("Icon", selection: $selectedIcon) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }

                Toggle("Set Deadline", isOn: $hasDeadline)

                if hasDeadline {
                    DatePicker("Deadline", selection: $deadline, displayedComponents: .date)
                }

                TextField("Notes (optional)", text: $notes)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Create Goal") {
                    viewModel.createGoal(
                        name: name,
                        targetAmount: Decimal(targetAmount),
                        deadline: hasDeadline ? deadline : nil,
                        priority: priority,
                        icon: selectedIcon,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || targetAmount <= 0)
            }
        }
        .padding()
        .frame(width: 420, height: 520)
    }
}

// MARK: - Edit Goal Sheet

struct EditSavingsGoalSheet: View {
    var viewModel: SavingsGoalViewModel
    let goal: SavingsGoal
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var targetAmount: Double
    @State private var priority: GoalPriority
    @State private var contributionAmount: Double = 0
    @State private var showingDeleteConfirmation = false

    init(viewModel: SavingsGoalViewModel, goal: SavingsGoal, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.goal = goal
        self.modelContext = modelContext
        _name = State(initialValue: goal.name)
        _targetAmount = State(initialValue: Double(truncating: goal.targetAmount as NSNumber))
        _priority = State(initialValue: goal.priority)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: goal.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(goal.priority.color)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Edit Goal")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(Int(goal.progressPercentage))% complete")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Form {
                Section("Details") {
                    TextField("Name", text: $name)

                    HStack {
                        Text("Target")
                        Spacer()
                        TextField("Amount", value: $targetAmount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(GoalPriority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }

                Section("Progress") {
                    LabeledContent("Saved", value: CurrencyFormatter.shared.format(Double(truncating: goal.currentAmount as NSNumber)))
                    LabeledContent("Remaining", value: CurrencyFormatter.shared.format(Double(truncating: goal.remainingAmount as NSNumber)))
                }

                Section("Add Contribution") {
                    HStack {
                        TextField("Amount", value: $contributionAmount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                            .multilineTextAlignment(.trailing)

                        Button("Add") {
                            viewModel.addContribution(goal: goal, amount: Decimal(contributionAmount), modelContext: modelContext)
                            contributionAmount = 0
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(contributionAmount <= 0)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Save") {
                    goal.name = name
                    goal.targetAmount = Decimal(targetAmount)
                    goal.priority = priority
                    viewModel.updateGoal(goal: goal, modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || targetAmount <= 0)
            }
        }
        .padding()
        .frame(width: 420, height: 550)
        .confirmationDialog("Delete Goal?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteGoal(goal: goal, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the \"\(goal.name)\" savings goal.")
        }
    }
}

#Preview {
    SavingsGoalView()
}
