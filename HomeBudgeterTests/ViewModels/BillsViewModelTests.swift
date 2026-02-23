//
//  BillsViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class BillsViewModelTests: XCTestCase {

    var sut: BillsViewModel!
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

        sut = BillsViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    @MainActor
    private func createBillWithDocument(
        amount: Decimal = Decimal(string: "99.99")!,
        vendor: String = "Test Vendor",
        billType: BillType = .other,
        categoryType: CategoryType = .utilities,
        date: Date? = nil,
        isRecurring: Bool = false,
        recurringFrequency: RecurringFrequency? = nil,
        attachDocument: Bool = true,
        lineItems: [(billType: BillType, amount: Decimal, label: String?, provider: String?)] = []
    ) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let billDate = date ?? makeDate(year: currentYear, month: 6, day: 15)

        if attachDocument {
            let document = Document(
                filename: "test-bill.pdf",
                localPath: "/tmp/test-bill.pdf",
                documentType: .bill,
                fileSize: 1024,
                mimeType: "application/pdf"
            )
            modelContext.insert(document)
            try? modelContext.save()
            sut.importedDocument = document
        }

        sut.createBillTransaction(
            amount: amount,
            date: billDate,
            vendor: vendor,
            billType: billType,
            categoryType: categoryType,
            notes: nil,
            dueDate: nil,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            lineItems: lineItems,
            modelContext: modelContext
        )
    }

    // MARK: - Initial State

    func test_initialState_hasEmptyBills() {
        XCTAssertTrue(sut.bills.isEmpty)
        XCTAssertFalse(sut.showingCreateSheet)
        XCTAssertNil(sut.selectedBill)
    }

    func test_initialState_filterYearIsCurrentYear() {
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertEqual(sut.filterYear, currentYear)
    }

    // MARK: - Create Bill Transaction

    @MainActor
    func test_createBillTransaction_addsToList() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let billDate = makeDate(year: currentYear, month: 3, day: 10)

        // When
        sut.createBillTransaction(
            amount: Decimal(string: "150.00")!,
            date: billDate,
            vendor: "Electric Ireland",
            billType: .electric,
            categoryType: .utilities,
            notes: "March bill",
            dueDate: makeDate(year: currentYear, month: 3, day: 25),
            isRecurring: true,
            recurringFrequency: .monthly,
            modelContext: modelContext
        )

        // Then — loadBills finds bills by [BillType] tag in notes, even without a linked document
        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 1)

        let bill = sut.bills.first
        XCTAssertEqual(bill?.amount, Decimal(string: "150.00")!)
        XCTAssertEqual(bill?.descriptionText, "Electric Ireland")
        XCTAssertTrue(bill?.isRecurring ?? false)
        XCTAssertEqual(bill?.recurringFrequency, .monthly)
        XCTAssertTrue(bill?.notes?.contains("[Electric]") ?? false)
    }

    @MainActor
    func test_createBillTransaction_linksDocument() {
        // Given & When
        createBillWithDocument(vendor: "Virgin Media", billType: .internet)

        // Then
        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 1)

        let bill = sut.bills.first
        XCTAssertNotNil(bill?.linkedDocument)
        XCTAssertEqual(bill?.linkedDocument?.filename, "test-bill.pdf")
        XCTAssertEqual(bill?.linkedDocument?.documentType, .bill)

        // Verify bidirectional relationship
        XCTAssertEqual(bill?.linkedDocument?.linkedTransaction?.id, bill?.id)
    }

    @MainActor
    func test_createBillTransaction_withLineItems_createsMultiTagNotes() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let lineItems: [(billType: BillType, amount: Decimal, label: String?, provider: String?)] = [
            (billType: .gas, amount: Decimal(string: "100.00")!, label: "Gas Supply", provider: nil),
            (billType: .electric, amount: Decimal(string: "80.00")!, label: "Electricity", provider: nil),
        ]

        // When
        sut.createBillTransaction(
            amount: Decimal(string: "180.00")!,
            date: makeDate(year: currentYear, month: 3, day: 10),
            vendor: "Bord Gáis Energy",
            billType: .gas,
            categoryType: .utilities,
            notes: nil,
            dueDate: nil,
            isRecurring: true,
            recurringFrequency: .monthly,
            lineItems: lineItems,
            modelContext: modelContext
        )

        // Then
        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 1)

        let bill = sut.bills.first!
        XCTAssertTrue(bill.notes?.contains("[Gas]") ?? false)
        XCTAssertTrue(bill.notes?.contains("[Electric]") ?? false)

        // Verify BillLineItem records
        XCTAssertEqual(bill.billLineItems?.count, 2)
        let sortedItems = (bill.billLineItems ?? []).sorted { $0.amount > $1.amount }
        XCTAssertEqual(sortedItems[0].billType, .gas)
        XCTAssertEqual(sortedItems[0].amount, Decimal(string: "100.00")!)
        XCTAssertEqual(sortedItems[0].label, "Gas Supply")
        XCTAssertEqual(sortedItems[1].billType, .electric)
        XCTAssertEqual(sortedItems[1].amount, Decimal(string: "80.00")!)
    }

    @MainActor
    func test_createBillTransaction_withoutLineItems_createsSingleLineItem() {
        // When
        let currentYear = Calendar.current.component(.year, from: Date())
        sut.createBillTransaction(
            amount: Decimal(string: "50.00")!,
            date: makeDate(year: currentYear, month: 1, day: 1),
            vendor: "Netflix",
            billType: .streaming,
            categoryType: .entertainment,
            notes: nil,
            dueDate: nil,
            isRecurring: false,
            recurringFrequency: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadBills(modelContext: modelContext)
        let bill = sut.bills.first!
        XCTAssertEqual(bill.billLineItems?.count, 1)
        XCTAssertEqual(bill.billLineItems?.first?.billType, .streaming)
        XCTAssertEqual(bill.billLineItems?.first?.amount, Decimal(string: "50.00")!)
    }

    // MARK: - Delete Bill

    @MainActor
    func test_deleteBill_removesFromList() {
        // Given
        createBillWithDocument(vendor: "Sky Ireland", billType: .tv)
        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 1)

        guard let bill = sut.bills.first else {
            XCTFail("No bill found")
            return
        }

        // When
        sut.deleteBill(bill, modelContext: modelContext)

        // Then
        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 0)

        // Verify linked document is also deleted
        let docDescriptor = FetchDescriptor<Document>()
        let docs = try? modelContext.fetch(docDescriptor)
        XCTAssertEqual(docs?.count, 0)
    }

    // MARK: - Extracted Data Round-Trip (Regression Test)

    @MainActor
    func test_extractedData_roundtrip_persistsAfterSave() {
        // Given — create a ParsedBillData with all fields populated
        let parsedData = ParsedBillData(
            vendor: "Electric Ireland",
            billDate: "2026-02-10",
            dueDate: "2026-02-28",
            billingPeriodStart: "2026-01-01",
            billingPeriodEnd: "2026-01-31",
            totalAmount: "142.50",
            subtotalAmount: "120.00",
            taxAmount: "22.50",
            accountNumber: "IE-12345678",
            billType: "Electric",
            suggestedCategory: "Utilities",
            confidence: 0.92,
            lineItems: nil
        )

        let document = Document(
            filename: "electric-bill-jan.pdf",
            localPath: "/tmp/electric-bill-jan.pdf",
            documentType: .bill,
            fileSize: 2048,
            mimeType: "application/pdf"
        )
        modelContext.insert(document)

        // When — encode and persist (mimicking what parseImportedDocument does)
        let jsonData = try! JSONEncoder().encode(parsedData)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        document.extractedData = jsonString
        document.isProcessed = true
        try? modelContext.save()

        // Then — fetch from context and decode
        let descriptor = FetchDescriptor<Document>(
            predicate: #Predicate<Document> { doc in
                doc.filename == "electric-bill-jan.pdf"
            }
        )
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetched?.count, 1)

        let fetchedDoc = fetched!.first!
        XCTAssertTrue(fetchedDoc.isProcessed)
        XCTAssertNotNil(fetchedDoc.extractedData)

        // Decode and verify all fields
        let decodedData = fetchedDoc.extractedData!.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(ParsedBillData.self, from: decodedData)

        XCTAssertEqual(decoded.vendor, "Electric Ireland")
        XCTAssertEqual(decoded.billDate, "2026-02-10")
        XCTAssertEqual(decoded.dueDate, "2026-02-28")
        XCTAssertEqual(decoded.billingPeriodStart, "2026-01-01")
        XCTAssertEqual(decoded.billingPeriodEnd, "2026-01-31")
        XCTAssertEqual(decoded.totalAmount, "142.50")
        XCTAssertEqual(decoded.subtotalAmount, "120.00")
        XCTAssertEqual(decoded.taxAmount, "22.50")
        XCTAssertEqual(decoded.accountNumber, "IE-12345678")
        XCTAssertEqual(decoded.billType, "Electric")
        XCTAssertEqual(decoded.suggestedCategory, "Utilities")
        XCTAssertEqual(decoded.confidence, 0.92)

        // Verify resolved types
        XCTAssertEqual(decoded.resolvedBillType, .electric)
        XCTAssertEqual(decoded.resolvedCategoryType, .utilities)

        // Verify Decimal conversion
        XCTAssertEqual(ParsedBillData.toDecimal(decoded.totalAmount), Decimal(string: "142.50")!)
        XCTAssertEqual(ParsedBillData.toDecimal(decoded.taxAmount), Decimal(string: "22.50")!)
    }

    // MARK: - Filter by Bill Type

    @MainActor
    func test_filteredBills_byBillType() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        createBillWithDocument(
            vendor: "Electric Ireland",
            billType: .electric,
            date: makeDate(year: currentYear, month: 1, day: 15)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "Virgin Media",
            billType: .internet,
            date: makeDate(year: currentYear, month: 2, day: 15)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "Vodafone",
            billType: .mobile,
            date: makeDate(year: currentYear, month: 3, day: 15)
        )

        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 3)

        // When — filter by Electric
        sut.filterBillType = .electric
        XCTAssertEqual(sut.filteredBills.count, 1)
        XCTAssertEqual(sut.filteredBills.first?.descriptionText, "Electric Ireland")

        // When — filter by Internet
        sut.filterBillType = .internet
        XCTAssertEqual(sut.filteredBills.count, 1)
        XCTAssertEqual(sut.filteredBills.first?.descriptionText, "Virgin Media")

        // When — no filter
        sut.filterBillType = nil
        XCTAssertEqual(sut.filteredBills.count, 3)
    }

    // MARK: - Legacy Tag Recognition

    @MainActor
    func test_loadBills_recognizesLegacyTags() {
        // Simulate a pre-migration bill with legacy tag
        let currentYear = Calendar.current.component(.year, from: Date())
        let transaction = Transaction(
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: currentYear, month: 1, day: 1),
            descriptionText: "Old Bill",
            type: .expense,
            notes: "[Gas & Electric] Old bill"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        // When
        sut.loadBills(modelContext: modelContext)

        // Then — legacy-tagged bill should appear
        XCTAssertEqual(sut.bills.count, 1)
        XCTAssertEqual(sut.bills.first?.descriptionText, "Old Bill")
    }

    @MainActor
    func test_filteredBills_legacyTag_matchesNewFilter() {
        // Simulate a pre-migration bill with [Gas & Electric] tag
        let currentYear = Calendar.current.component(.year, from: Date())
        let transaction = Transaction(
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: currentYear, month: 1, day: 1),
            descriptionText: "Legacy Bill",
            type: .expense,
            notes: "[Gas & Electric] Legacy"
        )
        modelContext.insert(transaction)
        try? modelContext.save()

        sut.loadBills(modelContext: modelContext)

        // When — filter by .gas should match [Gas & Electric] via legacy mapping
        sut.filterBillType = .gas
        XCTAssertEqual(sut.filteredBills.count, 1)

        // When — filter by .electric should also match
        sut.filterBillType = .electric
        XCTAssertEqual(sut.filteredBills.count, 1)

        // When — filter by .water should not match
        sut.filterBillType = .water
        XCTAssertEqual(sut.filteredBills.count, 0)
    }

    // MARK: - Extract Bill Types

    func test_extractBillTypes_newTags() {
        let types = BillsViewModel.extractBillTypes(from: "[Gas][Electric]")
        XCTAssertTrue(types.contains(.gas))
        XCTAssertTrue(types.contains(.electric))
        XCTAssertEqual(types.count, 2)
    }

    func test_extractBillTypes_legacyTag() {
        let types = BillsViewModel.extractBillTypes(from: "[Internet & TV] Some notes")
        XCTAssertTrue(types.contains(.internet))
        XCTAssertTrue(types.contains(.tv))
    }

    func test_extractBillTypes_nilNotes() {
        let types = BillsViewModel.extractBillTypes(from: nil)
        XCTAssertTrue(types.isEmpty)
    }

    // MARK: - Bills Grouped By Month

    @MainActor
    func test_billsGroupedByMonth_sortsCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        createBillWithDocument(
            vendor: "January Bill",
            date: makeDate(year: currentYear, month: 1, day: 10)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "March Bill",
            date: makeDate(year: currentYear, month: 3, day: 10)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "February Bill",
            date: makeDate(year: currentYear, month: 2, day: 10)
        )

        sut.loadBills(modelContext: modelContext)

        // When
        let grouped = sut.billsGroupedByMonth

        // Then — most recent month first
        XCTAssertEqual(grouped.count, 3)
        XCTAssertEqual(grouped[0].bills.first?.descriptionText, "March Bill")
        XCTAssertEqual(grouped[1].bills.first?.descriptionText, "February Bill")
        XCTAssertEqual(grouped[2].bills.first?.descriptionText, "January Bill")
    }

    // MARK: - Computed Properties

    @MainActor
    func test_totalSpentYTD_sumsCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        createBillWithDocument(
            amount: Decimal(string: "100.00")!,
            vendor: "Bill 1",
            date: makeDate(year: currentYear, month: 1, day: 15)
        )
        sut.resetImportState()

        createBillWithDocument(
            amount: Decimal(string: "200.00")!,
            vendor: "Bill 2",
            date: makeDate(year: currentYear, month: 2, day: 15)
        )

        sut.loadBills(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.totalSpentYTD, Decimal(string: "300.00")!)
    }

    @MainActor
    func test_billCount_returnsCorrectCount() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        createBillWithDocument(
            vendor: "Bill A",
            date: makeDate(year: currentYear, month: 1, day: 1)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "Bill B",
            date: makeDate(year: currentYear, month: 2, day: 1)
        )

        sut.loadBills(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.billCount, 2)
    }

    // MARK: - Manual Bill (No Document) Appears in List (Regression #12)

    @MainActor
    func test_manualBillWithoutDocument_appearsInLoadBills() {
        // Given — add a bill with no uploaded document (attachDocument: false)
        let currentYear = Calendar.current.component(.year, from: Date())
        let billDate = makeDate(year: currentYear, month: 5, day: 20)

        sut.createBillTransaction(
            amount: Decimal(string: "75.50")!,
            date: billDate,
            vendor: "Netflix",
            billType: .streaming,
            categoryType: .entertainment,
            notes: nil,
            dueDate: nil,
            isRecurring: true,
            recurringFrequency: .monthly,
            modelContext: modelContext
        )

        // When
        sut.loadBills(modelContext: modelContext)

        // Then — bill must appear even without a linked document
        XCTAssertEqual(sut.bills.count, 1)
        XCTAssertEqual(sut.bills.first?.descriptionText, "Netflix")
        XCTAssertEqual(sut.bills.first?.amount, Decimal(string: "75.50")!)
        XCTAssertTrue(sut.bills.first?.notes?.contains("[Streaming]") ?? false)
        XCTAssertNil(sut.bills.first?.linkedDocument)
    }

    @MainActor
    func test_mixedBills_withAndWithoutDocuments_allAppear() {
        // Given — one manual bill, one with document
        let currentYear = Calendar.current.component(.year, from: Date())

        // Manual bill
        sut.createBillTransaction(
            amount: Decimal(string: "12.99")!,
            date: makeDate(year: currentYear, month: 4, day: 1),
            vendor: "Spotify",
            billType: .streaming,
            categoryType: .entertainment,
            notes: nil,
            dueDate: nil,
            isRecurring: true,
            recurringFrequency: .monthly,
            modelContext: modelContext
        )

        // Bill with document
        createBillWithDocument(
            amount: Decimal(string: "89.00")!,
            vendor: "Electric Ireland",
            billType: .electric,
            date: makeDate(year: currentYear, month: 4, day: 15)
        )

        // When
        sut.loadBills(modelContext: modelContext)

        // Then — both bills appear
        XCTAssertEqual(sut.bills.count, 2)
        let vendors = Set(sut.bills.map(\.descriptionText))
        XCTAssertTrue(vendors.contains("Spotify"))
        XCTAssertTrue(vendors.contains("Electric Ireland"))
    }

    // MARK: - Recurring Detection

    @MainActor
    func test_detectionTriggersAfterSecondBillFromSameVendor() {
        let currentYear = Calendar.current.component(.year, from: Date())

        // First bill - should NOT trigger
        sut.createBillTransaction(
            amount: Decimal(string: "100.00")!,
            date: makeDate(year: currentYear, month: 1, day: 15),
            vendor: "Electric Ireland",
            billType: .electric,
            categoryType: .utilities,
            notes: nil,
            dueDate: nil,
            isRecurring: false,
            recurringFrequency: nil,
            modelContext: modelContext
        )
        XCTAssertFalse(sut.showingRecurringSuggestion)
        XCTAssertNil(sut.detectedRecurring)

        // Second bill - should trigger
        sut.createBillTransaction(
            amount: Decimal(string: "110.00")!,
            date: makeDate(year: currentYear, month: 2, day: 15),
            vendor: "Electric Ireland",
            billType: .electric,
            categoryType: .utilities,
            notes: nil,
            dueDate: nil,
            isRecurring: false,
            recurringFrequency: nil,
            modelContext: modelContext
        )
        XCTAssertTrue(sut.showingRecurringSuggestion)
        XCTAssertNotNil(sut.detectedRecurring)
        XCTAssertEqual(sut.detectedRecurring?.vendor, "Electric Ireland")
    }

    @MainActor
    func test_noDetectionAfterFirstBill() {
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createBillTransaction(
            amount: Decimal(string: "50.00")!,
            date: makeDate(year: currentYear, month: 3, day: 1),
            vendor: "Netflix",
            billType: .streaming,
            categoryType: .entertainment,
            notes: nil,
            dueDate: nil,
            isRecurring: false,
            recurringFrequency: nil,
            modelContext: modelContext
        )

        XCTAssertFalse(sut.showingRecurringSuggestion)
        XCTAssertNil(sut.detectedRecurring)
    }

    // MARK: - Reset Import State

    func test_resetImportState_clearsAllFields() {
        // Given
        sut.importedDocument = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        sut.parsedData = ParsedBillData(
            vendor: "Test", billDate: nil, dueDate: nil,
            billingPeriodStart: nil, billingPeriodEnd: nil,
            totalAmount: "100", subtotalAmount: nil, taxAmount: nil,
            accountNumber: nil, billType: nil, suggestedCategory: nil,
            confidence: 0.9, lineItems: nil
        )
        sut.parsingError = "Some error"
        sut.isParsing = true

        // When
        sut.resetImportState()

        // Then
        XCTAssertNil(sut.importedDocument)
        XCTAssertNil(sut.parsedData)
        XCTAssertNil(sut.parsingError)
        XCTAssertFalse(sut.isParsing)
    }
}
