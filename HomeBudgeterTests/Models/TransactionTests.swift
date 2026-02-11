//
//  TransactionTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class TransactionTests: XCTestCase {

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

    func test_createTransaction_withValidData_succeeds() {
        // Given
        let amount: Decimal = 100.50
        let description = "Test Transaction"

        // When
        let transaction = Transaction(
            amount: amount,
            descriptionText: description,
            type: .expense
        )

        // Then
        XCTAssertNotNil(transaction.id)
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.descriptionText, description)
        XCTAssertEqual(transaction.type, .expense)
        XCTAssertFalse(transaction.isRecurring)
        XCTAssertNil(transaction.notes)
        XCTAssertNil(transaction.category)
    }

    func test_createTransaction_asIncome_setsTypeCorrectly() {
        // Given/When
        let transaction = Transaction(
            amount: 5000,
            descriptionText: "Salary",
            type: .income
        )

        // Then
        XCTAssertEqual(transaction.type, .income)
    }

    func test_createTransaction_withRecurring_setsFrequency() {
        // Given/When
        let transaction = Transaction(
            amount: 50,
            descriptionText: "Netflix",
            type: .expense,
            isRecurring: true,
            recurringFrequency: .monthly
        )

        // Then
        XCTAssertTrue(transaction.isRecurring)
        XCTAssertEqual(transaction.recurringFrequency, .monthly)
    }

    // MARK: - Formatting Tests

    func test_formattedAmount_returnsEuroFormat() {
        // Given
        let transaction = Transaction(
            amount: 1234.56,
            descriptionText: "Test"
        )

        // When
        let formatted = transaction.formattedAmount

        // Then
        XCTAssertTrue(formatted.contains("1,234.56") || formatted.contains("1.234,56"))
        XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"))
    }

    func test_formattedDate_returnsReadableFormat() {
        // Given
        let transaction = Transaction(
            amount: 100,
            date: Date(),
            descriptionText: "Test"
        )

        // When
        let formatted = transaction.formattedDate

        // Then
        XCTAssertFalse(formatted.isEmpty)
    }

    // MARK: - Timestamp Tests

    func test_newTransaction_setsCreatedAt() {
        // Given
        let beforeCreation = Date()

        // When
        let transaction = Transaction(
            amount: 100,
            descriptionText: "Test"
        )

        // Then
        XCTAssertGreaterThanOrEqual(transaction.createdAt, beforeCreation)
        // Allow small time difference (< 1 second) between createdAt and updatedAt
        let timeDiff = abs(transaction.createdAt.timeIntervalSince(transaction.updatedAt))
        XCTAssertLessThan(timeDiff, 1.0, "createdAt and updatedAt should be within 1 second")
    }

    // MARK: - Edge Cases

    func test_transaction_withZeroAmount_isValid() {
        // Given/When
        let transaction = Transaction(
            amount: 0,
            descriptionText: "Zero amount"
        )

        // Then
        XCTAssertEqual(transaction.amount, 0)
    }

    func test_transaction_withLargeAmount_handlesCorrectly() {
        // Given
        let largeAmount: Decimal = 999_999_999.99

        // When
        let transaction = Transaction(
            amount: largeAmount,
            descriptionText: "Large transaction"
        )

        // Then
        XCTAssertEqual(transaction.amount, largeAmount)
    }

    func test_transaction_withEmptyDescription_isValid() {
        // Note: Business logic may want to prevent this, but model allows it
        // Given/When
        let transaction = Transaction(
            amount: 100,
            descriptionText: ""
        )

        // Then
        XCTAssertEqual(transaction.descriptionText, "")
    }
}
