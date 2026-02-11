//
//  SavingsGoalViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class SavingsGoalViewModelTests: XCTestCase {

    var sut: SavingsGoalViewModel!
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

        sut = SavingsGoalViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_hasEmptyGoals() {
        XCTAssertTrue(sut.goals.isEmpty)
        XCTAssertFalse(sut.showingCreateSheet)
        XCTAssertNil(sut.selectedGoal)
    }

    // MARK: - Computed Properties

    func test_totalSaved_withNoGoals_returnsZero() {
        XCTAssertEqual(sut.totalSaved, 0)
    }

    func test_totalTarget_withNoGoals_returnsZero() {
        XCTAssertEqual(sut.totalTarget, 0)
    }

    func test_completedGoals_withNoGoals_returnsEmpty() {
        XCTAssertTrue(sut.completedGoals.isEmpty)
    }

    func test_activeGoals_withNoGoals_returnsEmpty() {
        XCTAssertTrue(sut.activeGoals.isEmpty)
    }

    // MARK: - Create Goal

    @MainActor
    func test_createGoal_addsToList() {
        // When
        sut.createGoal(
            name: "Emergency Fund",
            targetAmount: 10000,
            deadline: nil,
            priority: .high,
            icon: "banknote",
            notes: "For emergencies",
            modelContext: modelContext
        )

        // Then
        sut.loadGoals(modelContext: modelContext)
        XCTAssertEqual(sut.goals.count, 1)
        XCTAssertEqual(sut.goals.first?.name, "Emergency Fund")
        XCTAssertEqual(sut.goals.first?.targetAmount, 10000)
        XCTAssertEqual(sut.goals.first?.priority, .high)
    }

    @MainActor
    func test_createMultipleGoals_allPersist() {
        // When
        sut.createGoal(name: "Goal 1", targetAmount: 1000, deadline: nil, priority: .low, icon: "star", notes: nil, modelContext: modelContext)
        sut.createGoal(name: "Goal 2", targetAmount: 2000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.createGoal(name: "Goal 3", targetAmount: 3000, deadline: nil, priority: .high, icon: "star", notes: nil, modelContext: modelContext)

        // Then
        sut.loadGoals(modelContext: modelContext)
        XCTAssertEqual(sut.goals.count, 3)
    }

    // MARK: - Add Contribution

    @MainActor
    func test_addContribution_increasesCurrentAmount() {
        // Given
        sut.createGoal(name: "Test", targetAmount: 1000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.loadGoals(modelContext: modelContext)
        guard let goal = sut.goals.first else {
            XCTFail("No goal found")
            return
        }

        // When
        sut.addContribution(goal: goal, amount: 250, modelContext: modelContext)

        // Then
        XCTAssertEqual(goal.currentAmount, 250)
    }

    @MainActor
    func test_addMultipleContributions_accumulates() {
        // Given
        sut.createGoal(name: "Test", targetAmount: 1000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.loadGoals(modelContext: modelContext)
        guard let goal = sut.goals.first else {
            XCTFail("No goal found")
            return
        }

        // When
        sut.addContribution(goal: goal, amount: 100, modelContext: modelContext)
        sut.addContribution(goal: goal, amount: 200, modelContext: modelContext)
        sut.addContribution(goal: goal, amount: 300, modelContext: modelContext)

        // Then
        XCTAssertEqual(goal.currentAmount, 600)
    }

    // MARK: - Delete Goal

    @MainActor
    func test_deleteGoal_removesFromList() {
        // Given
        sut.createGoal(name: "To Delete", targetAmount: 500, deadline: nil, priority: .low, icon: "star", notes: nil, modelContext: modelContext)
        sut.loadGoals(modelContext: modelContext)
        XCTAssertEqual(sut.goals.count, 1)

        guard let goal = sut.goals.first else {
            XCTFail("No goal found")
            return
        }

        // When
        sut.deleteGoal(goal: goal, modelContext: modelContext)

        // Then
        sut.loadGoals(modelContext: modelContext)
        XCTAssertEqual(sut.goals.count, 0)
    }

    // MARK: - Totals

    @MainActor
    func test_totalSaved_sumsAllGoals() {
        // Given
        sut.createGoal(name: "G1", targetAmount: 1000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.createGoal(name: "G2", targetAmount: 2000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.loadGoals(modelContext: modelContext)

        // When
        if let g1 = sut.goals.first(where: { $0.name == "G1" }) {
            sut.addContribution(goal: g1, amount: 500, modelContext: modelContext)
        }
        if let g2 = sut.goals.first(where: { $0.name == "G2" }) {
            sut.addContribution(goal: g2, amount: 750, modelContext: modelContext)
        }

        // Then
        XCTAssertEqual(sut.totalSaved, 1250)
    }

    @MainActor
    func test_totalTarget_sumsAllGoals() {
        // Given
        sut.createGoal(name: "G1", targetAmount: 1000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.createGoal(name: "G2", targetAmount: 2000, deadline: nil, priority: .medium, icon: "star", notes: nil, modelContext: modelContext)
        sut.loadGoals(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.totalTarget, 3000)
    }
}
