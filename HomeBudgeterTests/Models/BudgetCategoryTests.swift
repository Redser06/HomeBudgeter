//
//  BudgetCategoryTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
import SwiftUI
@testable import Home_Budgeter

final class BudgetCategoryTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
            RecurringTemplate.self
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

    // MARK: - Initialisation Tests

    func test_init_withDefaults_setsCorrectDefaults() {
        let category = BudgetCategory(type: .groceries)
        XCTAssertNotNil(category.id)
        XCTAssertEqual(category.type, .groceries)
        XCTAssertEqual(category.budgetAmount, 0)
        XCTAssertEqual(category.spentAmount, 0)
        XCTAssertEqual(category.period, .monthly)
        XCTAssertTrue(category.isActive)
    }

    func test_init_withCustomValues_setsProperties() {
        let category = BudgetCategory(
            type: .housing,
            budgetAmount: 1500,
            spentAmount: 750,
            period: .weekly,
            isActive: false
        )
        XCTAssertEqual(category.type, .housing)
        XCTAssertEqual(category.budgetAmount, 1500)
        XCTAssertEqual(category.spentAmount, 750)
        XCTAssertEqual(category.period, .weekly)
        XCTAssertFalse(category.isActive)
    }

    func test_init_generatesUniqueIds() {
        let c1 = BudgetCategory(type: .housing)
        let c2 = BudgetCategory(type: .housing)
        XCTAssertNotEqual(c1.id, c2.id)
    }

    // MARK: - remainingAmount Tests

    func test_remainingAmount_withNoSpending_equalsBudget() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400)
        XCTAssertEqual(category.remainingAmount, 400)
    }

    func test_remainingAmount_withPartialSpending_returnsCorrectValue() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 150)
        XCTAssertEqual(category.remainingAmount, 250)
    }

    func test_remainingAmount_whenExactlyOnBudget_returnsZero() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 400)
        XCTAssertEqual(category.remainingAmount, 0)
    }

    func test_remainingAmount_whenOverBudget_returnsNegativeValue() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 500)
        XCTAssertEqual(category.remainingAmount, -100)
    }

    func test_remainingAmount_withZeroBudget_returnsNegativeSpent() {
        let category = BudgetCategory(type: .other, budgetAmount: 0, spentAmount: 50)
        XCTAssertEqual(category.remainingAmount, -50)
    }

    // MARK: - percentageUsed Tests

    func test_percentageUsed_withZeroBudget_returnsZero() {
        let category = BudgetCategory(type: .other, budgetAmount: 0, spentAmount: 100)
        XCTAssertEqual(category.percentageUsed, 0.0)
    }

    func test_percentageUsed_withNoSpending_returnsZero() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 0)
        XCTAssertEqual(category.percentageUsed, 0.0)
    }

    func test_percentageUsed_withHalfSpending_returns50() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        XCTAssertEqual(category.percentageUsed, 50.0, accuracy: 0.01)
    }

    func test_percentageUsed_atExactBudget_returns100() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 400)
        XCTAssertEqual(category.percentageUsed, 100.0, accuracy: 0.01)
    }

    func test_percentageUsed_overBudget_returnsOver100() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 600)
        XCTAssertEqual(category.percentageUsed, 150.0, accuracy: 0.01)
    }

    func test_percentageUsed_at74Percent_isBelow75Threshold() {
        let category = BudgetCategory(type: .dining, budgetAmount: 100, spentAmount: 74)
        XCTAssertLessThan(category.percentageUsed, 75.0)
    }

    func test_percentageUsed_at75Percent_meetsWarningThreshold() {
        let category = BudgetCategory(type: .dining, budgetAmount: 100, spentAmount: 75)
        XCTAssertGreaterThanOrEqual(category.percentageUsed, 75.0)
    }

    func test_percentageUsed_at89Percent_isBelow90Threshold() {
        let category = BudgetCategory(type: .dining, budgetAmount: 100, spentAmount: 89)
        XCTAssertLessThan(category.percentageUsed, 90.0)
    }

    // MARK: - isOverBudget Tests

    func test_isOverBudget_withNoSpending_returnsFalse() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 0)
        XCTAssertFalse(category.isOverBudget)
    }

    func test_isOverBudget_withPartialSpending_returnsFalse() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 200)
        XCTAssertFalse(category.isOverBudget)
    }

    func test_isOverBudget_atExactBudget_returnsFalse() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 400)
        XCTAssertFalse(category.isOverBudget)
    }

    func test_isOverBudget_withOneCentOver_returnsTrue() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: Decimal(string: "400.01")!)
        XCTAssertTrue(category.isOverBudget)
    }

    func test_isOverBudget_withLargeOverspend_returnsTrue() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 800)
        XCTAssertTrue(category.isOverBudget)
    }

    func test_isOverBudget_withZeroBudgetAndAnySpend_returnsTrue() {
        let category = BudgetCategory(type: .other, budgetAmount: 0, spentAmount: 1)
        XCTAssertTrue(category.isOverBudget)
    }

    // MARK: - statusColor Tests
    // statusColor thresholds: >= 90% = red (#EF4444), >= 75% = amber (#F59E0B), else green (#22C55E)

    static let dangerRed = Color(red: 239/255, green: 68/255, blue: 68/255)
    static let warningAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let successGreen = Color(red: 34/255, green: 197/255, blue: 94/255)

    func test_statusColor_withLowSpending_returnsGreen() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400, spentAmount: 100)
        // 25% used - should be green
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.successGreen)
    }

    func test_statusColor_at74Percent_returnsGreen() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 74)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.successGreen)
    }

    func test_statusColor_at75Percent_returnsAmber() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 75)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.warningAmber)
    }

    func test_statusColor_at89Percent_returnsAmber() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 89)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.warningAmber)
    }

    func test_statusColor_at90Percent_returnsRed() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 90)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.dangerRed)
    }

    func test_statusColor_at100Percent_returnsRed() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 100)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.dangerRed)
    }

    func test_statusColor_overBudget_returnsRed() {
        let category = BudgetCategory(type: .groceries, budgetAmount: 100, spentAmount: 150)
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.dangerRed)
    }

    func test_statusColor_withZeroBudgetAndZeroSpend_returnsGreen() {
        let category = BudgetCategory(type: .other, budgetAmount: 0, spentAmount: 0)
        // percentageUsed returns 0 for zero budget, so green
        XCTAssertEqual(category.statusColor, BudgetCategoryTests.successGreen)
    }

    // MARK: - CategoryType Tests

    func test_categoryType_allCasesCount() {
        XCTAssertEqual(CategoryType.allCases.count, 11)
    }

    func test_categoryType_allHaveNonEmptyIcons() {
        for type in CategoryType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "Icon for \(type.rawValue) is empty")
        }
    }

    func test_categoryType_orderIsUnique() {
        let orders = CategoryType.allCases.map { $0.order }
        let uniqueOrders = Set(orders)
        XCTAssertEqual(orders.count, uniqueOrders.count, "Category orders should be unique")
    }

    func test_categoryType_housingOrder_isZero() {
        XCTAssertEqual(CategoryType.housing.order, 0)
    }

    func test_categoryType_otherOrder_isLast() {
        XCTAssertEqual(CategoryType.other.order, 10)
    }

    func test_categoryType_rawValues_areCorrect() {
        XCTAssertEqual(CategoryType.housing.rawValue, "Housing")
        XCTAssertEqual(CategoryType.groceries.rawValue, "Groceries")
        XCTAssertEqual(CategoryType.transport.rawValue, "Transport")
        XCTAssertEqual(CategoryType.savings.rawValue, "Savings")
    }

    // MARK: - BudgetPeriod Tests

    func test_budgetPeriod_weeklyRawValue() {
        XCTAssertEqual(BudgetPeriod.weekly.rawValue, "Weekly")
    }

    func test_budgetPeriod_monthlyRawValue() {
        XCTAssertEqual(BudgetPeriod.monthly.rawValue, "Monthly")
    }

    func test_budgetPeriod_yearlyRawValue() {
        XCTAssertEqual(BudgetPeriod.yearly.rawValue, "Yearly")
    }

    // MARK: - Persistence Tests

    @MainActor
    func test_saveAndFetch_budgetCategory_persistsCorrectly() throws {
        let category = BudgetCategory(type: .groceries, budgetAmount: 500, spentAmount: 200)
        modelContext.insert(category)
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.budgetAmount, 500)
        XCTAssertEqual(fetched.first?.spentAmount, 200)
    }

    @MainActor
    func test_updateSpentAmount_persistsChange() throws {
        let category = BudgetCategory(type: .dining, budgetAmount: 200, spentAmount: 50)
        modelContext.insert(category)
        try modelContext.save()

        category.spentAmount = 175
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.first?.spentAmount, 175)
    }
}
