//
//  RecurringTransactionsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

struct RecurringTransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = RecurringViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Manage recurring income and expenses")
                        .foregroundColor(.secondary)
                }
                Spacer()

                if !viewModel.overdueTemplates.isEmpty {
                    Button {
                        viewModel.processOverdue(modelContext: modelContext)
                    } label: {
                        Label("Process Overdue", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Button {
                    viewModel.showingCreateSheet = true
                } label: {
                    Label("Add Recurring", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Overview Cards
            HStack(spacing: 16) {
                RecurringOverviewCard(
                    title: "Active",
                    value: "\(viewModel.activeTemplates.count + viewModel.overdueTemplates.count)",
                    subtitle: "Recurring items",
                    color: .primaryBlue
                )
                RecurringOverviewCard(
                    title: "Monthly Cost",
                    amount: Double(truncating: viewModel.monthlyCost as NSNumber),
                    subtitle: "Estimated monthly",
                    color: .orange
                )
                RecurringOverviewCard(
                    title: "Overdue",
                    value: "\(viewModel.overdueTemplates.count)",
                    subtitle: viewModel.overdueTemplates.isEmpty ? "All up to date" : "Needs attention",
                    color: viewModel.overdueTemplates.isEmpty ? .budgetHealthy : .budgetDanger
                )
            }
            .padding(.horizontal)

            // Templates List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.templates.isEmpty {
                        ContentUnavailableView(
                            "No Recurring Transactions",
                            systemImage: "repeat.circle",
                            description: Text("Add recurring income or expenses to track them automatically")
                        )
                        .padding(.top, 60)
                    } else {
                        // Overdue Section
                        if !viewModel.overdueTemplates.isEmpty {
                            Section {
                                ForEach(viewModel.overdueTemplates) { template in
                                    RecurringTemplateRow(template: template, isOverdue: true) {
                                        viewModel.selectedTemplate = template
                                    }
                                }
                            } header: {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text("Overdue")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }
                        }

                        // Active Section
                        if !viewModel.activeTemplates.isEmpty {
                            Section {
                                ForEach(viewModel.activeTemplates) { template in
                                    RecurringTemplateRow(template: template) {
                                        viewModel.selectedTemplate = template
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Active")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            }
                        }

                        // Paused Section
                        if !viewModel.pausedTemplates.isEmpty {
                            Section {
                                ForEach(viewModel.pausedTemplates) { template in
                                    RecurringTemplateRow(template: template, isPaused: true) {
                                        viewModel.selectedTemplate = template
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Paused")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadTemplates(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            AddRecurringSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $viewModel.selectedTemplate) { template in
            EditRecurringSheet(viewModel: viewModel, template: template, modelContext: modelContext)
        }
    }
}

// MARK: - Overview Card

struct RecurringOverviewCard: View {
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

// MARK: - Template Row

struct RecurringTemplateRow: View {
    let template: RecurringTemplate
    var isOverdue: Bool = false
    var isPaused: Bool = false
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "repeat.circle.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(isOverdue ? Color.red : (isPaused ? Color.gray : Color.primaryBlue))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(isPaused ? .secondary : .primary)

                    // Frequency badge
                    Text(template.frequency.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    if template.isAutoPay {
                        Text("Auto")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }

                    if isPaused {
                        Text("Paused")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }

                Text(template.type == .expense ? "Expense" : "Income")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(template.formattedAmount)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(template.type == .expense ? .red : .green)

                if template.isActive {
                    let days = template.daysUntilDue
                    Text(days < 0 ? "\(abs(days))d overdue" : (days == 0 ? "Due today" : "Due in \(days)d"))
                        .font(.caption)
                        .foregroundColor(days < 0 ? .red : (days <= 3 ? .orange : .secondary))
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            isOverdue
                ? Color.red.opacity(0.05)
                : Color(.controlBackgroundColor)
        )
        .cornerRadius(12)
        .overlay(
            isOverdue
                ? RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1)
                : nil
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Add Recurring Sheet

struct AddRecurringSheet: View {
    var viewModel: RecurringViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double = 0
    @State private var isExpense = true
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var notes = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("New Recurring Transaction")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Name", text: $name)

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("Amount", value: $amount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }

                Picker("Type", selection: $isExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)

                Picker("Frequency", selection: $frequency) {
                    ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                Toggle("Set End Date", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }

                TextField("Notes (optional)", text: $notes)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Create") {
                    viewModel.createTemplate(
                        name: name,
                        amount: Decimal(amount),
                        type: isExpense ? .expense : .income,
                        frequency: frequency,
                        startDate: startDate,
                        endDate: hasEndDate ? endDate : nil,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || amount <= 0)
            }
        }
        .padding()
        .frame(width: 420, height: 520)
    }
}

// MARK: - Edit Recurring Sheet

struct EditRecurringSheet: View {
    var viewModel: RecurringViewModel
    let template: RecurringTemplate
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amount: Double
    @State private var showingDeleteConfirmation = false

    init(viewModel: RecurringViewModel, template: RecurringTemplate, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.template = template
        self.modelContext = modelContext
        _name = State(initialValue: template.name)
        _amount = State(initialValue: Double(truncating: template.amount as NSNumber))
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.primaryBlue)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Edit Recurring")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(template.frequency.rawValue)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("Amount", value: $amount, format: .currency(code: CurrencyFormatter.shared.locale.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                }

                Section("Status") {
                    LabeledContent("Frequency", value: template.frequency.rawValue)
                    LabeledContent("Next Due", value: template.nextDueDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("Generated", value: "\(template.generatedTransactions.count) transactions")
                    LabeledContent("Status", value: template.isActive ? "Active" : "Paused")
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }

                Spacer()

                if template.isActive {
                    Button("Pause") {
                        viewModel.pauseTemplate(template, modelContext: modelContext)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Resume") {
                        viewModel.resumeTemplate(template, modelContext: modelContext)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }

                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Save") {
                    template.name = name
                    template.amount = Decimal(amount)
                    template.updatedAt = Date()
                    try? modelContext.save()
                    viewModel.loadTemplates(modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || amount <= 0)
            }
        }
        .padding()
        .frame(width: 420, height: 500)
        .confirmationDialog("Delete Recurring?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteTemplate(template, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete \"\(template.name)\" and all its generated transactions.")
        }
    }
}

#Preview {
    RecurringTransactionsView()
}
