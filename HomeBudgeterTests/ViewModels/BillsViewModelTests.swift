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
            RecurringTemplate.self
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
        attachDocument: Bool = true
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
            billType: .gasElectric,
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
        XCTAssertTrue(bill?.notes?.contains("[Gas & Electric]") ?? false)
    }

    @MainActor
    func test_createBillTransaction_linksDocument() {
        // Given & When
        createBillWithDocument(vendor: "Virgin Media", billType: .internetTv)

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

    // MARK: - Delete Bill

    @MainActor
    func test_deleteBill_removesFromList() {
        // Given
        createBillWithDocument(vendor: "Sky Ireland")
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
            billType: "Gas & Electric",
            suggestedCategory: "Utilities",
            confidence: 0.92
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
        XCTAssertEqual(decoded.billType, "Gas & Electric")
        XCTAssertEqual(decoded.suggestedCategory, "Utilities")
        XCTAssertEqual(decoded.confidence, 0.92)

        // Verify resolved types
        XCTAssertEqual(decoded.resolvedBillType, .gasElectric)
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
            billType: .gasElectric,
            date: makeDate(year: currentYear, month: 1, day: 15)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "Virgin Media",
            billType: .internetTv,
            date: makeDate(year: currentYear, month: 2, day: 15)
        )
        sut.resetImportState()

        createBillWithDocument(
            vendor: "Vodafone",
            billType: .phone,
            date: makeDate(year: currentYear, month: 3, day: 15)
        )

        sut.loadBills(modelContext: modelContext)
        XCTAssertEqual(sut.bills.count, 3)

        // When — filter by Gas & Electric
        sut.filterBillType = .gasElectric
        XCTAssertEqual(sut.filteredBills.count, 1)
        XCTAssertEqual(sut.filteredBills.first?.descriptionText, "Electric Ireland")

        // When — filter by Internet & TV
        sut.filterBillType = .internetTv
        XCTAssertEqual(sut.filteredBills.count, 1)
        XCTAssertEqual(sut.filteredBills.first?.descriptionText, "Virgin Media")

        // When — no filter
        sut.filterBillType = nil
        XCTAssertEqual(sut.filteredBills.count, 3)
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

    // MARK: - Reset Import State

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
            billType: .subscription,
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
        XCTAssertTrue(sut.bills.first?.notes?.contains("[Subscription]") ?? false)
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
            billType: .subscription,
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
            billType: .gasElectric,
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

    // MARK: - Reset Import State

    func test_resetImportState_clearsAllFields() {
        // Given
        sut.importedDocument = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        sut.parsedData = ParsedBillData(
            vendor: "Test", billDate: nil, dueDate: nil,
            billingPeriodStart: nil, billingPeriodEnd: nil,
            totalAmount: "100", subtotalAmount: nil, taxAmount: nil,
            accountNumber: nil, billType: nil, suggestedCategory: nil,
            confidence: 0.9
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
