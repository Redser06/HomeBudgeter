import Foundation
import SwiftData
import SwiftUI

@Observable
class TransactionsViewModel {
    var transactions: [Transaction] = []
    var filteredTransactions: [Transaction] = []
    var selectedTransaction: Transaction?
    var showingAddTransaction = false
    var showingEditTransaction = false

    var searchText: String = "" {
        didSet { applyFilters() }
    }

    var selectedCategory: CategoryType? {
        didSet { applyFilters() }
    }

    var selectedType: TransactionType? {
        didSet { applyFilters() }
    }

    var dateRange: DateRange = .thisMonth {
        didSet { applyFilters() }
    }

    var sortOrder: SortOrder = .dateDescending {
        didSet { applyFilters() }
    }

    enum DateRange: String, CaseIterable {
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case allTime = "All Time"
        case custom = "Custom"

        var dateInterval: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()

            switch self {
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return (start, now)
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                return (start, now)
            case .lastMonth:
                let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonth)!
                return (start, thisMonth)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
            case .allTime, .custom:
                return (Date.distantPast, now)
            }
        }
    }

    enum SortOrder: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case amountDescending = "Highest Amount"
        case amountAscending = "Lowest Amount"
    }

    var totalIncome: Decimal {
        filteredTransactions
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Decimal {
        filteredTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var netAmount: Decimal {
        totalIncome - totalExpenses
    }

    func loadTransactions(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            transactions = try modelContext.fetch(descriptor)
            applyFilters()
        } catch {
            print("Error loading transactions: \(error)")
        }
    }

    private func applyFilters() {
        var result = transactions

        // Date range filter
        let interval = dateRange.dateInterval
        result = result.filter { $0.date >= interval.start && $0.date <= interval.end }

        // Category filter
        if let category = selectedCategory {
            result = result.filter { $0.category?.type == category }
        }

        // Type filter
        if let type = selectedType {
            result = result.filter { $0.type == type }
        }

        // Search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.descriptionText.localizedCaseInsensitiveContains(searchText) ||
                $0.category?.type.rawValue.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Sort
        switch sortOrder {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.amount > $1.amount }
        case .amountAscending:
            result.sort { $0.amount < $1.amount }
        }

        filteredTransactions = result
    }

    func addTransaction(_ transaction: Transaction, modelContext: ModelContext) {
        modelContext.insert(transaction)
        try? modelContext.save()
        loadTransactions(modelContext: modelContext)
    }

    func deleteTransaction(_ transaction: Transaction, modelContext: ModelContext) {
        modelContext.delete(transaction)
        try? modelContext.save()
        loadTransactions(modelContext: modelContext)
    }

    func clearFilters() {
        searchText = ""
        selectedCategory = nil
        selectedType = nil
        dateRange = .thisMonth
    }
}
