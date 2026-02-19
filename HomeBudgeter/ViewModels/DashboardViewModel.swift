import Foundation
import SwiftData
import SwiftUI

@Observable
class DashboardViewModel {
    var monthlyIncome: Decimal = 0
    var monthlyExpenses: Decimal = 0
    var netWorth: Decimal = 0
    var pensionValue: Decimal = 0
    var investmentValue: Decimal = 0
    var budgetCategories: [BudgetCategory] = []
    var recentTransactions: [Transaction] = []
    var selectedPeriod: TimePeriod = .month
    var selectedMember: HouseholdMember?
    var householdMembers: [HouseholdMember] = []
    var categorySpending: [CategorySpendingData] = []
    var monthlyTrend: [MonthlyTrendData] = []

    var monthlySavings: Decimal {
        monthlyIncome - monthlyExpenses
    }

    var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return Double(truncating: (monthlySavings / monthlyIncome) as NSNumber) * 100
    }

    var totalBudgeted: Decimal {
        budgetCategories.reduce(0) { $0 + $1.budgetAmount }
    }

    var totalSpentAmount: Decimal {
        budgetCategories.reduce(0) { $0 + $1.spentAmount }
    }

    var budgetUtilization: Double {
        guard totalBudgeted > 0 else { return 0 }
        return Double(truncating: (totalSpentAmount / totalBudgeted) as NSNumber) * 100
    }

    // Computed properties for the view
    var totalIncome: Double {
        Double(truncating: monthlyIncome as NSNumber)
    }

    var totalExpenses: Double {
        Double(truncating: monthlyExpenses as NSNumber)
    }

    var netSavings: Double {
        Double(truncating: monthlySavings as NSNumber)
    }

    var budgetUsedPercentage: Double {
        budgetUtilization
    }

    func loadData(modelContext: ModelContext) {
        loadHouseholdMembers(modelContext: modelContext)
        loadMonthlyData(modelContext: modelContext)
        loadNetWorth(modelContext: modelContext)
        loadPensionData(modelContext: modelContext)
        loadInvestmentData(modelContext: modelContext)
        loadBudgetCategories(modelContext: modelContext)
        loadRecentTransactions(modelContext: modelContext)
        loadCategorySpending(modelContext: modelContext)
        loadMonthlyTrend(modelContext: modelContext)
    }

    private func loadHouseholdMembers(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<HouseholdMember>(sortBy: [SortDescriptor(\.name)])
        do {
            householdMembers = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading household members: \(error)")
        }
    }

    private func loadMonthlyData(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let transactionDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { transaction in
                transaction.date >= startOfMonth && transaction.date < endOfMonth
            }
        )

        let payslipDescriptor = FetchDescriptor<Payslip>(
            predicate: #Predicate { payslip in
                payslip.payDate >= startOfMonth && payslip.payDate < endOfMonth
            }
        )

        do {
            var transactions = try modelContext.fetch(transactionDescriptor)
            var payslips = try modelContext.fetch(payslipDescriptor)
            if let member = selectedMember {
                transactions = transactions.filter { $0.account?.owner?.id == member.id }
                payslips = payslips.filter { $0.member?.id == member.id }
            }
            let transactionIncome = transactions
                .filter { $0.type == .income }
                .reduce(Decimal.zero) { $0 + $1.amount }
            let payslipIncome = payslips
                .reduce(Decimal.zero) { $0 + $1.netPay }
            monthlyIncome = transactionIncome + payslipIncome
            monthlyExpenses = transactions
                .filter { $0.type == .expense }
                .reduce(Decimal.zero) { $0 + $1.amount }
        } catch {
            print("Error loading monthly data: \(error)")
        }
    }

    private func loadNetWorth(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { account in
                account.isActive
            }
        )

        do {
            var accounts = try modelContext.fetch(descriptor)
            if let member = selectedMember {
                accounts = accounts.filter { $0.owner?.id == member.id }
            }
            netWorth = accounts.reduce(0) { result, account in
                if account.isAsset {
                    return result + account.balance
                } else {
                    return result - abs(account.balance)
                }
            }
            // Include investment portfolio value in net worth
            netWorth += investmentValue
        } catch {
            print("Error loading net worth: \(error)")
        }
    }

    private func loadInvestmentData(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Investment>()
        do {
            var investments = try modelContext.fetch(descriptor)
            if let member = selectedMember {
                investments = investments.filter { $0.owner?.id == member.id }
            }
            investmentValue = investments.reduce(Decimal.zero) { $0 + $1.currentValue }
        } catch {
            print("Error loading investment data: \(error)")
        }
    }

    private func loadPensionData(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PensionData>(
            sortBy: [SortDescriptor(\.lastUpdated, order: .reverse)]
        )

        do {
            if let pension = try modelContext.fetch(descriptor).first {
                pensionValue = pension.currentValue
            }
        } catch {
            print("Error loading pension data: \(error)")
        }
    }

    private func loadBudgetCategories(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { category in
                category.isActive
            }
        )

        do {
            let fetchedCategories = try modelContext.fetch(descriptor)
            budgetCategories = fetchedCategories.sorted { $0.type.order < $1.type.order }
        } catch {
            print("Error loading budget categories: \(error)")
        }
    }

    private func loadRecentTransactions(modelContext: ModelContext) {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 5

        do {
            recentTransactions = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading recent transactions: \(error)")
        }
    }

    private func loadCategorySpending(modelContext: ModelContext) {
        var spendingByCategory: [String: Double] = [:]

        for category in budgetCategories {
            let amount = Double(truncating: category.spentAmount as NSNumber)
            spendingByCategory[category.type.rawValue] = amount
        }

        categorySpending = spendingByCategory
            .filter { $0.value > 0 }
            .map { CategorySpendingData(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    private func loadMonthlyTrend(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        var trends: [MonthlyTrendData] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        for monthOffset in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                continue
            }

            let monthName = dateFormatter.string(from: monthDate)

            let transactionPredicate = #Predicate<Transaction> { transaction in
                transaction.date >= startOfMonth && transaction.date <= endOfMonth
            }
            let payslipPredicate = #Predicate<Payslip> { payslip in
                payslip.payDate >= startOfMonth && payslip.payDate <= endOfMonth
            }

            let transactionDescriptor = FetchDescriptor<Transaction>(predicate: transactionPredicate)
            let payslipDescriptor = FetchDescriptor<Payslip>(predicate: payslipPredicate)

            do {
                let transactions = try modelContext.fetch(transactionDescriptor)
                let payslips = try modelContext.fetch(payslipDescriptor)

                let transactionIncome = transactions
                    .filter { $0.type == .income }
                    .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }
                let payslipIncome = payslips
                    .reduce(0.0) { $0 + Double(truncating: $1.netPay as NSNumber) }

                let expenses = transactions
                    .filter { $0.type == .expense }
                    .reduce(0.0) { $0 + Double(truncating: $1.amount as NSNumber) }

                trends.append(MonthlyTrendData(month: monthName, amount: transactionIncome + payslipIncome, type: "Income"))
                trends.append(MonthlyTrendData(month: monthName, amount: expenses, type: "Expense"))
            } catch {
                print("Error loading monthly trend: \(error)")
            }
        }

        monthlyTrend = trends
    }
}

// MARK: - Chart Data Models

struct CategorySpendingData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}

struct MonthlyTrendData: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
    let type: String
}
