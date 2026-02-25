import Foundation
import SwiftData
import SwiftUI

@Observable
class BudgetViewModel {
    var categories: [BudgetCategory] = []
    var selectedPeriod: BudgetPeriod = .monthly
    var showingAddCategory = false
    var editingCategory: BudgetCategory?

    var totalBudgeted: Decimal {
        categories.reduce(0) { $0 + $1.budgetAmount }
    }

    var totalSpentAmount: Decimal {
        categories.reduce(0) { $0 + $1.spentAmount }
    }

    var totalRemaining: Decimal {
        totalBudgeted - totalSpentAmount
    }

    var overallProgress: Double {
        guard totalBudgeted > 0 else { return 0 }
        return Double(truncating: (totalSpentAmount / totalBudgeted) as NSNumber) * 100
    }

    // Computed properties for view compatibility
    var budgetCategories: [BudgetCategory] {
        categories
    }

    var totalBudget: Double {
        Double(truncating: totalBudgeted as NSNumber)
    }

    var totalSpent: Double {
        Double(truncating: totalSpentAmount as NSNumber)
    }

    var remaining: Double {
        Double(truncating: totalRemaining as NSNumber)
    }

    var spentPercentage: Double {
        overallProgress
    }

    var categoriesOverBudget: [BudgetCategory] {
        categories.filter { $0.isOverBudget }
    }

    var categoriesNearLimit: [BudgetCategory] {
        categories.filter { $0.percentageUsed >= 80 && !$0.isOverBudget }
    }

    func loadCategories(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { category in
                category.isActive
            }
        )

        do {
            let fetchedCategories = try modelContext.fetch(descriptor)
            categories = fetchedCategories.sorted { $0.type.order < $1.type.order }

            // Create default categories if none exist
            if categories.isEmpty {
                createDefaultCategories(modelContext: modelContext)
            }
        } catch {
            print("Error loading categories: \(error)")
        }
    }

    private func createDefaultCategories(modelContext: ModelContext) {
        let defaultBudgets: [CategoryType: Decimal] = [
            .housing: 1200,
            .utilities: 150,
            .groceries: 400,
            .transport: 200,
            .healthcare: 100,
            .entertainment: 150,
            .dining: 200,
            .shopping: 150,
            .personal: 100,
            .savings: 500,
            .other: 100
        ]

        for type in CategoryType.allCases {
            let category = BudgetCategory(
                type: type,
                budgetAmount: defaultBudgets[type] ?? 100,
                period: .monthly
            )
            modelContext.insert(category)
            categories.append(category)
        }

        try? modelContext.save()
    }

    @MainActor
    func updateBudget(for category: BudgetCategory, amount: Decimal, modelContext: ModelContext) {
        category.budgetAmount = amount
        try? modelContext.save()

        if let userId = AuthManager.shared.currentUserId {
            let dto = SyncMapper.toDTO(category, userId: userId)
            Task { await SyncService.shared.pushUpsert(table: "budget_categories", recordId: category.id, dto: dto, modelContext: modelContext) }
        }
    }

    func recalculateSpending(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        let expenseType = TransactionType.expense

        for category in categories {
            let descriptor = FetchDescriptor<Transaction>(
                predicate: #Predicate { transaction in
                    transaction.date >= startOfMonth &&
                    transaction.date < endOfMonth &&
                    transaction.type == expenseType
                }
            )

            do {
                let transactions = try modelContext.fetch(descriptor)
                let categoryTransactions = transactions.filter { $0.category?.id == category.id }
                category.spentAmount = categoryTransactions.reduce(0) { $0 + $1.amount }
            } catch {
                print("Error recalculating spending: \(error)")
            }
        }

        try? modelContext.save()
    }

    // View compatibility methods
    func addBudget(name: String, amount: Double, icon: String) {
        // This will be called with modelContext from view
    }

    @MainActor
    func addBudget(name: String, amount: Double, icon: String, modelContext: ModelContext) {
        let categoryType = CategoryType.allCases.first { $0.rawValue == name } ?? .other
        let category = BudgetCategory(
            type: categoryType,
            budgetAmount: Decimal(string: String(amount)) ?? 0,
            period: .monthly
        )
        modelContext.insert(category)
        try? modelContext.save()

        if let userId = AuthManager.shared.currentUserId {
            let dto = SyncMapper.toDTO(category, userId: userId)
            Task { await SyncService.shared.pushUpsert(table: "budget_categories", recordId: category.id, dto: dto, modelContext: modelContext) }
        }

        loadCategories(modelContext: modelContext)
    }

    func updateBudget(_ budget: BudgetCategory, name: String, amount: Double) {
        // This will be called with modelContext from view
    }

    @MainActor
    func updateBudget(_ budget: BudgetCategory, name: String, amount: Double, modelContext: ModelContext) {
        budget.budgetAmount = Decimal(string: String(amount)) ?? 0
        if let categoryType = CategoryType.allCases.first(where: { $0.rawValue == name }) {
            budget.type = categoryType
        }
        try? modelContext.save()

        if let userId = AuthManager.shared.currentUserId {
            let dto = SyncMapper.toDTO(budget, userId: userId)
            Task { await SyncService.shared.pushUpsert(table: "budget_categories", recordId: budget.id, dto: dto, modelContext: modelContext) }
        }

        loadCategories(modelContext: modelContext)
    }

    func deleteBudget(_ budget: BudgetCategory) {
        // This will be called with modelContext from view
    }

    @MainActor
    func deleteBudget(_ budget: BudgetCategory, modelContext: ModelContext) {
        let recordId = budget.id
        modelContext.delete(budget)
        try? modelContext.save()

        if let userId = AuthManager.shared.currentUserId {
            Task { await SyncService.shared.pushDelete(table: "budget_categories", recordId: recordId, modelContext: modelContext) }
        }

        loadCategories(modelContext: modelContext)
    }
}

// Extension for BudgetCategory view compatibility
extension BudgetCategory {
    var name: String {
        type.rawValue
    }

    var budgeted: Double {
        Double(truncating: budgetAmount as NSNumber)
    }

    var spent: Double {
        Double(truncating: spentAmount as NSNumber)
    }

    var remaining: Double {
        budgeted - spent
    }

    var icon: String {
        type.icon
    }
}
