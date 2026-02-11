//
//  ReportsViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class ReportsViewModelTests: XCTestCase {

    var sut: ReportsViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()

        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Account.self,
            Document.self,
            SavingsGoal.self,
            Payslip.self,
            PensionData.self,
            RecurringTemplate.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }

        sut = ReportsViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_selectedPeriodIsMonth() {
        XCTAssertEqual(sut.selectedPeriod, .month)
    }

    func test_initialState_incomeVsExpenseDataIsEmpty() {
        XCTAssertTrue(sut.incomeVsExpenseData.isEmpty)
    }

    func test_initialState_categoryBreakdownIsEmpty() {
        XCTAssertTrue(sut.categoryBreakdown.isEmpty)
    }

    func test_initialState_netWorthHistoryIsEmpty() {
        XCTAssertTrue(sut.netWorthHistory.isEmpty)
    }

    func test_initialState_topExpensesIsEmpty() {
        XCTAssertTrue(sut.topExpenses.isEmpty)
    }

    func test_initialState_budgetUtilisationIsEmpty() {
        XCTAssertTrue(sut.budgetUtilisation.isEmpty)
    }

    func test_initialState_startDateIsStartOfCurrentMonth() {
        let calendar = Calendar.current
        let expectedComponents = calendar.dateComponents([.year, .month], from: Date())
        let expected = calendar.date(from: expectedComponents)!
        XCTAssertEqual(calendar.compare(sut.startDate, to: expected, toGranularity: .day), .orderedSame)
    }

    func test_initialState_endDateIsEndOfCurrentMonth() {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month], from: Date())
        let startOfMonth = calendar.date(from: startComponents)!
        let expected = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        XCTAssertEqual(calendar.compare(sut.endDate, to: expected, toGranularity: .day), .orderedSame)
    }

    // MARK: - Computed Properties with No Data

    func test_totalIncome_withNoData_returnsZero() {
        XCTAssertEqual(sut.totalIncome, 0)
    }

    func test_totalExpenses_withNoData_returnsZero() {
        XCTAssertEqual(sut.totalExpenses, 0)
    }

    func test_netAmount_withNoData_returnsZero() {
        XCTAssertEqual(sut.netAmount, 0)
    }

    func test_savingsRate_withNoData_returnsZero() {
        XCTAssertEqual(sut.savingsRate, 0)
    }

    // MARK: - Computed Properties with Data

    func test_totalIncome_sumsIncomeFromAllMonths() {
        // Manually set the data to test computed properties
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 3000, expenses: 2000),
            IncomeExpenseData(month: "Feb 2025", monthDate: Date(), income: 3500, expenses: 2500)
        ]
        // 3000 + 3500 = 6500
        XCTAssertEqual(sut.totalIncome, Decimal(6500))
    }

    func test_totalExpenses_sumsExpensesFromAllMonths() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 3000, expenses: 2000),
            IncomeExpenseData(month: "Feb 2025", monthDate: Date(), income: 3500, expenses: 2500)
        ]
        // 2000 + 2500 = 4500
        XCTAssertEqual(sut.totalExpenses, Decimal(4500))
    }

    func test_netAmount_calculatesIncomeMinusExpenses() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 5000, expenses: 3000)
        ]
        XCTAssertEqual(sut.netAmount, Decimal(2000))
    }

    func test_netAmount_canBeNegative() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 2000, expenses: 3000)
        ]
        XCTAssertEqual(sut.netAmount, Decimal(-1000))
    }

    func test_savingsRate_calculatesCorrectly() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 5000, expenses: 3000)
        ]
        // Savings: 2000, Income: 5000, Rate: 40%
        XCTAssertEqual(sut.savingsRate, 40.0, accuracy: 0.01)
    }

    func test_savingsRate_withZeroIncome_returnsZero() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 0, expenses: 500)
        ]
        XCTAssertEqual(sut.savingsRate, 0)
    }

    func test_savingsRate_canBeNegative() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 2000, expenses: 4000)
        ]
        // Net: -2000, Income: 2000, Rate: -100%
        XCTAssertEqual(sut.savingsRate, -100.0, accuracy: 0.01)
    }

    func test_savingsRate_fullSavingsReturns100() {
        sut.incomeVsExpenseData = [
            IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 5000, expenses: 0)
        ]
        XCTAssertEqual(sut.savingsRate, 100.0, accuracy: 0.01)
    }

    // MARK: - updateDateRange

    func test_updateDateRange_month_setsCorrectDates() {
        sut.selectedPeriod = .month
        sut.updateDateRange()

        let calendar = Calendar.current
        let now = Date()
        let expectedComponents = calendar.dateComponents([.year, .month], from: now)
        let expectedStart = calendar.date(from: expectedComponents)!
        let expectedEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: expectedStart)!

        XCTAssertEqual(calendar.compare(sut.startDate, to: expectedStart, toGranularity: .day), .orderedSame)
        XCTAssertEqual(calendar.compare(sut.endDate, to: expectedEnd, toGranularity: .day), .orderedSame)
    }

    func test_updateDateRange_quarter_setsCorrectStartMonth() {
        sut.selectedPeriod = .quarter
        sut.updateDateRange()

        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let expectedQuarterStartMonth = ((currentMonth - 1) / 3) * 3 + 1

        let startMonth = calendar.component(.month, from: sut.startDate)
        XCTAssertEqual(startMonth, expectedQuarterStartMonth)
    }

    func test_updateDateRange_quarter_spansThreeMonths() {
        sut.selectedPeriod = .quarter
        sut.updateDateRange()

        let calendar = Calendar.current
        let months = calendar.dateComponents([.month], from: sut.startDate, to: sut.endDate).month ?? 0
        // End date is last day of third month, so difference should be ~2-3 months
        XCTAssertTrue(months >= 2 && months <= 3)
    }

    func test_updateDateRange_year_startsOnJanuary1() {
        sut.selectedPeriod = .year
        sut.updateDateRange()

        let calendar = Calendar.current
        let startMonth = calendar.component(.month, from: sut.startDate)
        let startDay = calendar.component(.day, from: sut.startDate)

        XCTAssertEqual(startMonth, 1)
        XCTAssertEqual(startDay, 1)
    }

    func test_updateDateRange_year_endsOnDecember31() {
        sut.selectedPeriod = .year
        sut.updateDateRange()

        let calendar = Calendar.current
        let endMonth = calendar.component(.month, from: sut.endDate)
        let endDay = calendar.component(.day, from: sut.endDate)

        XCTAssertEqual(endMonth, 12)
        XCTAssertEqual(endDay, 31)
    }

    func test_updateDateRange_custom_doesNotChangeDates() {
        let customStart = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let customEnd = Date()
        sut.startDate = customStart
        sut.endDate = customEnd

        sut.selectedPeriod = .custom
        sut.updateDateRange()

        XCTAssertEqual(sut.startDate, customStart)
        XCTAssertEqual(sut.endDate, customEnd)
    }

    // MARK: - loadIncomeVsExpense

    @MainActor
    func test_loadIncomeVsExpense_withEmptyDatabase_returnsData() {
        sut.loadIncomeVsExpense(modelContext: modelContext)
        // Should have at least 1 month entry (current month)
        XCTAssertGreaterThanOrEqual(sut.incomeVsExpenseData.count, 1)
    }

    @MainActor
    func test_loadIncomeVsExpense_withTransactions_aggregatesCorrectly() throws {
        let income1 = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)
        let income2 = Transaction(amount: 500, date: Date(), descriptionText: "Freelance", type: .income)
        let expense1 = Transaction(amount: 200, date: Date(), descriptionText: "Groceries", type: .expense)
        let expense2 = Transaction(amount: 100, date: Date(), descriptionText: "Transport", type: .expense)

        modelContext.insert(income1)
        modelContext.insert(income2)
        modelContext.insert(expense1)
        modelContext.insert(expense2)
        try modelContext.save()

        sut.loadIncomeVsExpense(modelContext: modelContext)

        // Find the current month's data
        let currentMonthData = sut.incomeVsExpenseData.first
        XCTAssertNotNil(currentMonthData)
        XCTAssertEqual(currentMonthData?.income ?? 0, 3500, accuracy: 0.01)
        XCTAssertEqual(currentMonthData?.expenses ?? 0, 300, accuracy: 0.01)
    }

    @MainActor
    func test_loadIncomeVsExpense_excludesTransfers() throws {
        let income = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)
        let transfer = Transaction(amount: 500, date: Date(), descriptionText: "Transfer", type: .transfer)
        let expense = Transaction(amount: 200, date: Date(), descriptionText: "Groceries", type: .expense)

        modelContext.insert(income)
        modelContext.insert(transfer)
        modelContext.insert(expense)
        try modelContext.save()

        sut.loadIncomeVsExpense(modelContext: modelContext)

        let currentMonthData = sut.incomeVsExpenseData.first
        XCTAssertNotNil(currentMonthData)
        XCTAssertEqual(currentMonthData?.income ?? 0, 3000, accuracy: 0.01)
        XCTAssertEqual(currentMonthData?.expenses ?? 0, 200, accuracy: 0.01)
    }

    @MainActor
    func test_loadIncomeVsExpense_yearPeriod_hasMultipleMonths() throws {
        sut.selectedPeriod = .year
        sut.updateDateRange()

        let calendar = Calendar.current
        // Add a transaction for January
        var janComponents = calendar.dateComponents([.year], from: Date())
        janComponents.month = 1
        janComponents.day = 15
        if let janDate = calendar.date(from: janComponents) {
            let tx = Transaction(amount: 1000, date: janDate, descriptionText: "Jan Income", type: .income)
            modelContext.insert(tx)
        }

        try modelContext.save()

        sut.loadIncomeVsExpense(modelContext: modelContext)

        // Year should have 12 months
        XCTAssertEqual(sut.incomeVsExpenseData.count, 12)
    }

    // MARK: - loadCategoryBreakdown

    @MainActor
    func test_loadCategoryBreakdown_withEmptyDatabase_returnsEmpty() {
        sut.loadCategoryBreakdown(modelContext: modelContext)
        XCTAssertTrue(sut.categoryBreakdown.isEmpty)
    }

    @MainActor
    func test_loadCategoryBreakdown_groupsByCategory() throws {
        let groceriesCategory = BudgetCategory(type: .groceries, budgetAmount: 400)
        let transportCategory = BudgetCategory(type: .transport, budgetAmount: 200)
        modelContext.insert(groceriesCategory)
        modelContext.insert(transportCategory)

        let tx1 = Transaction(amount: 50, date: Date(), descriptionText: "Shop 1", type: .expense, category: groceriesCategory)
        let tx2 = Transaction(amount: 30, date: Date(), descriptionText: "Shop 2", type: .expense, category: groceriesCategory)
        let tx3 = Transaction(amount: 20, date: Date(), descriptionText: "Bus", type: .expense, category: transportCategory)

        modelContext.insert(tx1)
        modelContext.insert(tx2)
        modelContext.insert(tx3)
        try modelContext.save()

        sut.loadCategoryBreakdown(modelContext: modelContext)

        XCTAssertEqual(sut.categoryBreakdown.count, 2)

        let groceriesData = sut.categoryBreakdown.first { $0.category == "Groceries" }
        XCTAssertNotNil(groceriesData)
        XCTAssertEqual(groceriesData?.amount ?? 0, 80, accuracy: 0.01)

        let transportData = sut.categoryBreakdown.first { $0.category == "Transport" }
        XCTAssertNotNil(transportData)
        XCTAssertEqual(transportData?.amount ?? 0, 20, accuracy: 0.01)
    }

    @MainActor
    func test_loadCategoryBreakdown_calculatesPercentages() throws {
        let groceriesCategory = BudgetCategory(type: .groceries, budgetAmount: 400)
        let transportCategory = BudgetCategory(type: .transport, budgetAmount: 200)
        modelContext.insert(groceriesCategory)
        modelContext.insert(transportCategory)

        let tx1 = Transaction(amount: 75, date: Date(), descriptionText: "Shop", type: .expense, category: groceriesCategory)
        let tx2 = Transaction(amount: 25, date: Date(), descriptionText: "Bus", type: .expense, category: transportCategory)

        modelContext.insert(tx1)
        modelContext.insert(tx2)
        try modelContext.save()

        sut.loadCategoryBreakdown(modelContext: modelContext)

        let groceriesData = sut.categoryBreakdown.first { $0.category == "Groceries" }
        XCTAssertNotNil(groceriesData)
        XCTAssertEqual(groceriesData?.percentage ?? 0, 75.0, accuracy: 0.01)

        let transportData = sut.categoryBreakdown.first { $0.category == "Transport" }
        XCTAssertNotNil(transportData)
        XCTAssertEqual(transportData?.percentage ?? 0, 25.0, accuracy: 0.01)
    }

    @MainActor
    func test_loadCategoryBreakdown_excludesIncomeTransactions() throws {
        let groceriesCategory = BudgetCategory(type: .groceries, budgetAmount: 400)
        modelContext.insert(groceriesCategory)

        let expense = Transaction(amount: 50, date: Date(), descriptionText: "Shop", type: .expense, category: groceriesCategory)
        let income = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)

        modelContext.insert(expense)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadCategoryBreakdown(modelContext: modelContext)

        // Only expense should be counted
        let totalAmount = sut.categoryBreakdown.reduce(0.0) { $0 + $1.amount }
        XCTAssertEqual(totalAmount, 50, accuracy: 0.01)
    }

    @MainActor
    func test_loadCategoryBreakdown_sortedByAmountDescending() throws {
        let groceriesCategory = BudgetCategory(type: .groceries, budgetAmount: 400)
        let transportCategory = BudgetCategory(type: .transport, budgetAmount: 200)
        let diningCategory = BudgetCategory(type: .dining, budgetAmount: 150)
        modelContext.insert(groceriesCategory)
        modelContext.insert(transportCategory)
        modelContext.insert(diningCategory)

        let tx1 = Transaction(amount: 100, date: Date(), descriptionText: "Shop", type: .expense, category: groceriesCategory)
        let tx2 = Transaction(amount: 50, date: Date(), descriptionText: "Bus", type: .expense, category: transportCategory)
        let tx3 = Transaction(amount: 200, date: Date(), descriptionText: "Restaurant", type: .expense, category: diningCategory)

        modelContext.insert(tx1)
        modelContext.insert(tx2)
        modelContext.insert(tx3)
        try modelContext.save()

        sut.loadCategoryBreakdown(modelContext: modelContext)

        XCTAssertEqual(sut.categoryBreakdown.count, 3)
        XCTAssertEqual(sut.categoryBreakdown[0].category, "Dining")
        XCTAssertEqual(sut.categoryBreakdown[1].category, "Groceries")
        XCTAssertEqual(sut.categoryBreakdown[2].category, "Transport")
    }

    // MARK: - loadTopExpenses

    @MainActor
    func test_loadTopExpenses_withEmptyDatabase_returnsEmpty() {
        sut.loadTopExpenses(modelContext: modelContext)
        XCTAssertTrue(sut.topExpenses.isEmpty)
    }

    @MainActor
    func test_loadTopExpenses_sortedByAmountDescending() throws {
        let tx1 = Transaction(amount: 100, date: Date(), descriptionText: "Small", type: .expense)
        let tx2 = Transaction(amount: 500, date: Date(), descriptionText: "Large", type: .expense)
        let tx3 = Transaction(amount: 250, date: Date(), descriptionText: "Medium", type: .expense)

        modelContext.insert(tx1)
        modelContext.insert(tx2)
        modelContext.insert(tx3)
        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 3)
        XCTAssertEqual(sut.topExpenses[0].description, "Large")
        XCTAssertEqual(sut.topExpenses[0].amount, 500, accuracy: 0.01)
        XCTAssertEqual(sut.topExpenses[1].description, "Medium")
        XCTAssertEqual(sut.topExpenses[1].amount, 250, accuracy: 0.01)
        XCTAssertEqual(sut.topExpenses[2].description, "Small")
        XCTAssertEqual(sut.topExpenses[2].amount, 100, accuracy: 0.01)
    }

    @MainActor
    func test_loadTopExpenses_limitedToTen() throws {
        for i in 1...15 {
            let tx = Transaction(amount: Decimal(i * 10), date: Date(), descriptionText: "Expense \(i)", type: .expense)
            modelContext.insert(tx)
        }
        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 10)
    }

    @MainActor
    func test_loadTopExpenses_excludesIncomeAndTransfers() throws {
        let expense = Transaction(amount: 100, date: Date(), descriptionText: "Expense", type: .expense)
        let income = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)
        let transfer = Transaction(amount: 500, date: Date(), descriptionText: "Transfer", type: .transfer)

        modelContext.insert(expense)
        modelContext.insert(income)
        modelContext.insert(transfer)
        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 1)
        XCTAssertEqual(sut.topExpenses[0].description, "Expense")
    }

    @MainActor
    func test_loadTopExpenses_includesCategoryName() throws {
        let groceriesCategory = BudgetCategory(type: .groceries, budgetAmount: 400)
        modelContext.insert(groceriesCategory)

        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Shop", type: .expense, category: groceriesCategory)
        modelContext.insert(tx)
        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 1)
        XCTAssertEqual(sut.topExpenses[0].category, "Groceries")
    }

    @MainActor
    func test_loadTopExpenses_withNoCategoryReturnsNil() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Misc", type: .expense)
        modelContext.insert(tx)
        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 1)
        XCTAssertNil(sut.topExpenses[0].category)
    }

    @MainActor
    func test_loadTopExpenses_respectsDateRange() throws {
        // Transaction within range (current month)
        let withinRange = Transaction(amount: 100, date: Date(), descriptionText: "Current", type: .expense)
        modelContext.insert(withinRange)

        // Transaction outside range (3 months ago)
        let outsideDate = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let outsideRange = Transaction(amount: 500, date: outsideDate, descriptionText: "Old", type: .expense)
        modelContext.insert(outsideRange)

        try modelContext.save()

        sut.loadTopExpenses(modelContext: modelContext)

        XCTAssertEqual(sut.topExpenses.count, 1)
        XCTAssertEqual(sut.topExpenses[0].description, "Current")
    }

    // MARK: - loadBudgetUtilisation

    @MainActor
    func test_loadBudgetUtilisation_withEmptyDatabase_returnsEmpty() {
        sut.loadBudgetUtilisation(modelContext: modelContext)
        XCTAssertTrue(sut.budgetUtilisation.isEmpty)
    }

    @MainActor
    func test_loadBudgetUtilisation_returnsPerCategoryData() throws {
        let groceries = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        let transport = BudgetCategory(type: .transport, budgetAmount: 200, spentAmount: 150)
        modelContext.insert(groceries)
        modelContext.insert(transport)
        try modelContext.save()

        sut.loadBudgetUtilisation(modelContext: modelContext)

        XCTAssertEqual(sut.budgetUtilisation.count, 2)
    }

    @MainActor
    func test_loadBudgetUtilisation_calculatesPercentage() throws {
        let groceries = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        modelContext.insert(groceries)
        try modelContext.save()

        sut.loadBudgetUtilisation(modelContext: modelContext)

        let groceriesData = sut.budgetUtilisation.first { $0.category == "Groceries" }
        XCTAssertNotNil(groceriesData)
        XCTAssertEqual(groceriesData?.percentage ?? 0, 50.0, accuracy: 0.01)
    }

    @MainActor
    func test_loadBudgetUtilisation_excludesInactiveCategories() throws {
        let active = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        let inactive = BudgetCategory(type: .transport, budgetAmount: 200, spentAmount: 100, isActive: false)
        modelContext.insert(active)
        modelContext.insert(inactive)
        try modelContext.save()

        sut.loadBudgetUtilisation(modelContext: modelContext)

        XCTAssertEqual(sut.budgetUtilisation.count, 1)
        XCTAssertEqual(sut.budgetUtilisation.first?.category, "Groceries")
    }

    @MainActor
    func test_loadBudgetUtilisation_excludesZeroBudgetCategories() throws {
        let withBudget = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        let zeroBudget = BudgetCategory(type: .transport, budgetAmount: 0, spentAmount: 0)
        modelContext.insert(withBudget)
        modelContext.insert(zeroBudget)
        try modelContext.save()

        sut.loadBudgetUtilisation(modelContext: modelContext)

        XCTAssertEqual(sut.budgetUtilisation.count, 1)
        XCTAssertEqual(sut.budgetUtilisation.first?.category, "Groceries")
    }

    @MainActor
    func test_loadBudgetUtilisation_sortedByCategoryOrder() throws {
        let transport = BudgetCategory(type: .transport, budgetAmount: 200, spentAmount: 100)
        let groceries = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        // Insert transport first to verify sorting
        modelContext.insert(transport)
        modelContext.insert(groceries)
        try modelContext.save()

        sut.loadBudgetUtilisation(modelContext: modelContext)

        XCTAssertEqual(sut.budgetUtilisation.count, 2)
        // Groceries has order 2, Transport has order 3
        XCTAssertEqual(sut.budgetUtilisation[0].category, "Groceries")
        XCTAssertEqual(sut.budgetUtilisation[1].category, "Transport")
    }

    // MARK: - loadNetWorthHistory

    @MainActor
    func test_loadNetWorthHistory_withNoAccounts_returnsEmpty() {
        sut.loadNetWorthHistory(modelContext: modelContext)
        XCTAssertTrue(sut.netWorthHistory.isEmpty)
    }

    @MainActor
    func test_loadNetWorthHistory_withAccounts_returns12Points() throws {
        let account = Account(name: "Checking", type: .checking, balance: 10000)
        modelContext.insert(account)
        try modelContext.save()

        sut.loadNetWorthHistory(modelContext: modelContext)

        XCTAssertEqual(sut.netWorthHistory.count, 12)
    }

    @MainActor
    func test_loadNetWorthHistory_sortedByDateAscending() throws {
        let account = Account(name: "Checking", type: .checking, balance: 5000)
        modelContext.insert(account)
        try modelContext.save()

        sut.loadNetWorthHistory(modelContext: modelContext)

        for i in 0..<(sut.netWorthHistory.count - 1) {
            XCTAssertLessThanOrEqual(sut.netWorthHistory[i].date, sut.netWorthHistory[i + 1].date)
        }
    }

    @MainActor
    func test_loadNetWorthHistory_latestPointReflectsCurrentNetWorth() throws {
        let checking = Account(name: "Checking", type: .checking, balance: 10000)
        let savings = Account(name: "Savings", type: .savings, balance: 5000)
        modelContext.insert(checking)
        modelContext.insert(savings)
        try modelContext.save()

        sut.loadNetWorthHistory(modelContext: modelContext)

        // The last point should reflect current net worth (15000)
        let lastPoint = sut.netWorthHistory.last
        XCTAssertNotNil(lastPoint)
        XCTAssertEqual(lastPoint?.amount ?? 0, 15000, accuracy: 0.01)
    }

    // MARK: - loadAllReports

    @MainActor
    func test_loadAllReports_populatesAllDataArrays() throws {
        // Set up some data
        let account = Account(name: "Checking", type: .checking, balance: 5000)
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        let expense = Transaction(amount: 50, date: Date(), descriptionText: "Groceries", type: .expense, category: category)
        let income = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)

        modelContext.insert(account)
        modelContext.insert(category)
        modelContext.insert(expense)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadAllReports(modelContext: modelContext)

        // All sections should have data
        XCTAssertFalse(sut.incomeVsExpenseData.isEmpty)
        XCTAssertFalse(sut.categoryBreakdown.isEmpty)
        XCTAssertFalse(sut.netWorthHistory.isEmpty)
        XCTAssertFalse(sut.topExpenses.isEmpty)
        XCTAssertFalse(sut.budgetUtilisation.isEmpty)
    }

    @MainActor
    func test_loadAllReports_withEmptyDatabase_handlesGracefully() {
        sut.loadAllReports(modelContext: modelContext)

        // Should not crash and income vs expense should still have months
        XCTAssertGreaterThanOrEqual(sut.incomeVsExpenseData.count, 1)
        XCTAssertTrue(sut.categoryBreakdown.isEmpty)
        XCTAssertTrue(sut.netWorthHistory.isEmpty)
        XCTAssertTrue(sut.topExpenses.isEmpty)
        XCTAssertTrue(sut.budgetUtilisation.isEmpty)
    }

    // MARK: - Data Struct Tests

    func test_incomeExpenseData_netCalculation() {
        let data = IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 5000, expenses: 3000)
        XCTAssertEqual(data.net, 2000, accuracy: 0.01)
    }

    func test_incomeExpenseData_negativeNet() {
        let data = IncomeExpenseData(month: "Jan 2025", monthDate: Date(), income: 2000, expenses: 3000)
        XCTAssertEqual(data.net, -1000, accuracy: 0.01)
    }

    func test_incomeExpenseData_hasUniqueIds() {
        let data1 = IncomeExpenseData(month: "Jan", monthDate: Date(), income: 1000, expenses: 500)
        let data2 = IncomeExpenseData(month: "Feb", monthDate: Date(), income: 1000, expenses: 500)
        XCTAssertNotEqual(data1.id, data2.id)
    }

    func test_categoryBreakdownData_hasUniqueIds() {
        let data1 = CategoryBreakdownData(category: "Food", amount: 100, percentage: 50, color: .blue)
        let data2 = CategoryBreakdownData(category: "Transport", amount: 100, percentage: 50, color: .green)
        XCTAssertNotEqual(data1.id, data2.id)
    }

    func test_netWorthPoint_hasUniqueIds() {
        let point1 = NetWorthPoint(date: Date(), amount: 10000)
        let point2 = NetWorthPoint(date: Date(), amount: 10000)
        XCTAssertNotEqual(point1.id, point2.id)
    }

    func test_topExpenseData_hasUniqueIds() {
        let data1 = TopExpenseData(description: "Rent", amount: 1200, date: Date(), category: "Housing")
        let data2 = TopExpenseData(description: "Rent", amount: 1200, date: Date(), category: "Housing")
        XCTAssertNotEqual(data1.id, data2.id)
    }

    func test_budgetUtilisationData_percentageCalculation() {
        let data = BudgetUtilisationData(category: "Food", budgeted: 400, spent: 200)
        XCTAssertEqual(data.percentage, 50.0, accuracy: 0.01)
    }

    func test_budgetUtilisationData_percentageWithZeroBudget() {
        let data = BudgetUtilisationData(category: "Food", budgeted: 0, spent: 200)
        XCTAssertEqual(data.percentage, 0)
    }

    func test_budgetUtilisationData_overBudgetPercentage() {
        let data = BudgetUtilisationData(category: "Food", budgeted: 100, spent: 150)
        XCTAssertEqual(data.percentage, 150.0, accuracy: 0.01)
    }

    func test_budgetUtilisationData_hasUniqueIds() {
        let data1 = BudgetUtilisationData(category: "Food", budgeted: 400, spent: 200)
        let data2 = BudgetUtilisationData(category: "Transport", budgeted: 200, spent: 100)
        XCTAssertNotEqual(data1.id, data2.id)
    }

    // MARK: - ReportPeriod Enum

    func test_reportPeriod_allCases() {
        XCTAssertEqual(ReportPeriod.allCases.count, 4)
        XCTAssertTrue(ReportPeriod.allCases.contains(.month))
        XCTAssertTrue(ReportPeriod.allCases.contains(.quarter))
        XCTAssertTrue(ReportPeriod.allCases.contains(.year))
        XCTAssertTrue(ReportPeriod.allCases.contains(.custom))
    }

    func test_reportPeriod_rawValues() {
        XCTAssertEqual(ReportPeriod.month.rawValue, "Month")
        XCTAssertEqual(ReportPeriod.quarter.rawValue, "Quarter")
        XCTAssertEqual(ReportPeriod.year.rawValue, "Year")
        XCTAssertEqual(ReportPeriod.custom.rawValue, "Custom")
    }
}
