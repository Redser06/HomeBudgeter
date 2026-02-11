//
//  RecurringTemplateTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class RecurringTemplateTests: XCTestCase {

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
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Creation Tests

    func test_createRecurringTemplate_withValidData_succeeds() {
        // Given
        let name = "Netflix"
        let amount: Decimal = 17.99

        // When
        let template = RecurringTemplate(
            name: name,
            amount: amount,
            type: .expense,
            frequency: .monthly
        )

        // Then
        XCTAssertNotNil(template.id)
        XCTAssertEqual(template.name, name)
        XCTAssertEqual(template.amount, amount)
        XCTAssertEqual(template.type, .expense)
        XCTAssertEqual(template.frequency, .monthly)
        XCTAssertTrue(template.isActive)
        XCTAssertTrue(template.generatedTransactions.isEmpty)
    }

    func test_createRecurringTemplate_asIncome_setsTypeCorrectly() {
        // Given/When
        let template = RecurringTemplate(
            name: "Salary",
            amount: 5000,
            type: .income,
            frequency: .monthly
        )

        // Then
        XCTAssertEqual(template.type, .income)
    }

    // MARK: - Frequency Tests

    func test_allFrequencies_areValid() {
        let frequencies: [RecurringFrequency] = [.daily, .weekly, .biweekly, .monthly, .quarterly, .yearly]

        for frequency in frequencies {
            let template = RecurringTemplate(
                name: "Test",
                amount: 100,
                type: .expense,
                frequency: frequency
            )
            XCTAssertEqual(template.frequency, frequency)
        }
    }

    // MARK: - Active/Inactive Tests

    func test_newTemplate_isActiveByDefault() {
        // Given/When
        let template = RecurringTemplate(
            name: "Test",
            amount: 100,
            type: .expense,
            frequency: .monthly
        )

        // Then
        XCTAssertTrue(template.isActive)
    }

    func test_deactivateTemplate_setsInactive() {
        // Given
        let template = RecurringTemplate(
            name: "Test",
            amount: 100,
            type: .expense,
            frequency: .monthly
        )

        // When
        template.isActive = false

        // Then
        XCTAssertFalse(template.isActive)
    }

    // MARK: - Due Date Tests

    func test_isOverdue_whenNextDueDateInPast_returnsTrue() {
        // Given
        let template = RecurringTemplate(
            name: "Overdue Bill",
            amount: 50,
            type: .expense,
            frequency: .monthly,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        )
        template.nextDueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        // Then
        XCTAssertTrue(template.isOverdue)
    }

    func test_isOverdue_whenNextDueDateInFuture_returnsFalse() {
        // Given
        let template = RecurringTemplate(
            name: "Future Bill",
            amount: 50,
            type: .expense,
            frequency: .monthly
        )
        template.nextDueDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

        // Then
        XCTAssertFalse(template.isOverdue)
    }

    // MARK: - Formatted Amount Tests

    func test_formattedAmount_containsCurrencySymbol() {
        // Given
        let template = RecurringTemplate(
            name: "Test",
            amount: 99.99,
            type: .expense,
            frequency: .monthly
        )

        // When
        let formatted = template.formattedAmount

        // Then
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("99.99") || formatted.contains("99,99"))
    }

    // MARK: - Edge Cases

    func test_template_withZeroAmount_isValid() {
        // Given/When
        let template = RecurringTemplate(
            name: "Free Subscription",
            amount: 0,
            type: .expense,
            frequency: .monthly
        )

        // Then
        XCTAssertEqual(template.amount, 0)
    }

    func test_template_withLargeAmount_handlesCorrectly() {
        // Given
        let largeAmount: Decimal = 999_999.99

        // When
        let template = RecurringTemplate(
            name: "Mortgage",
            amount: largeAmount,
            type: .expense,
            frequency: .monthly
        )

        // Then
        XCTAssertEqual(template.amount, largeAmount)
    }

    // MARK: - Persistence Tests

    @MainActor
    func test_persistTemplate_andFetch_succeeds() {
        // Given
        let template = RecurringTemplate(
            name: "Rent",
            amount: 1500,
            type: .expense,
            frequency: .monthly
        )

        // When
        modelContext.insert(template)
        try? modelContext.save()

        let descriptor = FetchDescriptor<RecurringTemplate>()
        let fetched = try? modelContext.fetch(descriptor)

        // Then
        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.name, "Rent")
        XCTAssertEqual(fetched?.first?.amount, 1500)
    }
}
