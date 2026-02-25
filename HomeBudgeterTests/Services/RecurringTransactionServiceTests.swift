//
//  RecurringTransactionServiceTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class RecurringTransactionServiceTests: XCTestCase {

    var sut: RecurringTransactionService!
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

        sut = RecurringTransactionService.shared
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Next Due Date Calculation

    @MainActor
    func test_calculateNextDueDate_daily_addsOneDay() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .daily)
        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    @MainActor
    func test_calculateNextDueDate_weekly_addsOneWeek() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .weekly)
        let expectedDate = Calendar.current.date(byAdding: .day, value: 7, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    @MainActor
    func test_calculateNextDueDate_biweekly_addsTwoWeeks() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .biweekly)
        let expectedDate = Calendar.current.date(byAdding: .day, value: 14, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    @MainActor
    func test_calculateNextDueDate_monthly_addsOneMonth() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .monthly)
        let expectedDate = Calendar.current.date(byAdding: .month, value: 1, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    @MainActor
    func test_calculateNextDueDate_quarterly_addsThreeMonths() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .quarterly)
        let expectedDate = Calendar.current.date(byAdding: .month, value: 3, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    @MainActor
    func test_calculateNextDueDate_yearly_addsOneYear() {
        let today = Date()
        let next = sut.calculateNextDueDate(from: today, frequency: .yearly)
        let expectedDate = Calendar.current.date(byAdding: .year, value: 1, to: today)!
        XCTAssertNotNil(next)
        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month, .day], from: next!),
            Calendar.current.dateComponents([.year, .month, .day], from: expectedDate)
        )
    }

    // MARK: - Generate Due Transactions

    @MainActor
    func test_generateDueTransactions_createsTransaction() {
        // Given
        let template = RecurringTemplate(
            name: "Netflix",
            amount: 17.99,
            type: .expense,
            frequency: .monthly,
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )
        template.nextDueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        template.isActive = true
        modelContext.insert(template)
        try? modelContext.save()

        // When
        sut.generateDueTransactions(modelContext: modelContext)

        // Then
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try? modelContext.fetch(descriptor)
        XCTAssertEqual(transactions?.count, 1)
        XCTAssertEqual(transactions?.first?.descriptionText, "Netflix")
        XCTAssertEqual(transactions?.first?.amount, Decimal(string: "17.99"))
    }

    @MainActor
    func test_generateDueTransactions_advancesNextDueDate() {
        // Given
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let template = RecurringTemplate(
            name: "Test",
            amount: 50,
            type: .expense,
            frequency: .monthly,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        )
        template.nextDueDate = pastDate
        template.isActive = true
        modelContext.insert(template)
        try? modelContext.save()

        // When
        sut.generateDueTransactions(modelContext: modelContext)

        // Then
        XCTAssertGreaterThan(template.nextDueDate, pastDate)
    }

    @MainActor
    func test_generateDueTransactions_skipsInactiveTemplates() {
        // Given
        let template = RecurringTemplate(
            name: "Paused",
            amount: 100,
            type: .expense,
            frequency: .monthly,
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        )
        template.nextDueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        template.isActive = false
        modelContext.insert(template)
        try? modelContext.save()

        // When
        sut.generateDueTransactions(modelContext: modelContext)

        // Then
        let descriptor = FetchDescriptor<Transaction>()
        let transactions = try? modelContext.fetch(descriptor)
        XCTAssertEqual(transactions?.count ?? 0, 0)
    }

    // MARK: - Overdue Templates

    @MainActor
    func test_getOverdueTemplates_returnsOverdueOnly() {
        // Given
        let overdueTemplate = RecurringTemplate(
            name: "Overdue",
            amount: 50,
            type: .expense,
            frequency: .monthly,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        )
        overdueTemplate.nextDueDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        overdueTemplate.isActive = true

        let futureTemplate = RecurringTemplate(
            name: "Future",
            amount: 100,
            type: .expense,
            frequency: .monthly
        )
        futureTemplate.nextDueDate = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        futureTemplate.isActive = true

        modelContext.insert(overdueTemplate)
        modelContext.insert(futureTemplate)
        try? modelContext.save()

        // When
        let overdue = sut.getOverdueTemplates(modelContext: modelContext)

        // Then
        XCTAssertEqual(overdue.count, 1)
        XCTAssertEqual(overdue.first?.name, "Overdue")
    }
}
