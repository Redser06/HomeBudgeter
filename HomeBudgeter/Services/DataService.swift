//
//  DataService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import Combine

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    private init() {
        self.modelContainer = PersistenceController.shared.modelContainer
        self.modelContext = modelContainer.mainContext
    }

    // MARK: - Transactions

    func getAllTransactions() -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch transactions: \(error)")
            return []
        }
    }

    func getTransactions(for period: TimePeriod) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date

        switch period {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .quarter:
            startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }

        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= startDate
        }

        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch transactions for period: \(error)")
            return []
        }
    }

    func saveTransaction(_ transaction: Transaction) {
        modelContext.insert(transaction)
        save()
    }

    func updateTransaction(_ transaction: Transaction) {
        transaction.updatedAt = Date()
        save()
    }

    func deleteTransaction(_ transaction: Transaction) {
        modelContext.delete(transaction)
        save()
    }

    // MARK: - Budget Categories

    func getBudgetCategories() -> [BudgetCategory] {
        let descriptor = FetchDescriptor<BudgetCategory>(
            sortBy: [SortDescriptor(\.type.rawValue)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch budget categories: \(error)")
            return []
        }
    }

    func getTotalBudget() -> Double {
        let categories = getBudgetCategories()
        return categories.reduce(0) { $0 + Double(truncating: $1.budgetAmount as NSNumber) }
    }

    func saveBudgetCategory(_ category: BudgetCategory) {
        modelContext.insert(category)
        save()
    }

    func updateBudgetCategory(_ category: BudgetCategory) {
        save()
    }

    func deleteBudgetCategory(_ category: BudgetCategory) {
        modelContext.delete(category)
        save()
    }

    // MARK: - Accounts

    func getAllAccounts() -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch accounts: \(error)")
            return []
        }
    }

    func saveAccount(_ account: Account) {
        modelContext.insert(account)
        save()
    }

    func deleteAccount(_ account: Account) {
        modelContext.delete(account)
        save()
    }

    // MARK: - Charts & Analytics

    func getCategorySpending(for period: TimePeriod) -> [CategorySpending] {
        let transactions = getTransactions(for: period)
        var spendingByCategory: [String: Double] = [:]

        for transaction in transactions where transaction.type == .expense {
            let categoryName = transaction.category?.type.rawValue ?? "Other"
            let amount = Double(truncating: transaction.amount as NSNumber)
            spendingByCategory[categoryName, default: 0] += amount
        }

        return spendingByCategory.map { CategorySpending(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    func getMonthlyTrend() -> [MonthlyTrend] {
        let calendar = Calendar.current
        let now = Date()
        var trends: [MonthlyTrend] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                continue
            }

            let monthName = dateFormatter.string(from: monthDate)
            let transactions = getAllTransactions().filter { $0.date >= startOfMonth && $0.date <= endOfMonth }

            let income = transactions
                .filter { $0.type == .income }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

            let expenses = transactions
                .filter { $0.type == .expense }
                .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

            trends.append(MonthlyTrend(month: monthName, amount: income, type: "Income"))
            trends.append(MonthlyTrend(month: monthName, amount: expenses, type: "Expense"))
        }

        return trends
    }

    // MARK: - Private

    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

// MARK: - Chart Data Models

struct CategorySpending: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}

struct MonthlyTrend: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
    let type: String
}
