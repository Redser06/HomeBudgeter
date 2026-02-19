//
//  RecurringViewModelDetectionTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class RecurringViewModelDetectionTests: XCTestCase {

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
            BillLineItem.self,
            HouseholdMember.self,
            Investment.self,
            InvestmentTransaction.self
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
        billType: BillType = .electric
    ) -> Transaction {
        let transaction = Transaction(
            amount: amount,
            date: date,
            descriptionText: vendor,
            type: .expense,
            notes: "[\(billType.rawValue)]"
        )
        modelContext.insert(transaction)
        try? modelContext.save()
        return transaction
    }

    @MainActor
    private func makeDetectionResult(
        vendor: String = "Electric Ireland",
        transactions: [Transaction],
        frequency: RecurringFrequency = .monthly,
        suggestedAmount: Decimal = Decimal(string: "120.00")!,
        averageAmount: Decimal = Decimal(string: "110.00")!,
        isVariableAmount: Bool = true,
        billTypes: [BillType] = [.electric],
        suggestedNotes: String? = "[Electric]",
        hasBillTags: Bool = true
    ) -> RecurringBillDetector.DetectionResult {
        RecurringBillDetector.DetectionResult(
            vendor: vendor,
            matchingTransactions: transactions,
            suggestedFrequency: frequency,
            suggestedAmount: suggestedAmount,
            averageAmount: averageAmount,
            isVariableAmount: isVariableAmount,
            billTypes: billTypes,
            suggestedNotes: suggestedNotes,
            hasBillTags: hasBillTags
        )
    }

    // MARK: - Creates template from detection result

    @MainActor
    func test_createTemplateFromDetection_createsTemplate() {
        let t1 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        let t2 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = makeDetectionResult(transactions: [t1, t2])

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "120.00")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        XCTAssertEqual(sut.templates.count, 1)
        XCTAssertEqual(sut.templates.first?.name, "Electric Ireland")
        XCTAssertEqual(sut.templates.first?.amount, Decimal(string: "120.00")!)
        XCTAssertEqual(sut.templates.first?.frequency, .monthly)
    }

    // MARK: - Links existing transactions retroactively

    @MainActor
    func test_createTemplateFromDetection_linksTransactions() {
        let t1 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        let t2 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = makeDetectionResult(transactions: [t1, t2])

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "120.00")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        let template = sut.templates.first!

        XCTAssertEqual(template.generatedTransactions.count, 2)
        XCTAssertNotNil(t1.parentTemplate)
        XCTAssertNotNil(t2.parentTemplate)
        XCTAssertEqual(t1.parentTemplate?.id, template.id)
        XCTAssertEqual(t2.parentTemplate?.id, template.id)
    }

    // MARK: - Sets nextDueDate correctly

    @MainActor
    func test_createTemplateFromDetection_setsNextDueDate() {
        let t1 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        let t2 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "120.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = makeDetectionResult(transactions: [t1, t2])

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "120.00")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        let template = sut.templates.first!

        // nextDueDate should be one month after last bill (Feb 15 + 1 month = Mar 15)
        let expectedDate = makeDate(year: 2026, month: 3, day: 15)
        let calendar = Calendar.current
        XCTAssertEqual(
            calendar.startOfDay(for: template.nextDueDate),
            calendar.startOfDay(for: expectedDate)
        )
    }

    // MARK: - Sets isVariableAmount flag

    @MainActor
    func test_createTemplateFromDetection_setsIsVariableAmount() {
        let t1 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15)
        )
        let t2 = insertBillTransaction(
            vendor: "Electric Ireland",
            amount: Decimal(string: "150.00")!,
            date: makeDate(year: 2026, month: 2, day: 15)
        )

        let result = makeDetectionResult(transactions: [t1, t2], isVariableAmount: true)

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "150.00")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        XCTAssertTrue(sut.templates.first!.isVariableAmount)
    }

    // MARK: - Preserves bill type tags in notes

    @MainActor
    func test_createTemplateFromDetection_preservesBillTypeTags() {
        let t1 = insertBillTransaction(
            vendor: "Bord Gais",
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: 2026, month: 1, day: 15),
            billType: .gas
        )
        let t2 = insertBillTransaction(
            vendor: "Bord Gais",
            amount: Decimal(string: "110.00")!,
            date: makeDate(year: 2026, month: 2, day: 15),
            billType: .gas
        )

        let result = makeDetectionResult(
            vendor: "Bord Gais",
            transactions: [t1, t2],
            billTypes: [.gas, .electric],
            suggestedNotes: "[Gas][Electric]"
        )

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "110.00")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        let template = sut.templates.first!
        XCTAssertTrue(template.notes?.contains("[Gas]") ?? false)
        XCTAssertTrue(template.notes?.contains("[Electric]") ?? false)
    }

    // MARK: - Fixed amount template

    @MainActor
    func test_createTemplateFromDetection_fixedAmount() {
        let t1 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1)
        )
        let t2 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1)
        )

        let result = makeDetectionResult(
            vendor: "Netflix",
            transactions: [t1, t2],
            suggestedAmount: Decimal(string: "17.99")!,
            averageAmount: Decimal(string: "17.99")!,
            isVariableAmount: false,
            billTypes: [.streaming],
            suggestedNotes: "[Streaming]"
        )

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "17.99")!,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        let template = sut.templates.first!
        XCTAssertFalse(template.isVariableAmount)
        XCTAssertEqual(template.amount, Decimal(string: "17.99")!)
    }

    // MARK: - Sets isAutoPay flag on template

    @MainActor
    func test_createTemplateFromDetection_setsIsAutoPay() {
        let t1 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 1, day: 1)
        )
        let t2 = insertBillTransaction(
            vendor: "Netflix",
            amount: Decimal(string: "17.99")!,
            date: makeDate(year: 2026, month: 2, day: 1)
        )

        let result = makeDetectionResult(
            vendor: "Netflix",
            transactions: [t1, t2],
            suggestedAmount: Decimal(string: "17.99")!,
            averageAmount: Decimal(string: "17.99")!,
            isVariableAmount: false,
            billTypes: [],
            suggestedNotes: nil,
            hasBillTags: false
        )

        sut.createTemplateFromDetection(
            result,
            frequency: .monthly,
            amount: Decimal(string: "17.99")!,
            isAutoPay: true,
            modelContext: modelContext
        )

        sut.loadTemplates(modelContext: modelContext)
        let template = sut.templates.first!
        XCTAssertTrue(template.isAutoPay)
    }
}
