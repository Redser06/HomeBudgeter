//
//  ReportsViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Report Period

enum ReportPeriod: String, CaseIterable {
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
    case custom = "Custom"
}

// MARK: - Report Data Structs

struct IncomeExpenseData: Identifiable {
    let id = UUID()
    let month: String
    let monthDate: Date
    let income: Double
    let expenses: Double

    var net: Double { income - expenses }
}

struct CategoryBreakdownData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
    let percentage: Double
    let color: Color
}

struct NetWorthPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
}

struct TopExpenseData: Identifiable {
    let id = UUID()
    let description: String
    let amount: Double
    let date: Date
    let category: String?
}

struct BudgetUtilisationData: Identifiable {
    let id = UUID()
    let category: String
    let budgeted: Double
    let spent: Double

    var percentage: Double { budgeted > 0 ? (spent / budgeted) * 100 : 0 }
}

// MARK: - ReportsViewModel

@Observable
class ReportsViewModel {
    var selectedPeriod: ReportPeriod = .month
    var startDate: Date
    var endDate: Date
    var incomeVsExpenseData: [IncomeExpenseData] = []
    var categoryBreakdown: [CategoryBreakdownData] = []
    var netWorthHistory: [NetWorthPoint] = []
    var topExpenses: [TopExpenseData] = []
    var budgetUtilisation: [BudgetUtilisationData] = []

    // MARK: - Computed Properties

    var totalIncome: Decimal {
        let sum = incomeVsExpenseData.reduce(0.0) { $0 + $1.income }
        return Decimal(sum)
    }

    var totalExpenses: Decimal {
        let sum = incomeVsExpenseData.reduce(0.0) { $0 + $1.expenses }
        return Decimal(sum)
    }

    var netAmount: Decimal {
        totalIncome - totalExpenses
    }

    var savingsRate: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(truncating: (netAmount / totalIncome) as NSNumber) * 100
    }

    // MARK: - Init

    init() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? now
        self.startDate = start
        self.endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? now
    }

    // MARK: - Public Methods

    func loadAllReports(modelContext: ModelContext) {
        loadIncomeVsExpense(modelContext: modelContext)
        loadCategoryBreakdown(modelContext: modelContext)
        loadNetWorthHistory(modelContext: modelContext)
        loadTopExpenses(modelContext: modelContext)
        loadBudgetUtilisation(modelContext: modelContext)
    }

    func loadIncomeVsExpense(modelContext: ModelContext) {
        let calendar = Calendar.current
        var results: [IncomeExpenseData] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"

        // Determine how many months to show based on the date range
        let monthsBetween = calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        let totalMonths = max(monthsBetween + 1, 1)

        for monthOffset in 0..<totalMonths {
            guard let monthStart = calendar.date(byAdding: .month, value: monthOffset, to: startDate) else {
                continue
            }

            let monthComponents = calendar.dateComponents([.year, .month], from: monthStart)
            guard let normalizedMonthStart = calendar.date(from: monthComponents),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: normalizedMonthStart) else {
                continue
            }

            let monthName = dateFormatter.string(from: normalizedMonthStart)

            let predicate = #Predicate<Transaction> { transaction in
                transaction.date >= normalizedMonthStart && transaction.date < monthEnd
            }
            let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

            do {
                let transactions = try modelContext.fetch(descriptor)

                let income = transactions
                    .filter { $0.type == .income }
                    .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

                let expenses = transactions
                    .filter { $0.type == .expense }
                    .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

                results.append(IncomeExpenseData(
                    month: monthName,
                    monthDate: normalizedMonthStart,
                    income: income,
                    expenses: expenses
                ))
            } catch {
                print("Error loading income vs expense: \(error)")
            }
        }

        incomeVsExpenseData = results
    }

    func loadCategoryBreakdown(modelContext: ModelContext) {
        let rangeStart = startDate
        let rangeEnd = endDate
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= rangeStart && transaction.date <= rangeEnd
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

        do {
            let transactions = try modelContext.fetch(descriptor)
            let expenseTransactions = transactions.filter { $0.type == .expense }

            var spendingByCategory: [String: Double] = [:]
            var categoryColorMap: [String: Color] = [:]

            for transaction in expenseTransactions {
                let categoryName = transaction.category?.type.rawValue ?? "Other"
                let amount = Double(truncating: transaction.amount as NSNumber)
                spendingByCategory[categoryName, default: 0] += amount

                if let categoryType = transaction.category?.type {
                    categoryColorMap[categoryName] = categoryType.color
                }
            }

            let totalSpending = spendingByCategory.values.reduce(0.0, +)
            let chartColors = Color.chartColors

            let sortedCategories = spendingByCategory.sorted { $0.value > $1.value }

            categoryBreakdown = sortedCategories.enumerated().map { index, pair in
                let percentage = totalSpending > 0 ? (pair.value / totalSpending) * 100 : 0
                let color = categoryColorMap[pair.key] ?? chartColors[index % chartColors.count]
                return CategoryBreakdownData(
                    category: pair.key,
                    amount: pair.value,
                    percentage: percentage,
                    color: color
                )
            }
        } catch {
            print("Error loading category breakdown: \(error)")
        }
    }

    func loadNetWorthHistory(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        var results: [NetWorthPoint] = []

        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate { account in
                account.isActive
            }
        )

        do {
            let accounts = try modelContext.fetch(accountDescriptor)

            guard !accounts.isEmpty else {
                netWorthHistory = []
                return
            }

            // Current net worth as the baseline
            let currentNetWorth = accounts.reduce(0.0) { result, account in
                let balance = Double(truncating: account.balance as NSNumber)
                if account.isAsset {
                    return result + balance
                } else {
                    return result - abs(balance)
                }
            }

            // Build 12 monthly net worth points by working backwards from current net worth
            // adjusting for transactions in each month
            for monthOffset in (0..<12).reversed() {
                guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now) else {
                    continue
                }

                let monthComponents = calendar.dateComponents([.year, .month], from: monthDate)
                guard let monthStart = calendar.date(from: monthComponents) else {
                    continue
                }

                // Sum all transactions between this month and now to estimate net worth at that point
                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                    continue
                }

                let predicate = #Predicate<Transaction> { transaction in
                    transaction.date >= nextMonth
                }
                let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

                let futureTransactions = try modelContext.fetch(descriptor)

                // Net effect of future transactions on accounts
                let futureNetEffect = futureTransactions.reduce(0.0) { result, transaction in
                    let amount = Double(truncating: transaction.amount as NSNumber)
                    switch transaction.type {
                    case .income:
                        return result - amount  // Remove future income to go back in time
                    case .expense:
                        return result + amount  // Add back future expenses to go back in time
                    case .transfer:
                        return result  // Transfers are net zero
                    }
                }

                let estimatedNetWorth = currentNetWorth + futureNetEffect

                results.append(NetWorthPoint(
                    date: monthStart,
                    amount: estimatedNetWorth
                ))
            }

            netWorthHistory = results.sorted { $0.date < $1.date }
        } catch {
            print("Error loading net worth history: \(error)")
        }
    }

    func loadTopExpenses(modelContext: ModelContext) {
        let rangeStart = startDate
        let rangeEnd = endDate
        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= rangeStart && transaction.date <= rangeEnd
        }
        let descriptor = FetchDescriptor<Transaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.amount, order: .reverse)]
        )

        do {
            let transactions = try modelContext.fetch(descriptor)
            let expenseTransactions = transactions
                .filter { $0.type == .expense }
                .sorted { Double(truncating: $0.amount as NSNumber) > Double(truncating: $1.amount as NSNumber) }

            topExpenses = Array(expenseTransactions.prefix(10)).map { transaction in
                TopExpenseData(
                    description: transaction.descriptionText,
                    amount: Double(truncating: transaction.amount as NSNumber),
                    date: transaction.date,
                    category: transaction.category?.type.rawValue
                )
            }
        } catch {
            print("Error loading top expenses: \(error)")
        }
    }

    func loadBudgetUtilisation(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { category in
                category.isActive
            }
        )

        do {
            let categories = try modelContext.fetch(descriptor)
            budgetUtilisation = categories
                .filter { $0.budgetAmount > 0 }
                .sorted { $0.type.order < $1.type.order }
                .map { category in
                    BudgetUtilisationData(
                        category: category.type.rawValue,
                        budgeted: Double(truncating: category.budgetAmount as NSNumber),
                        spent: Double(truncating: category.spentAmount as NSNumber)
                    )
                }
        } catch {
            print("Error loading budget utilisation: \(error)")
        }
    }

    func updateDateRange() {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPeriod {
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            startDate = calendar.date(from: components) ?? now
            endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? now

        case .quarter:
            let month = calendar.component(.month, from: now)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            startDate = calendar.date(from: components) ?? now
            endDate = calendar.date(byAdding: DateComponents(month: 3, day: -1), to: startDate) ?? now

        case .year:
            var components = calendar.dateComponents([.year], from: now)
            components.month = 1
            components.day = 1
            startDate = calendar.date(from: components) ?? now
            endDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startDate) ?? now

        case .custom:
            // Custom period: don't change dates, user sets them manually
            break
        }
    }
}
