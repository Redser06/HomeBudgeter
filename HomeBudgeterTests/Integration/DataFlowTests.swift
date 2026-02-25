//
//  DataFlowTests.swift
//  HomeBudgeterTests
//
//  Integration tests verifying that data flows correctly between layers:
//  transactions → budget spent amounts, accounts → net worth, etc.
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class DataFlowTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self,
            HouseholdMember.self,
            Investment.self,
            InvestmentTransaction.self,
            SyncQueueEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Transaction → Budget Category Flow

    @MainActor
    func test_budgetCategory_spentAmount_canBeUpdatedDirectly() throws {
        // Direct spentAmount mutation (as recalculateSpending does after aggregating)
        let category = BudgetCategory(type: .groceries, budgetAmount: 400)
        modelContext.insert(category)
        try modelContext.save()

        // Simulate what recalculateSpending would set
        category.spentAmount = 150
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.first?.spentAmount, 150)
    }

    @MainActor
    func test_budgetCategory_multipleSpends_sumCorrectly() throws {
        // Test that manually summing expenses from transactions gives correct spent amount
        let category = BudgetCategory(type: .dining, budgetAmount: 200)
        modelContext.insert(category)
        try modelContext.save()

        let amounts: [Decimal] = [45, 62]
        category.spentAmount = amounts.reduce(0, +)
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.first?.spentAmount, 107)
    }

    @MainActor
    func test_transaction_expenseType_isExpense() throws {
        let expense = Transaction(amount: 100, date: Date(), descriptionText: "Food", type: .expense)
        XCTAssertEqual(expense.type, .expense)
    }

    @MainActor
    func test_transaction_incomeType_isIncome() throws {
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        XCTAssertEqual(income.type, .income)
    }

    // MARK: - Transaction → Dashboard Flow

    @MainActor
    func test_dashboardData_withExpense_showsCorrectMonthlyExpenses() throws {
        let expense = Transaction(amount: 300, date: Date(), descriptionText: "Rent", type: .expense)
        modelContext.insert(expense)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        XCTAssertEqual(vm.monthlyExpenses, 300)
    }

    @MainActor
    func test_dashboardData_withIncome_showsCorrectMonthlyIncome() throws {
        let income = Transaction(amount: 4500, date: Date(), descriptionText: "Salary", type: .income)
        modelContext.insert(income)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        XCTAssertEqual(vm.monthlyIncome, 4500)
    }

    @MainActor
    func test_dashboardData_savingsRate_calculatedCorrectly() throws {
        let income = Transaction(amount: 4000, date: Date(), descriptionText: "Salary", type: .income)
        let expense = Transaction(amount: 2000, date: Date(), descriptionText: "Expenses", type: .expense)
        modelContext.insert(income)
        modelContext.insert(expense)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        XCTAssertEqual(vm.savingsRate, 50.0, accuracy: 0.1)
    }

    // MARK: - Account → Net Worth Flow

    @MainActor
    func test_netWorth_withAssetAccounts_sumsBalances() throws {
        let checking = Account(name: "Checking", type: .checking, balance: 5000)
        let savings = Account(name: "Savings", type: .savings, balance: 10000)
        modelContext.insert(checking)
        modelContext.insert(savings)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        XCTAssertEqual(vm.netWorth, 15000)
    }

    @MainActor
    func test_netWorth_withCreditCardDebt_subtractsBalance() throws {
        let savings = Account(name: "Savings", type: .savings, balance: 8000)
        let credit = Account(name: "Visa", type: .credit, balance: -3000)
        modelContext.insert(savings)
        modelContext.insert(credit)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        XCTAssertEqual(vm.netWorth, 5000)
    }

    @MainActor
    func test_netWorth_withMixedAccounts_calculatesCorrectly() throws {
        let checking = Account(name: "Checking", type: .checking, balance: 2000)
        let investment = Account(name: "Stocks", type: .investment, balance: 15000)
        let credit = Account(name: "Credit", type: .credit, balance: -1500)
        let inactive = Account(name: "Old", type: .savings, balance: 500, isActive: false)
        modelContext.insert(checking)
        modelContext.insert(investment)
        modelContext.insert(credit)
        modelContext.insert(inactive)
        try modelContext.save()

        let vm = DashboardViewModel()
        vm.loadData(modelContext: modelContext)

        // 2000 + 15000 - 1500 = 15500 (inactive excluded)
        XCTAssertEqual(vm.netWorth, 15500)
    }

    // MARK: - Transaction Filter → Totals Flow

    @MainActor
    func test_transactionsViewModel_totalsMatchFilteredSet() throws {
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        let exp1 = Transaction(amount: 200, date: Date(), descriptionText: "Food", type: .expense)
        let exp2 = Transaction(amount: 100, date: Date(), descriptionText: "Coffee", type: .expense)
        modelContext.insert(income)
        modelContext.insert(exp1)
        modelContext.insert(exp2)
        try modelContext.save()

        let vm = TransactionsViewModel()
        vm.loadTransactions(modelContext: modelContext)

        XCTAssertEqual(vm.totalIncome, 5000)
        XCTAssertEqual(vm.totalExpenses, 300)
        XCTAssertEqual(vm.netAmount, 4700)
    }

    @MainActor
    func test_transactionsViewModel_afterDelete_totalsUpdate() throws {
        let income = Transaction(amount: 5000, date: Date(), descriptionText: "Salary", type: .income)
        let expense = Transaction(amount: 200, date: Date(), descriptionText: "Food", type: .expense)
        modelContext.insert(income)
        modelContext.insert(expense)
        try modelContext.save()

        let vm = TransactionsViewModel()
        vm.loadTransactions(modelContext: modelContext)

        vm.deleteTransaction(expense, modelContext: modelContext)

        XCTAssertEqual(vm.totalExpenses, 0)
        XCTAssertEqual(vm.netAmount, vm.totalIncome)
    }

    // MARK: - BudgetViewModel CRUD Flow

    @MainActor
    func test_addBudget_thenLoad_categoryAppears() throws {
        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)

        vm.addBudget(name: "Dining", amount: 300, icon: "fork.knife", modelContext: modelContext)

        let found = vm.categories.first { $0.type == .dining }
        XCTAssertNotNil(found)
    }

    @MainActor
    func test_updateBudget_changesAmount_reflected() throws {
        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)

        guard let category = vm.categories.first else {
            XCTFail("No categories available")
            return
        }

        vm.updateBudget(for: category, amount: 999, modelContext: modelContext)

        XCTAssertEqual(category.budgetAmount, 999)
    }

    @MainActor
    func test_deleteBudget_removedFromDatabase() throws {
        // First load which creates 13 default categories
        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)
        XCTAssertEqual(vm.categories.count, 13)

        // Delete one category
        guard let category = vm.categories.first else {
            XCTFail("No categories")
            return
        }
        let countBefore = vm.categories.count
        vm.deleteBudget(category, modelContext: modelContext)

        // After delete, loadCategories is called again, but since there are still
        // remaining active categories, no new defaults are created
        XCTAssertEqual(vm.categories.count, countBefore - 1)
    }

    // MARK: - Budget Over/Near Limit Flow

    @MainActor
    func test_categoriesOverBudget_whenCategoryExceeded_isIncluded() throws {
        let category = BudgetCategory(type: .shopping, budgetAmount: 100, spentAmount: 150)
        modelContext.insert(category)
        try modelContext.save()

        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)

        XCTAssertFalse(vm.categoriesOverBudget.isEmpty)
    }

    @MainActor
    func test_categoriesNearLimit_at85Percent_isIncluded() throws {
        let category = BudgetCategory(type: .personal, budgetAmount: 100, spentAmount: 85)
        modelContext.insert(category)
        try modelContext.save()

        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)

        XCTAssertFalse(vm.categoriesNearLimit.isEmpty)
    }

    @MainActor
    func test_categoriesNearLimit_doesNotIncludeOverBudget() throws {
        let overBudget = BudgetCategory(type: .healthcare, budgetAmount: 100, spentAmount: 110)
        let nearLimit = BudgetCategory(type: .personal, budgetAmount: 100, spentAmount: 85)
        modelContext.insert(overBudget)
        modelContext.insert(nearLimit)
        try modelContext.save()

        let vm = BudgetViewModel()
        vm.loadCategories(modelContext: modelContext)

        // categoriesNearLimit should NOT include over-budget categories
        XCTAssertFalse(vm.categoriesNearLimit.contains { $0.type == .healthcare })
        XCTAssertTrue(vm.categoriesNearLimit.contains { $0.type == .personal })
    }

    // MARK: - Document → Storage Calculation Flow

    @MainActor
    func test_documentsViewModel_afterAddingDocuments_storageUpdates() throws {
        let doc1 = Document(filename: "a.pdf", localPath: "/a.pdf", fileSize: 1024 * 1024) // 1MB
        let doc2 = Document(filename: "b.pdf", localPath: "/b.pdf", fileSize: 2 * 1024 * 1024) // 2MB
        modelContext.insert(doc1)
        modelContext.insert(doc2)
        try modelContext.save()

        let vm = DocumentsViewModel()
        vm.loadDocuments(modelContext: modelContext)

        XCTAssertEqual(vm.totalStorageUsed, 3 * 1024 * 1024)
    }
}
