//
//  TransactionsViewModelTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class TransactionsViewModelTests: XCTestCase {

    var sut: TransactionsViewModel!
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
        sut = TransactionsViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_transactionsEmpty() {
        XCTAssertTrue(sut.transactions.isEmpty)
    }

    func test_initialState_filteredTransactionsEmpty() {
        XCTAssertTrue(sut.filteredTransactions.isEmpty)
    }

    func test_initialState_searchTextEmpty() {
        XCTAssertEqual(sut.searchText, "")
    }

    func test_initialState_selectedCategoryNil() {
        XCTAssertNil(sut.selectedCategory)
    }

    func test_initialState_selectedTypeNil() {
        XCTAssertNil(sut.selectedType)
    }

    func test_initialState_dateRangeIsThisMonth() {
        XCTAssertEqual(sut.dateRange, .thisMonth)
    }

    func test_initialState_sortOrderIsDateDescending() {
        XCTAssertEqual(sut.sortOrder, .dateDescending)
    }

    // MARK: - Computed Properties - Empty State

    func test_totalIncome_withNoTransactions_returnsZero() {
        XCTAssertEqual(sut.totalIncome, 0)
    }

    func test_totalExpenses_withNoTransactions_returnsZero() {
        XCTAssertEqual(sut.totalExpenses, 0)
    }

    func test_netAmount_withNoTransactions_returnsZero() {
        XCTAssertEqual(sut.netAmount, 0)
    }

    // MARK: - loadTransactions Tests

    @MainActor
    func test_loadTransactions_withEmptyDB_leavesEmptyArrays() {
        sut.loadTransactions(modelContext: modelContext)
        XCTAssertTrue(sut.transactions.isEmpty)
    }

    @MainActor
    func test_loadTransactions_loadsAllTransactions() throws {
        let tx1 = Transaction(amount: 100, date: Date(), descriptionText: "A", type: .expense)
        let tx2 = Transaction(amount: 200, date: Date(), descriptionText: "B", type: .income)
        modelContext.insert(tx1)
        modelContext.insert(tx2)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        XCTAssertEqual(sut.transactions.count, 2)
    }

    // MARK: - CRUD Operations

    @MainActor
    func test_addTransaction_increasesTransactionCount() throws {
        sut.loadTransactions(modelContext: modelContext)
        let initialCount = sut.transactions.count

        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Coffee", type: .expense)
        sut.addTransaction(tx, modelContext: modelContext)

        XCTAssertEqual(sut.transactions.count, initialCount + 1)
    }

    @MainActor
    func test_deleteTransaction_decreasesTransactionCount() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Coffee", type: .expense)
        sut.addTransaction(tx, modelContext: modelContext)
        let countAfterAdd = sut.transactions.count

        sut.deleteTransaction(tx, modelContext: modelContext)
        XCTAssertEqual(sut.transactions.count, countAfterAdd - 1)
    }

    // MARK: - Filtering by Type

    @MainActor
    func test_filterByType_expense_showsOnlyExpenses() throws {
        let expense = Transaction(amount: 100, date: Date(), descriptionText: "Rent", type: .expense)
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(expense)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.selectedType = .expense

        XCTAssertTrue(sut.filteredTransactions.allSatisfy { $0.type == .expense })
    }

    @MainActor
    func test_filterByType_income_showsOnlyIncome() throws {
        let expense = Transaction(amount: 100, date: Date(), descriptionText: "Rent", type: .expense)
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(expense)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.selectedType = .income

        XCTAssertTrue(sut.filteredTransactions.allSatisfy { $0.type == .income })
    }

    @MainActor
    func test_clearTypeFilter_showsAll() throws {
        let expense = Transaction(amount: 100, date: Date(), descriptionText: "Rent", type: .expense)
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(expense)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.selectedType = .expense
        sut.selectedType = nil

        XCTAssertEqual(sut.filteredTransactions.count, 2)
    }

    // MARK: - Search Filtering

    @MainActor
    func test_searchByDescription_findsMatchingTransaction() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Netflix subscription", type: .expense)
        modelContext.insert(tx)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.searchText = "Netflix"

        XCTAssertEqual(sut.filteredTransactions.count, 1)
        XCTAssertEqual(sut.filteredTransactions.first?.descriptionText, "Netflix subscription")
    }

    @MainActor
    func test_searchCaseInsensitive_findsMatch() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "NETFLIX", type: .expense)
        modelContext.insert(tx)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.searchText = "netflix"

        XCTAssertFalse(sut.filteredTransactions.isEmpty)
    }

    @MainActor
    func test_searchWithNoMatch_returnsEmpty() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Groceries", type: .expense)
        modelContext.insert(tx)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.searchText = "zzznomatch"

        XCTAssertTrue(sut.filteredTransactions.isEmpty)
    }

    @MainActor
    func test_clearSearch_restoresAll() throws {
        let tx1 = Transaction(amount: 50, date: Date(), descriptionText: "Netflix", type: .expense)
        let tx2 = Transaction(amount: 100, date: Date(), descriptionText: "Groceries", type: .expense)
        modelContext.insert(tx1)
        modelContext.insert(tx2)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.searchText = "Netflix"
        sut.searchText = ""

        XCTAssertEqual(sut.filteredTransactions.count, 2)
    }

    // MARK: - Sorting

    @MainActor
    func test_sortByDateDescending_newestFirst() throws {
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let newDate = Date()

        let old = Transaction(amount: 100, date: oldDate, descriptionText: "Old", type: .expense)
        let new = Transaction(amount: 200, date: newDate, descriptionText: "New", type: .expense)
        modelContext.insert(old)
        modelContext.insert(new)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.sortOrder = .dateDescending

        XCTAssertGreaterThan(sut.filteredTransactions.first!.date,
                             sut.filteredTransactions.last!.date)
    }

    @MainActor
    func test_sortByDateAscending_oldestFirst() throws {
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        let newDate = Date()

        let old = Transaction(amount: 100, date: oldDate, descriptionText: "Old", type: .expense)
        let new = Transaction(amount: 200, date: newDate, descriptionText: "New", type: .expense)
        modelContext.insert(old)
        modelContext.insert(new)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.sortOrder = .dateAscending

        XCTAssertLessThan(sut.filteredTransactions.first!.date,
                          sut.filteredTransactions.last!.date)
    }

    @MainActor
    func test_sortByAmountDescending_highestFirst() throws {
        let low = Transaction(amount: 10, date: Date(), descriptionText: "Low", type: .expense)
        let high = Transaction(amount: 1000, date: Date(), descriptionText: "High", type: .expense)
        modelContext.insert(low)
        modelContext.insert(high)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.sortOrder = .amountDescending

        XCTAssertGreaterThan(sut.filteredTransactions.first!.amount,
                             sut.filteredTransactions.last!.amount)
    }

    @MainActor
    func test_sortByAmountAscending_lowestFirst() throws {
        let low = Transaction(amount: 10, date: Date(), descriptionText: "Low", type: .expense)
        let high = Transaction(amount: 1000, date: Date(), descriptionText: "High", type: .expense)
        modelContext.insert(low)
        modelContext.insert(high)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)
        sut.sortOrder = .amountAscending

        XCTAssertLessThan(sut.filteredTransactions.first!.amount,
                          sut.filteredTransactions.last!.amount)
    }

    // MARK: - Totals on Filtered Set

    @MainActor
    func test_totalIncome_sumsFilteredIncomeOnly() throws {
        let income1 = Transaction(amount: 3000, date: Date(), descriptionText: "Salary", type: .income)
        let income2 = Transaction(amount: 500, date: Date(), descriptionText: "Bonus", type: .income)
        let expense = Transaction(amount: 200, date: Date(), descriptionText: "Food", type: .expense)
        modelContext.insert(income1)
        modelContext.insert(income2)
        modelContext.insert(expense)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)

        XCTAssertEqual(sut.totalIncome, 3500)
    }

    @MainActor
    func test_totalExpenses_sumsFilteredExpensesOnly() throws {
        let expense1 = Transaction(amount: 200, date: Date(), descriptionText: "Food", type: .expense)
        let expense2 = Transaction(amount: 100, date: Date(), descriptionText: "Coffee", type: .expense)
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(expense1)
        modelContext.insert(expense2)
        modelContext.insert(income)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)

        XCTAssertEqual(sut.totalExpenses, 300)
    }

    @MainActor
    func test_netAmount_isIncomeMinusExpenses() throws {
        let income = Transaction(amount: 4000, date: Date(), descriptionText: "Salary", type: .income)
        let expense = Transaction(amount: 1500, date: Date(), descriptionText: "Bills", type: .expense)
        modelContext.insert(income)
        modelContext.insert(expense)
        try modelContext.save()

        sut.loadTransactions(modelContext: modelContext)

        XCTAssertEqual(sut.netAmount, 2500)
    }

    // MARK: - clearFilters Tests

    @MainActor
    func test_clearFilters_resetsAllFilters() throws {
        sut.loadTransactions(modelContext: modelContext)
        sut.searchText = "test"
        sut.selectedCategory = .groceries
        sut.selectedType = .expense
        sut.dateRange = .allTime

        sut.clearFilters()

        XCTAssertEqual(sut.searchText, "")
        XCTAssertNil(sut.selectedCategory)
        XCTAssertNil(sut.selectedType)
        XCTAssertEqual(sut.dateRange, .thisMonth)
    }

    // MARK: - Recurring Detection Trigger

    @MainActor
    func test_addTransaction_triggersRecurringDetection_afterSecondMatchingTransaction() throws {
        // Add first transaction — no detection yet
        let tx1 = Transaction(
            amount: Decimal(string: "17.99")!,
            date: Date(),
            descriptionText: "Netflix",
            type: .expense
        )
        sut.addTransaction(tx1, modelContext: modelContext)
        XCTAssertNil(sut.detectedRecurring)
        XCTAssertFalse(sut.showingRecurringSuggestion)

        // Add second transaction with same vendor — detection triggers
        let tx2 = Transaction(
            amount: Decimal(string: "17.99")!,
            date: Date(),
            descriptionText: "Netflix",
            type: .expense
        )
        sut.addTransaction(tx2, modelContext: modelContext)
        XCTAssertNotNil(sut.detectedRecurring)
        XCTAssertTrue(sut.showingRecurringSuggestion)
        XCTAssertEqual(sut.detectedRecurring?.vendor, "Netflix")
    }

    // MARK: - DateRange Tests

    func test_dateRange_allCasesCount() {
        XCTAssertEqual(TransactionsViewModel.DateRange.allCases.count, 6)
    }

    func test_dateRange_thisMonthRawValue() {
        XCTAssertEqual(TransactionsViewModel.DateRange.thisMonth.rawValue, "This Month")
    }

    func test_dateRange_allTimeInterval_startIsDistantPast() {
        let interval = TransactionsViewModel.DateRange.allTime.dateInterval
        XCTAssertLessThan(interval.start, Date(timeIntervalSince1970: 0))
    }

    func test_dateRange_thisWeekInterval_startIsBeforeNow() {
        let interval = TransactionsViewModel.DateRange.thisWeek.dateInterval
        XCTAssertLessThan(interval.start, Date())
    }

    func test_dateRange_thisYearInterval_startIsBeforeNow() {
        let interval = TransactionsViewModel.DateRange.thisYear.dateInterval
        XCTAssertLessThan(interval.start, Date())
    }

    // MARK: - SortOrder Tests

    func test_sortOrder_allCasesCount() {
        XCTAssertEqual(TransactionsViewModel.SortOrder.allCases.count, 4)
    }

    func test_sortOrder_rawValues() {
        XCTAssertEqual(TransactionsViewModel.SortOrder.dateDescending.rawValue, "Newest First")
        XCTAssertEqual(TransactionsViewModel.SortOrder.dateAscending.rawValue, "Oldest First")
        XCTAssertEqual(TransactionsViewModel.SortOrder.amountDescending.rawValue, "Highest Amount")
        XCTAssertEqual(TransactionsViewModel.SortOrder.amountAscending.rawValue, "Lowest Amount")
    }
}
