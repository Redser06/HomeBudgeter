//
//  BudgetViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class BudgetViewModelTests: XCTestCase {

    var sut: BudgetViewModel!
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

        sut = BudgetViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_hasEmptyCategories() {
        // Then
        XCTAssertTrue(sut.categories.isEmpty)
        XCTAssertEqual(sut.selectedPeriod, .monthly)
        XCTAssertFalse(sut.showingAddCategory)
        XCTAssertNil(sut.editingCategory)
    }

    // MARK: - Computed Properties

    func test_totalBudgeted_withNoCategories_returnsZero() {
        // Then
        XCTAssertEqual(sut.totalBudgeted, 0)
    }

    func test_totalSpentAmount_withNoCategories_returnsZero() {
        // Then
        XCTAssertEqual(sut.totalSpentAmount, 0)
    }

    func test_totalRemaining_withNoCategories_returnsZero() {
        // Then
        XCTAssertEqual(sut.totalRemaining, 0)
    }

    func test_overallProgress_withNoCategories_returnsZero() {
        // Then
        XCTAssertEqual(sut.overallProgress, 0)
    }

    // MARK: - Load Categories

    @MainActor
    func test_loadCategories_withEmptyDatabase_createsDefaultCategories() {
        // When
        sut.loadCategories(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.categories.count, 11) // All CategoryType cases
    }

    @MainActor
    func test_loadCategories_createsAllCategoryTypes() {
        // When
        sut.loadCategories(modelContext: modelContext)

        // Then
        let categoryTypes = sut.categories.map { $0.type }
        for type in CategoryType.allCases {
            XCTAssertTrue(categoryTypes.contains(type), "Missing category: \(type.rawValue)")
        }
    }

    // MARK: - Budget Calculations

    @MainActor
    func test_totalBudgeted_sumsAllCategories() {
        // Given
        sut.loadCategories(modelContext: modelContext)

        // When
        let total = sut.totalBudgeted

        // Then
        let expectedTotal = sut.categories.reduce(Decimal(0)) { $0 + $1.budgetAmount }
        XCTAssertEqual(total, expectedTotal)
    }

    // MARK: - Update Budget

    @MainActor
    func test_updateBudget_changesAmount() {
        // Given
        sut.loadCategories(modelContext: modelContext)
        guard let category = sut.categories.first else {
            XCTFail("No categories loaded")
            return
        }
        let newAmount: Decimal = 999

        // When
        sut.updateBudget(for: category, amount: newAmount, modelContext: modelContext)

        // Then
        XCTAssertEqual(category.budgetAmount, newAmount)
    }

    // MARK: - View Compatibility Properties

    func test_budgetCategories_returnsCategoriesArray() {
        // Then
        XCTAssertEqual(sut.budgetCategories, sut.categories)
    }

    func test_totalBudget_returnsDoubleValue() {
        // Then
        XCTAssertEqual(sut.totalBudget, Double(truncating: sut.totalBudgeted as NSNumber))
    }

    func test_totalSpent_returnsDoubleValue() {
        // Then
        XCTAssertEqual(sut.totalSpent, Double(truncating: sut.totalSpentAmount as NSNumber))
    }

    func test_remaining_returnsDoubleValue() {
        // Then
        XCTAssertEqual(sut.remaining, Double(truncating: sut.totalRemaining as NSNumber))
    }

    func test_spentPercentage_returnsOverallProgress() {
        // Then
        XCTAssertEqual(sut.spentPercentage, sut.overallProgress)
    }

    // MARK: - Categories Over Budget

    @MainActor
    func test_categoriesOverBudget_withNoneOver_returnsEmpty() {
        // Given
        sut.loadCategories(modelContext: modelContext)
        // Default categories have 0 spent, so none over budget

        // Then
        XCTAssertTrue(sut.categoriesOverBudget.isEmpty)
    }

    // MARK: - Categories Near Limit

    @MainActor
    func test_categoriesNearLimit_withNoneNear_returnsEmpty() {
        // Given
        sut.loadCategories(modelContext: modelContext)
        // Default categories have 0 spent, so none near limit

        // Then
        XCTAssertTrue(sut.categoriesNearLimit.isEmpty)
    }
}

// MARK: - BudgetCategory Extension Tests

final class BudgetCategoryExtensionTests: XCTestCase {

    func test_name_returnsCategoryTypeRawValue() {
        // Given
        let category = BudgetCategory(
            type: .groceries,
            budgetAmount: 500,
            period: .monthly
        )

        // Then
        XCTAssertEqual(category.name, "Groceries")
    }

    func test_budgeted_returnsDoubleValue() {
        // Given
        let category = BudgetCategory(
            type: .groceries,
            budgetAmount: 500.50,
            period: .monthly
        )

        // Then
        XCTAssertEqual(category.budgeted, 500.50, accuracy: 0.01)
    }

    func test_spent_returnsDoubleValue() {
        // Given
        let category = BudgetCategory(
            type: .groceries,
            budgetAmount: 500,
            period: .monthly
        )
        category.spentAmount = 250.75

        // Then
        XCTAssertEqual(category.spent, 250.75, accuracy: 0.01)
    }

    func test_remaining_calculatesCorrectly() {
        // Given
        let category = BudgetCategory(
            type: .groceries,
            budgetAmount: 500,
            period: .monthly
        )
        category.spentAmount = 200

        // Then
        XCTAssertEqual(category.remaining, 300, accuracy: 0.01)
    }

    func test_icon_returnsCategoryTypeIcon() {
        // Given
        let category = BudgetCategory(
            type: .groceries,
            budgetAmount: 500,
            period: .monthly
        )

        // Then
        XCTAssertEqual(category.icon, CategoryType.groceries.icon)
    }
}
