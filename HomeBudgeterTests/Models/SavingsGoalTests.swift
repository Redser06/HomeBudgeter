//
//  SavingsGoalTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class SavingsGoalTests: XCTestCase {

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

    // MARK: - Creation Tests

    func test_createSavingsGoal_withValidData_succeeds() {
        // Given
        let name = "Emergency Fund"
        let target: Decimal = 10000

        // When
        let goal = SavingsGoal(
            name: name,
            targetAmount: target,
            currentAmount: 0
        )

        // Then
        XCTAssertNotNil(goal.id)
        XCTAssertEqual(goal.name, name)
        XCTAssertEqual(goal.targetAmount, target)
        XCTAssertEqual(goal.currentAmount, 0)
        XCTAssertFalse(goal.isCompleted)
    }

    func test_createSavingsGoal_withDeadline_setsDate() {
        // Given
        let deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date())!

        // When
        let goal = SavingsGoal(
            name: "Holiday",
            targetAmount: 3000,
            currentAmount: 0,
            deadline: deadline
        )

        // Then
        XCTAssertEqual(goal.deadline, deadline)
    }

    // MARK: - Progress Calculation Tests

    func test_progressPercentage_withZeroSaved_returnsZero() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 0
        )

        // Then
        XCTAssertEqual(goal.progressPercentage, 0)
    }

    func test_progressPercentage_withHalfSaved_returnsFifty() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 500
        )

        // Then — progressPercentage returns 0-100
        XCTAssertEqual(goal.progressPercentage, 50.0, accuracy: 0.1)
    }

    func test_progressPercentage_whenComplete_returnsHundred() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 1000
        )

        // Then
        XCTAssertEqual(goal.progressPercentage, 100.0, accuracy: 0.1)
    }

    func test_progressPercentage_whenOverfunded_exceedsHundred() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 1500
        )

        // Then
        XCTAssertGreaterThanOrEqual(goal.progressPercentage, 100.0)
        XCTAssertGreaterThan(goal.progressPercentage, 0)
    }

    // MARK: - Remaining Amount Tests

    func test_remainingAmount_calculatesCorrectly() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 5000,
            currentAmount: 2000
        )

        // Then
        XCTAssertEqual(goal.remainingAmount, 3000)
    }

    func test_remainingAmount_whenComplete_returnsZeroOrNegative() {
        // Given
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 1000
        )

        // Then
        XCTAssertEqual(goal.remainingAmount, 0)
    }

    // MARK: - Priority Tests

    func test_defaultPriority_isMedium() {
        // Given/When
        let goal = SavingsGoal(
            name: "Test",
            targetAmount: 1000,
            currentAmount: 0
        )

        // Then
        XCTAssertEqual(goal.priority, .medium)
    }

    func test_setPriority_toHigh_works() {
        // Given
        let goal = SavingsGoal(
            name: "Urgent",
            targetAmount: 1000,
            currentAmount: 0,
            priority: .high
        )

        // Then
        XCTAssertEqual(goal.priority, .high)
    }

    // MARK: - Edge Cases

    func test_savingsGoal_withZeroTarget_isValid() {
        // Given/When
        let goal = SavingsGoal(
            name: "Zero Target",
            targetAmount: 0,
            currentAmount: 0
        )

        // Then
        XCTAssertEqual(goal.targetAmount, 0)
    }

    func test_savingsGoal_withLargeAmount_handlesCorrectly() {
        // Given
        let largeAmount: Decimal = 999_999_999.99

        // When
        let goal = SavingsGoal(
            name: "Large Goal",
            targetAmount: largeAmount,
            currentAmount: 0
        )

        // Then
        XCTAssertEqual(goal.targetAmount, largeAmount)
    }
}
