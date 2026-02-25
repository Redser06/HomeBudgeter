//
//  RecurringBillDetectorTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class RecurringBillDetectorTests: XCTestCase {

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

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    @MainActor
    private func insertBillTransaction(
        vendor: String,
        amount: Decimal,
        date: Date,
        billType: BillType = .electric,
        notes: String? = nil
    ) -> Transaction {
        let billNotes = notes ?? "[\(billType.rawValue)]"
        let transaction = Transaction(
            amount: amount,
            date: date,
            descriptionText: vendor,
            type: .expense,
            notes: billNotes
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        return transaction
    }

    // MARK: - Returns nil with <2 bills

    @MainActor
    func test_detectRecurringPattern_returnsNilWithLessThanTwoBills() {
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNil(result)
    }

    // MARK: - Returns suggestion with 2+ bills

    @MainActor
    func test_detectRecurringPattern_returnsSuggestionWithTwoBills() {
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "105.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.vendor, "Electric Ireland")
        XCTAssertEqual(result?.matchingTransactions.count, 2)
    }

    // MARK: - Infers monthly frequency

    @MainActor
    func test_detectRecurringPattern_infersMonthlyFrequency() {
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .streaming
        )
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            billType: .streaming
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Netflix",
            modelContext: modelContext
        )

        XCTAssertEqual(result?.suggestedFrequency, .monthly)
    }

    // MARK: - Infers quarterly frequency

    @MainActor
    func test_detectRecurringPattern_infersQuarterlyFrequency() {
        _ = insertBillTransaction(
            vendor: "Insurance Co",
            amount: Decimal(string: "300.00")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .homeInsurance
        )
        _ = insertBillTransaction(
            vendor: "Insurance Co",
            amount: Decimal(string: "300.00")!,
            date: makeDate(year: 2026, month: 4, day: 1),
            billType: .homeInsurance
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Insurance Co",
            modelContext: modelContext
        )

        XCTAssertEqual(result?.suggestedFrequency, .quarterly)
    }

    // MARK: - Infers weekly frequency

    @MainActor
    func test_detectRecurringPattern_infersWeeklyFrequency() {
        _ = insertBillTransaction(
            vendor: "Cleaner",
            amount: Decimal(string: "50.00")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .other
        )
        _ = insertBillTransaction(
            vendor: "Cleaner",
            amount: Decimal(string: "50.00")!,
            date: makeDate(year: 2026, month: 1, day: 8),
            billType: .other
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Cleaner",
            modelContext: modelContext
        )

        XCTAssertEqual(result?.suggestedFrequency, .weekly)
    }

    // MARK: - Detects variable amounts

    @MainActor
    func test_detectRecurringPattern_detectsVariableAmounts() {
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "150.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isVariableAmount)
    }

    // MARK: - Detects fixed amounts

    @MainActor
    func test_detectRecurringPattern_detectsFixedAmounts() {
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .streaming
        )
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            billType: .streaming
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Netflix",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.isVariableAmount)
    }

    // MARK: - Returns nil when template already exists

    @MainActor
    func test_detectRecurringPattern_returnsNilWhenTemplateExists() {
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .streaming
        )
        _ = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            billType: .streaming
        )

        // Create an active template for Netflix
        let template = RecurringTemplate(
            name: "Netflix",
            amount: Decimal(string: "17.99")!,
            frequency: .monthly
        )
        modelContext.insert(template)
        try? modelContext.save()

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Netflix",
            modelContext: modelContext
        )

        XCTAssertNil(result)
    }

    // MARK: - Returns nil when transactions already linked

    @MainActor
    func test_detectRecurringPattern_returnsNilWhenTransactionsLinked() {
        let template = RecurringTemplate(
            name: "Netflix",
            amount: Decimal(string: "17.99")!,
            frequency: .monthly
        )
        modelContext.insert(template)

        let t1 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            billType: .streaming
        )
        t1.parentTemplate = template

        let t2 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            billType: .streaming
        )
        t2.parentTemplate = template
        try? modelContext.save()

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Netflix",
            modelContext: modelContext
        )

        // Template exists and is active, so returns nil
        XCTAssertNil(result)
    }

    // MARK: - Uses latest amount as suggested, computes average

    @MainActor
    func test_detectRecurringPattern_usesLatestAmountAsSuggested() {
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "140.00")!,
            date: makeDate(year: 2026, month: 3, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.suggestedAmount, Decimal(string: "140.00")!)
        XCTAssertEqual(result!.averageAmount, Decimal(string: "120.00")!)
    }

    // MARK: - Extracts bill types from notes

    @MainActor
    func test_detectRecurringPattern_extractsBillTypes() {
        _ = insertBillTransaction(
            vendor: "Bord Gais",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            notes: "[Gas][Electric]"
        )
        _ = insertBillTransaction(
            vendor: "Bord Gais",
            amount: Decimal(string: "110.00")!,
            date: makeDate(year: 2026, month: 2, day: 15),
            notes: "[Gas][Electric]"
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Bord Gais",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.billTypes.contains(.gas))
        XCTAssertTrue(result!.billTypes.contains(.electric))
    }

    // MARK: - Detects non-bill-tagged transactions

    @MainActor
    func test_detectRecurringPattern_detectsNonBillTaggedTransactions() {
        // Insert transactions without bill tags (regular subscriptions)
        let t1 = Transaction(
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1),
            descriptionText: "Netflix",
            type: .expense,
            notes: nil
        )
        modelContext.insert(t1)
        let t2 = Transaction(
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1),
            descriptionText: "Netflix",
            type: .expense,
            notes: nil
        )
        modelContext.insert(t2)
        try? modelContext.save()

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Netflix",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchingTransactions.count, 2)
        XCTAssertFalse(result!.hasBillTags)
        XCTAssertTrue(result!.billTypes.isEmpty)
    }

    // MARK: - hasBillTags is true when tags present

    @MainActor
    func test_detectRecurringPattern_hasBillTagsTrueWhenTagsPresent() {
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "105.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasBillTags)
    }

    // MARK: - Case-insensitive vendor matching

    @MainActor
    func test_detectRecurringPattern_caseInsensitiveVendorMatching() {
        _ = insertBillTransaction(
            vendor: "electric ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        _ = insertBillTransaction(
            vendor: "electric ireland",
            amount: Decimal(string: "105.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = RecurringBillDetector.shared.detectRecurringPattern(
            for: "Electric Ireland",
            modelContext: modelContext
        )

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchingTransactions.count, 2)
    }
}
