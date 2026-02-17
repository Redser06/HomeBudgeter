//
//  RecurringViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class RecurringViewModelTests: XCTestCase {

    var sut: RecurringViewModel!
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
            BillLineItem.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }

        sut = RecurringViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_hasEmptyTemplates() {
        XCTAssertTrue(sut.templates.isEmpty)
        XCTAssertFalse(sut.showingCreateSheet)
        XCTAssertNil(sut.selectedTemplate)
    }

    // MARK: - Computed Properties

    func test_monthlyCost_withNoTemplates_returnsZero() {
        XCTAssertEqual(sut.monthlyCost, 0)
    }

    func test_activeTemplates_withNoTemplates_returnsEmpty() {
        XCTAssertTrue(sut.activeTemplates.isEmpty)
    }

    func test_pausedTemplates_withNoTemplates_returnsEmpty() {
        XCTAssertTrue(sut.pausedTemplates.isEmpty)
    }

    func test_overdueTemplates_withNoTemplates_returnsEmpty() {
        XCTAssertTrue(sut.overdueTemplates.isEmpty)
    }

    // MARK: - Create Template

    @MainActor
    func test_createTemplate_addsToList() {
        // When
        sut.createTemplate(
            name: "Netflix",
            amount: 17.99,
            type: .expense,
            frequency: .monthly,
            startDate: Date(),
            endDate: nil,
            notes: nil,
            category: nil,
            account: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadTemplates(modelContext: modelContext)
        XCTAssertEqual(sut.templates.count, 1)
        XCTAssertEqual(sut.templates.first?.name, "Netflix")
        XCTAssertEqual(sut.templates.first?.amount, Decimal(string: "17.99"))
    }

    @MainActor
    func test_createMultipleTemplates_allPersist() {
        // When
        sut.createTemplate(name: "Netflix", amount: 17.99, type: .expense, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.createTemplate(name: "Salary", amount: 5000, type: .income, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.createTemplate(name: "Gym", amount: 40, type: .expense, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)

        // Then
        sut.loadTemplates(modelContext: modelContext)
        XCTAssertEqual(sut.templates.count, 3)
    }

    // MARK: - Delete Template

    @MainActor
    func test_deleteTemplate_removesFromList() {
        // Given
        sut.createTemplate(name: "To Delete", amount: 50, type: .expense, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.loadTemplates(modelContext: modelContext)
        XCTAssertEqual(sut.templates.count, 1)

        guard let template = sut.templates.first else {
            XCTFail("No template found")
            return
        }

        // When
        sut.deleteTemplate(template, modelContext: modelContext)

        // Then
        sut.loadTemplates(modelContext: modelContext)
        XCTAssertEqual(sut.templates.count, 0)
    }

    // MARK: - Pause / Resume

    @MainActor
    func test_pauseTemplate_setsInactive() {
        // Given
        sut.createTemplate(name: "Test", amount: 50, type: .expense, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.loadTemplates(modelContext: modelContext)
        guard let template = sut.templates.first else {
            XCTFail("No template found")
            return
        }
        XCTAssertTrue(template.isActive)

        // When
        sut.pauseTemplate(template, modelContext: modelContext)

        // Then
        XCTAssertFalse(template.isActive)
    }

    @MainActor
    func test_resumeTemplate_setsActive() {
        // Given
        sut.createTemplate(name: "Test", amount: 50, type: .expense, frequency: .monthly, startDate: Date(), endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.loadTemplates(modelContext: modelContext)
        guard let template = sut.templates.first else {
            XCTFail("No template found")
            return
        }
        template.isActive = false

        // When
        sut.resumeTemplate(template, modelContext: modelContext)

        // Then
        XCTAssertTrue(template.isActive)
    }

    // MARK: - Active / Paused Filtering

    @MainActor
    func test_activeTemplates_filtersCorrectly() {
        // Given — use future start dates so templates aren't considered overdue
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        sut.createTemplate(name: "Active", amount: 50, type: .expense, frequency: .monthly, startDate: futureDate, endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.createTemplate(name: "Paused", amount: 100, type: .expense, frequency: .monthly, startDate: futureDate, endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.loadTemplates(modelContext: modelContext)

        if let paused = sut.templates.first(where: { $0.name == "Paused" }) {
            sut.pauseTemplate(paused, modelContext: modelContext)
        }

        // Then
        XCTAssertEqual(sut.activeTemplates.count, 1)
        XCTAssertEqual(sut.activeTemplates.first?.name, "Active")
    }

    @MainActor
    func test_pausedTemplates_filtersCorrectly() {
        // Given
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        sut.createTemplate(name: "Active", amount: 50, type: .expense, frequency: .monthly, startDate: futureDate, endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.createTemplate(name: "Paused", amount: 100, type: .expense, frequency: .monthly, startDate: futureDate, endDate: nil, notes: nil, category: nil, account: nil, modelContext: modelContext)
        sut.loadTemplates(modelContext: modelContext)

        if let paused = sut.templates.first(where: { $0.name == "Paused" }) {
            sut.pauseTemplate(paused, modelContext: modelContext)
        }

        // Then
        XCTAssertEqual(sut.pausedTemplates.count, 1)
        XCTAssertEqual(sut.pausedTemplates.first?.name, "Paused")
    }
}
