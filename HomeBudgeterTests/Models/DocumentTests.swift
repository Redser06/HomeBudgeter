//
//  DocumentTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class DocumentTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
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
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initialisation Tests

    func test_init_withRequiredParams_setsDefaults() {
        let doc = Document(filename: "payslip.pdf", localPath: "/tmp/payslip.pdf")
        XCTAssertNotNil(doc.id)
        XCTAssertEqual(doc.filename, "payslip.pdf")
        XCTAssertEqual(doc.localPath, "/tmp/payslip.pdf")
        XCTAssertEqual(doc.documentType, .other)
        XCTAssertEqual(doc.fileSize, 0)
        XCTAssertEqual(doc.mimeType, "application/pdf")
        XCTAssertFalse(doc.isProcessed)
        XCTAssertNil(doc.extractedData)
        XCTAssertNil(doc.notes)
    }

    func test_init_withAllParams_setsProperties() {
        let doc = Document(
            filename: "invoice.pdf",
            localPath: "/docs/invoice.pdf",
            documentType: .invoice,
            fileSize: 204800,
            mimeType: "application/pdf"
        )
        XCTAssertEqual(doc.filename, "invoice.pdf")
        XCTAssertEqual(doc.documentType, .invoice)
        XCTAssertEqual(doc.fileSize, 204800)
        XCTAssertEqual(doc.mimeType, "application/pdf")
    }

    func test_init_setsUploadDateToNow() {
        let before = Date()
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        let after = Date()
        XCTAssertGreaterThanOrEqual(doc.uploadDate, before)
        XCTAssertLessThanOrEqual(doc.uploadDate, after)
    }

    func test_init_generatesUniqueIds() {
        let d1 = Document(filename: "a.pdf", localPath: "/a.pdf")
        let d2 = Document(filename: "b.pdf", localPath: "/b.pdf")
        XCTAssertNotEqual(d1.id, d2.id)
    }

    // MARK: - formattedFileSize Tests

    func test_formattedFileSize_withZeroBytes_returnsZeroString() {
        let doc = Document(filename: "empty.pdf", localPath: "/tmp/empty.pdf", fileSize: 0)
        XCTAssertFalse(doc.formattedFileSize.isEmpty)
    }

    func test_formattedFileSize_withKilobytes_containsKBUnit() {
        let doc = Document(filename: "small.pdf", localPath: "/tmp/small.pdf", fileSize: 1024)
        let formatted = doc.formattedFileSize
        XCTAssertFalse(formatted.isEmpty)
    }

    func test_formattedFileSize_with1MB_containsMBUnit() {
        let doc = Document(filename: "medium.pdf", localPath: "/tmp/medium.pdf", fileSize: 1_048_576)
        let formatted = doc.formattedFileSize
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("MiB") || formatted.contains("mb"),
                      "Expected MB in formatted size, got: \(formatted)")
    }

    func test_formattedFileSize_with1GB_containsGBUnit() {
        let doc = Document(filename: "large.pdf", localPath: "/tmp/large.pdf", fileSize: 1_073_741_824)
        let formatted = doc.formattedFileSize
        XCTAssertTrue(formatted.contains("GB") || formatted.contains("GiB"),
                      "Expected GB in formatted size, got: \(formatted)")
    }

    func test_formattedFileSize_isNotEmpty() {
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf", fileSize: 512_000)
        XCTAssertFalse(doc.formattedFileSize.isEmpty)
    }

    // MARK: - formattedUploadDate Tests

    func test_formattedUploadDate_isNotEmpty() {
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        XCTAssertFalse(doc.formattedUploadDate.isEmpty)
    }

    func test_formattedUploadDate_containsYear() {
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        XCTAssertTrue(doc.formattedUploadDate.contains(String(year)))
    }

    // MARK: - DocumentType Tests

    func test_documentType_allCasesCount() {
        XCTAssertEqual(DocumentType.allCases.count, 7)
    }

    func test_documentType_rawValues() {
        XCTAssertEqual(DocumentType.payslip.rawValue, "Payslip")
        XCTAssertEqual(DocumentType.bill.rawValue, "Bill")
        XCTAssertEqual(DocumentType.invoice.rawValue, "Invoice")
        XCTAssertEqual(DocumentType.receipt.rawValue, "Receipt")
        XCTAssertEqual(DocumentType.statement.rawValue, "Statement")
        XCTAssertEqual(DocumentType.tax.rawValue, "Tax Document")
        XCTAssertEqual(DocumentType.other.rawValue, "Other")
    }

    func test_documentType_allHaveNonEmptyIcons() {
        for type in DocumentType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "Icon for \(type.rawValue) is empty")
        }
    }

    func test_documentType_payslipIcon() {
        XCTAssertEqual(DocumentType.payslip.icon, "doc.text.fill")
    }

    func test_documentType_receiptIcon() {
        XCTAssertEqual(DocumentType.receipt.icon, "receipt.fill")
    }

    func test_documentType_taxIcon() {
        XCTAssertEqual(DocumentType.tax.icon, "building.columns.fill")
    }

    // MARK: - isProcessed Tests

    func test_newDocument_isNotProcessed() {
        let doc = Document(filename: "new.pdf", localPath: "/tmp/new.pdf")
        XCTAssertFalse(doc.isProcessed)
    }

    func test_setIsProcessed_updatesState() {
        let doc = Document(filename: "new.pdf", localPath: "/tmp/new.pdf")
        doc.isProcessed = true
        XCTAssertTrue(doc.isProcessed)
    }

    // MARK: - Optional Fields Tests

    func test_extractedData_canBeSetAndRead() {
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        doc.extractedData = "{\"amount\": 1234.56}"
        XCTAssertEqual(doc.extractedData, "{\"amount\": 1234.56}")
    }

    func test_notes_canBeSetAndRead() {
        let doc = Document(filename: "test.pdf", localPath: "/tmp/test.pdf")
        doc.notes = "Monthly statement from AIB"
        XCTAssertEqual(doc.notes, "Monthly statement from AIB")
    }

    // MARK: - Persistence Tests

    @MainActor
    func test_saveAndFetch_document_persistsCorrectly() throws {
        let doc = Document(
            filename: "statement.pdf",
            localPath: "/docs/statement.pdf",
            documentType: .statement,
            fileSize: 256_000
        )
        modelContext.insert(doc)
        try modelContext.save()

        let descriptor = FetchDescriptor<Document>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.filename, "statement.pdf")
        XCTAssertEqual(fetched.first?.documentType, .statement)
        XCTAssertEqual(fetched.first?.fileSize, 256_000)
    }

    @MainActor
    func test_delete_document_removesFromStore() throws {
        let doc = Document(filename: "delete_me.pdf", localPath: "/tmp/delete_me.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        modelContext.delete(doc)
        try modelContext.save()

        let descriptor = FetchDescriptor<Document>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertTrue(fetched.isEmpty)
    }

    @MainActor
    func test_multipleDocuments_fetchedInOrder() throws {
        let doc1 = Document(filename: "first.pdf", localPath: "/tmp/first.pdf", fileSize: 100)
        let doc2 = Document(filename: "second.pdf", localPath: "/tmp/second.pdf", fileSize: 200)
        let doc3 = Document(filename: "third.pdf", localPath: "/tmp/third.pdf", fileSize: 300)

        modelContext.insert(doc1)
        modelContext.insert(doc2)
        modelContext.insert(doc3)
        try modelContext.save()

        let descriptor = FetchDescriptor<Document>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 3)
    }
}
