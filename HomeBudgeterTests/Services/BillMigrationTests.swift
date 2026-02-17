//
//  BillMigrationTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class BillMigrationTests: XCTestCase {

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

        // Reset migration flag for each test
        UserDefaults.standard.removeObject(forKey: "billSegmentationMigrationV1")
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        UserDefaults.standard.removeObject(forKey: "billSegmentationMigrationV1")
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    // MARK: - Tag Rewriting

    @MainActor
    func test_migrate_rewritesGasElectricTag() {
        // Given
        let transaction = Transaction(
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            descriptionText: "Electric Ireland",
            type: .expense,
            notes: "[Gas & Electric] January bill"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then
        XCTAssertTrue(transaction.notes?.contains("[Gas]") ?? false)
        XCTAssertTrue(transaction.notes?.contains("[Electric]") ?? false)
        XCTAssertFalse(transaction.notes?.contains("[Gas & Electric]") ?? true)
        XCTAssertTrue(transaction.notes?.contains("January bill") ?? false)
    }

    @MainActor
    func test_migrate_rewritesInternetTvTag() {
        // Given
        let transaction = Transaction(
            amount: Decimal(string: "65.00")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            descriptionText: "Virgin Media",
            type: .expense,
            notes: "[Internet & TV] Feb bill"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then
        XCTAssertTrue(transaction.notes?.contains("[Internet]") ?? false)
        XCTAssertTrue(transaction.notes?.contains("[TV]") ?? false)
        XCTAssertFalse(transaction.notes?.contains("[Internet & TV]") ?? true)
    }

    @MainActor
    func test_migrate_rewritesPhoneTag() {
        // Given
        let transaction = Transaction(
            amount: Decimal(string: "40.00")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            descriptionText: "Vodafone",
            type: .expense,
            notes: "[Phone] Monthly"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then
        XCTAssertTrue(transaction.notes?.contains("[Mobile]") ?? false)
        XCTAssertFalse(transaction.notes?.contains("[Phone]") ?? true)
    }

    // MARK: - Line Item Creation

    @MainActor
    func test_migrate_createsLineItems_forLegacyBill() {
        // Given
        let transaction = Transaction(
            amount: Decimal(string: "200.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            descriptionText: "Bord Gáis Energy",
            type: .expense,
            notes: "[Gas & Electric] Bi-monthly"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then — line items should be created
        let items = transaction.billLineItems ?? []
        XCTAssertFalse(items.isEmpty)
        // Bord Gáis should infer to gas via vendor keywords
        let types = Set(items.map(\.billType))
        XCTAssertTrue(types.contains(.gas))
    }

    @MainActor
    func test_migrate_splitsAmountEqually_forBundledBill() {
        // Given — a generic vendor that doesn't infer to specific types
        let transaction = Transaction(
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            descriptionText: "Some Energy Co",
            type: .expense,
            notes: "[Gas & Electric]"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then — amount should be split across the mapped types
        let items = transaction.billLineItems ?? []
        XCTAssertEqual(items.count, 2)
        let totalFromItems = items.reduce(Decimal.zero) { $0 + $1.amount }
        XCTAssertEqual(totalFromItems, Decimal(string: "100.00")!)
    }

    // MARK: - Non-Legacy Bills

    @MainActor
    func test_migrate_doesNotModifyNewTags() {
        // Given — a bill with new-style tags
        let transaction = Transaction(
            amount: Decimal(string: "80.00")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            descriptionText: "ESB",
            type: .expense,
            notes: "[Electric] January"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then — notes should be unchanged
        XCTAssertEqual(transaction.notes, "[Electric] January")
        // But a line item should be created
        XCTAssertEqual(transaction.billLineItems?.count, 1)
        XCTAssertEqual(transaction.billLineItems?.first?.billType, .electric)
    }

    // MARK: - Idempotency

    @MainActor
    func test_migrateIfNeeded_isIdempotent() {
        // Given
        let transaction = Transaction(
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            descriptionText: "Electric Ireland",
            type: .expense,
            notes: "[Gas & Electric] January"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When — run migration twice
        BillMigrationService.shared.migrateIfNeeded(modelContext: modelContext)
        BillMigrationService.shared.migrateIfNeeded(modelContext: modelContext)

        // Then — flag is set, second run is a no-op
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "billSegmentationMigrationV1"))
        // Notes should only be rewritten once
        XCTAssertFalse(transaction.notes?.contains("[Gas & Electric]") ?? true)
        XCTAssertTrue(transaction.notes?.contains("[Gas]") ?? false)
        XCTAssertTrue(transaction.notes?.contains("[Electric]") ?? false)
    }

    @MainActor
    func test_migrateIfNeeded_setsFlag() {
        // Given
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "billSegmentationMigrationV1"))

        // When
        BillMigrationService.shared.migrateIfNeeded(modelContext: modelContext)

        // Then
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "billSegmentationMigrationV1"))
    }

    // MARK: - Non-Bill Transactions Unaffected

    @MainActor
    func test_migrate_ignoresNonBillTransactions() {
        // Given — a regular transaction with notes but no bill tags
        let transaction = Transaction(
            amount: Decimal(string: "50.00")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            descriptionText: "Grocery Store",
            type: .expense,
            notes: "Weekly groceries"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        BillMigrationService.shared.migrate(modelContext: modelContext)

        // Then — transaction is unchanged, no line items created
        XCTAssertEqual(transaction.notes, "Weekly groceries")
        XCTAssertTrue((transaction.billLineItems ?? []).isEmpty)
    }
}
