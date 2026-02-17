//
//  DashboardViewModelTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class DashboardViewModelTests: XCTestCase {

    var sut: DashboardViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }
        sut = DashboardViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_monthlyIncomeIsZero() {
        XCTAssertEqual(sut.monthlyIncome, 0)
    }

    func test_initialState_monthlyExpensesIsZero() {
        XCTAssertEqual(sut.monthlyExpenses, 0)
    }

    func test_initialState_netWorthIsZero() {
        XCTAssertEqual(sut.netWorth, 0)
    }

    func test_initialState_pensionValueIsZero() {
        XCTAssertEqual(sut.pensionValue, 0)
    }

    func test_initialState_budgetCategoriesEmpty() {
        XCTAssertTrue(sut.budgetCategories.isEmpty)
    }

    func test_initialState_recentTransactionsEmpty() {
        XCTAssertTrue(sut.recentTransactions.isEmpty)
    }

    func test_initialState_selectedPeriodIsMonth() {
        XCTAssertEqual(sut.selectedPeriod, .month)
    }

    // MARK: - Computed Properties

    func test_monthlySavings_withNoData_returnsZero() {
        XCTAssertEqual(sut.monthlySavings, 0)
    }

    func test_monthlySavings_withIncomeAndExpenses_calculatesCorrectly() {
        sut.monthlyIncome = 5000
        sut.monthlyExpenses = 3000
        XCTAssertEqual(sut.monthlySavings, 2000)
    }

    func test_monthlySavings_whenExpensesExceedIncome_returnsNegative() {
        sut.monthlyIncome = 2000
        sut.monthlyExpenses = 3000
        XCTAssertEqual(sut.monthlySavings, -1000)
    }

    func test_savingsRate_withNoIncome_returnsZero() {
        sut.monthlyIncome = 0
        sut.monthlyExpenses = 500
        XCTAssertEqual(sut.savingsRate, 0.0)
    }

    func test_savingsRate_with50PercentSavings_returns50() {
        sut.monthlyIncome = 4000
        sut.monthlyExpenses = 2000
        XCTAssertEqual(sut.savingsRate, 50.0, accuracy: 0.01)
    }

    func test_savingsRate_withFullSavings_returns100() {
        sut.monthlyIncome = 4000
        sut.monthlyExpenses = 0
        XCTAssertEqual(sut.savingsRate, 100.0, accuracy: 0.01)
    }

    func test_savingsRate_withNegativeSavings_returnsNegative() {
        sut.monthlyIncome = 1000
        sut.monthlyExpenses = 2000
        XCTAssertLessThan(sut.savingsRate, 0.0)
    }

    func test_totalBudgeted_withNoBudgetCategories_returnsZero() {
        XCTAssertEqual(sut.totalBudgeted, 0)
    }

    func test_totalSpentAmount_withNoBudgetCategories_returnsZero() {
        XCTAssertEqual(sut.totalSpentAmount, 0)
    }

    func test_budgetUtilization_withNoBudget_returnsZero() {
        XCTAssertEqual(sut.budgetUtilization, 0.0)
    }

    // MARK: - View-Compatible Computed Properties

    func test_totalIncome_convertsDecimalToDouble() {
        sut.monthlyIncome = 3500
        XCTAssertEqual(sut.totalIncome, 3500.0, accuracy: 0.01)
    }

    func test_totalExpenses_convertsDecimalToDouble() {
        sut.monthlyExpenses = 2100
        XCTAssertEqual(sut.totalExpenses, 2100.0, accuracy: 0.01)
    }

    func test_netSavings_convertsDecimalToDouble() {
        sut.monthlyIncome = 5000
        sut.monthlyExpenses = 3500
        XCTAssertEqual(sut.netSavings, 1500.0, accuracy: 0.01)
    }

    func test_budgetUsedPercentage_equalsBudgetUtilization() {
        XCTAssertEqual(sut.budgetUsedPercentage, sut.budgetUtilization)
    }

    // MARK: - loadData Tests

    @MainActor
    func test_loadData_withEmptyDatabase_leavesZeros() {
        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.monthlyIncome, 0)
        XCTAssertEqual(sut.monthlyExpenses, 0)
        XCTAssertEqual(sut.netWorth, 0)
    }

    @MainActor
    func test_loadData_withIncomeTx_updatesMonthlyIncome() throws {
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.monthlyIncome, 5000)
    }

    @MainActor
    func test_loadData_withExpenseTx_updatesMonthlyExpenses() throws {
        let expense = Transaction(amount: 200, date: Date(), descriptionText: "Groceries", type: .expense)
        modelContext.insert(expense)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.monthlyExpenses, 200)
    }

    @MainActor
    func test_loadData_withMultipleIncomeTxs_sumsThem() throws {
        let tx1 = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)
        let tx2 = Transaction(amount: 500, date: Date(), descriptionText: "Freelance", type: .income)
        modelContext.insert(tx1)
        modelContext.insert(tx2)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.monthlyIncome, 3500)
    }

    @MainActor
    func test_loadRecentTransactions_limitsToFive() throws {
        for i in 1...8 {
            let tx = Transaction(amount: Decimal(i * 10), date: Date(), descriptionText: "Tx \(i)", type: .expense)
            modelContext.insert(tx)
        }
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertLessThanOrEqual(sut.recentTransactions.count, 5)
    }

    @MainActor
    func test_loadData_withActiveAccount_updatesNetWorth() throws {
        let account = Account(name: "Checking", type: .checking, balance: 10000)
        modelContext.insert(account)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.netWorth, 10000)
    }

    @MainActor
    func test_loadData_withInactiveAccount_excludesFromNetWorth() throws {
        let active = Account(name: "Active", type: .checking, balance: 5000)
        let inactive = Account(name: "Inactive", type: .savings, balance: 3000, isActive: false)
        modelContext.insert(active)
        modelContext.insert(inactive)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.netWorth, 5000)
    }

    @MainActor
    func test_loadData_withCreditCardDebt_reducesNetWorth() throws {
        let savings = Account(name: "Savings", type: .savings, balance: 10000)
        let credit = Account(name: "Credit Card", type: .credit, balance: -2000)
        modelContext.insert(savings)
        modelContext.insert(credit)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.netWorth, 8000)
    }

    @MainActor
    func test_loadData_withPensionData_updatesPensionValue() throws {
        let pension = PensionData(currentValue: 75000)
        modelContext.insert(pension)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertEqual(sut.pensionValue, 75000)
    }

    @MainActor
    func test_loadData_withBudgetCategories_populatesList() throws {
        let cat = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        modelContext.insert(cat)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertFalse(sut.budgetCategories.isEmpty)
    }

    @MainActor
    func test_categorySpending_excludesZeroSpend() throws {
        let cat1 = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        let cat2 = BudgetCategory(type: .dining, budgetAmount: 100, spentAmount: 0)
        modelContext.insert(cat1)
        modelContext.insert(cat2)
        try modelContext.save()

        sut.loadData(modelContext: modelContext)
        XCTAssertFalse(sut.categorySpending.contains { $0.amount == 0 })
    }

    // MARK: - CategorySpendingData Tests

    func test_categorySpendingData_hasUniqueIds() {
        let data1 = CategorySpendingData(category: "Groceries", amount: 200)
        let data2 = CategorySpendingData(category: "Dining", amount: 100)
        XCTAssertNotEqual(data1.id, data2.id)
    }

    // MARK: - MonthlyTrendData Tests

    func test_monthlyTrendData_hasUniqueIds() {
        let trend1 = MonthlyTrendData(month: "Jan", amount: 1000, type: "Income")
        let trend2 = MonthlyTrendData(month: "Jan", amount: 800, type: "Expense")
        XCTAssertNotEqual(trend1.id, trend2.id)
    }

    @MainActor
    func test_loadMonthlyTrend_producesDataForSixMonths() throws {
        sut.loadData(modelContext: modelContext)
        // 6 months x 2 types (Income + Expense) = 12 entries
        XCTAssertEqual(sut.monthlyTrend.count, 12)
    }
}
