//
//  TransactionsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

struct TransactionsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TransactionsViewModel()
    @State private var showingAddTransaction = false
    @State private var searchText = ""
    @State private var selectedFilter: TransactionTypeFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transactions")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Track your income and expenses")
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Add Transaction", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Search and Filter Bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search transactions...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TransactionTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Menu {
                    Button("Date (Newest)") { viewModel.sortOrder = .dateDescending }
                    Button("Date (Oldest)") { viewModel.sortOrder = .dateAscending }
                    Button("Amount (High to Low)") { viewModel.sortOrder = .amountDescending }
                    Button("Amount (Low to High)") { viewModel.sortOrder = .amountAscending }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            // Transactions List
            if viewModel.filteredTransactions.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Transactions" : "No Results",
                    systemImage: searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                            ? "Add your first transaction to start tracking"
                            : "Try adjusting your search or filters"
                    )
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { date in
                            Section {
                                ForEach(groupedTransactions[date] ?? []) { transaction in
                                    TransactionListRow(transaction: transaction) {
                                        viewModel.selectedTransaction = transaction
                                    } onDelete: {
                                        viewModel.deleteTransaction(transaction, modelContext: modelContext)
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(date, style: .date)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 16)
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600)
        .searchable(text: $searchText, prompt: "Search transactions")
        .onAppear {
            viewModel.loadTransactions(modelContext: modelContext)
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.searchText = newValue
        }
        .onChange(of: selectedFilter) { _, newValue in
            switch newValue {
            case .all:
                viewModel.selectedType = nil
            case .income:
                viewModel.selectedType = .income
            case .expenses:
                viewModel.selectedType = .expense
            }
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $viewModel.selectedTransaction) { transaction in
            EditTransactionSheet(viewModel: viewModel, transaction: transaction, modelContext: modelContext)
        }
    }

    private var groupedTransactions: [Date: [Transaction]] {
        Dictionary(grouping: viewModel.filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.date)
        }
    }
}

enum TransactionTypeFilter: String, CaseIterable {
    case all = "All"
    case income = "Income"
    case expenses = "Expenses"
}

struct TransactionListRow: View {
    let transaction: Transaction
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var isExpense: Bool {
        transaction.type == .expense
    }

    private var categoryIcon: String {
        transaction.category?.type.icon ?? "dollarsign.circle.fill"
    }

    private var categoryName: String {
        transaction.category?.type.rawValue ?? "General"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.title3)
                .foregroundColor(isExpense ? .red : .green)
                .frame(width: 40, height: 40)
                .background(
                    (isExpense ? Color.red : Color.green)
                        .opacity(0.1)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(categoryName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    if let note = transaction.notes, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Text(transaction.formattedAmount)
                .fontWeight(.semibold)
                .foregroundColor(isExpense ? .red : .green)

            if isHovered {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct AddTransactionSheet: View {
    var viewModel: TransactionsViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount: Double = 0
    @State private var isExpense = true
    @State private var selectedCategory: CategoryType = .other
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Transaction")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Picker("Type", selection: $isExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)

                TextField("Description", text: $title)

                TextField("Amount", value: $amount, format: .currency(code: "EUR"))

                Picker("Category", selection: $selectedCategory) {
                    ForEach(CategoryType.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }

                DatePicker("Date", selection: $date, displayedComponents: .date)

                TextField("Note (optional)", text: $note)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add Transaction") {
                    let transaction = Transaction(
                        amount: Decimal(amount),
                        date: date,
                        descriptionText: title,
                        type: isExpense ? .expense : .income,
                        notes: note.isEmpty ? nil : note
                    )
                    viewModel.addTransaction(transaction, modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || amount <= 0)
            }
        }
        .padding()
        .frame(width: 400, height: 450)
    }
}

struct EditTransactionSheet: View {
    var viewModel: TransactionsViewModel
    let transaction: Transaction
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var amount: Double
    @State private var isExpense: Bool
    @State private var selectedCategory: CategoryType
    @State private var date: Date
    @State private var note: String

    init(viewModel: TransactionsViewModel, transaction: Transaction, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.transaction = transaction
        self.modelContext = modelContext
        _title = State(initialValue: transaction.descriptionText)
        _amount = State(initialValue: Double(truncating: transaction.amount as NSNumber))
        _isExpense = State(initialValue: transaction.type == .expense)
        _selectedCategory = State(initialValue: transaction.category?.type ?? .other)
        _date = State(initialValue: transaction.date)
        _note = State(initialValue: transaction.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Transaction")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Picker("Type", selection: $isExpense) {
                    Text("Expense").tag(true)
                    Text("Income").tag(false)
                }
                .pickerStyle(.segmented)

                TextField("Description", text: $title)
                TextField("Amount", value: $amount, format: .currency(code: "EUR"))

                Picker("Category", selection: $selectedCategory) {
                    ForEach(CategoryType.allCases, id: \.self) { cat in
                        Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                    }
                }

                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Note (optional)", text: $note)
            }
            .formStyle(.grouped)

            HStack {
                Button("Delete", role: .destructive) {
                    viewModel.deleteTransaction(transaction, modelContext: modelContext)
                    dismiss()
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    transaction.descriptionText = title
                    transaction.amount = Decimal(amount)
                    transaction.type = isExpense ? .expense : .income
                    transaction.date = date
                    transaction.notes = note.isEmpty ? nil : note
                    transaction.updatedAt = Date()
                    try? modelContext.save()
                    viewModel.loadTransactions(modelContext: modelContext)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 480)
    }
}

#Preview {
    TransactionsView()
}
