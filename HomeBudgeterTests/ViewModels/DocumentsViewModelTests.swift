//
//  DocumentsViewModelTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class DocumentsViewModelTests: XCTestCase {

    var sut: DocumentsViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
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
        sut = DocumentsViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_documentsEmpty() {
        XCTAssertTrue(sut.documents.isEmpty)
    }

    func test_initialState_selectedDocumentNil() {
        XCTAssertNil(sut.selectedDocument)
    }

    func test_initialState_showingFilePickerFalse() {
        XCTAssertFalse(sut.showingFilePicker)
    }

    func test_initialState_isProcessingFalse() {
        XCTAssertFalse(sut.isProcessing)
    }

    func test_initialState_processingProgressZero() {
        XCTAssertEqual(sut.processingProgress, 0.0)
    }

    func test_initialState_searchTextEmpty() {
        XCTAssertEqual(sut.searchText, "")
    }

    func test_initialState_selectedTypeNil() {
        XCTAssertNil(sut.selectedType)
    }

    // MARK: - totalStorageUsed Tests

    func test_totalStorageUsed_withNoDocuments_returnsZero() {
        XCTAssertEqual(sut.totalStorageUsed, 0)
    }

    @MainActor
    func test_totalStorageUsed_sumAllFileSizes() throws {
        let doc1 = Document(filename: "a.pdf", localPath: "/a.pdf", fileSize: 1024)
        let doc2 = Document(filename: "b.pdf", localPath: "/b.pdf", fileSize: 2048)
        modelContext.insert(doc1)
        modelContext.insert(doc2)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)

        XCTAssertEqual(sut.totalStorageUsed, 3072)
    }

    @MainActor
    func test_totalStorageUsed_withSingleDocument_returnsItsSize() throws {
        let doc = Document(filename: "test.pdf", localPath: "/test.pdf", fileSize: 512_000)
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)

        XCTAssertEqual(sut.totalStorageUsed, 512_000)
    }

    // MARK: - formattedStorageUsed Tests

    func test_formattedStorageUsed_withNoDocuments_isNotEmpty() {
        XCTAssertFalse(sut.formattedStorageUsed.isEmpty)
    }

    @MainActor
    func test_formattedStorageUsed_withLargeFiles_containsUnit() throws {
        let doc = Document(filename: "large.pdf", localPath: "/large.pdf", fileSize: 5_242_880)
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)

        XCTAssertFalse(sut.formattedStorageUsed.isEmpty)
    }

    // MARK: - loadDocuments Tests

    @MainActor
    func test_loadDocuments_withEmptyDB_leavesEmpty() {
        sut.loadDocuments(modelContext: modelContext)
        XCTAssertTrue(sut.documents.isEmpty)
    }

    @MainActor
    func test_loadDocuments_loadsAllDocuments() throws {
        let doc1 = Document(filename: "payslip.pdf", localPath: "/p.pdf", documentType: .payslip)
        let doc2 = Document(filename: "bill.pdf", localPath: "/b.pdf", documentType: .bill)
        modelContext.insert(doc1)
        modelContext.insert(doc2)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)

        XCTAssertEqual(sut.documents.count, 2)
    }

    // MARK: - displayedDocuments Tests

    @MainActor
    func test_displayedDocuments_withNoFilters_returnsAllDocuments() throws {
        let doc1 = Document(filename: "a.pdf", localPath: "/a.pdf")
        let doc2 = Document(filename: "b.pdf", localPath: "/b.pdf")
        modelContext.insert(doc1)
        modelContext.insert(doc2)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)

        XCTAssertEqual(sut.displayedDocuments.count, 2)
    }

    @MainActor
    func test_displayedDocuments_withTypeFilter_returnsFilteredSet() throws {
        let payslip = Document(filename: "payslip.pdf", localPath: "/p.pdf", documentType: .payslip)
        let bill = Document(filename: "bill.pdf", localPath: "/b.pdf", documentType: .bill)
        modelContext.insert(payslip)
        modelContext.insert(bill)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        sut.selectedType = .payslip

        let displayed = sut.displayedDocuments
        XCTAssertTrue(displayed.allSatisfy { $0.documentType == .payslip })
    }

    // MARK: - Search Filtering Tests

    @MainActor
    func test_searchByFilename_findsMatch() throws {
        let doc = Document(filename: "january_payslip.pdf", localPath: "/j.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        sut.searchText = "january"

        XCTAssertEqual(sut.displayedDocuments.count, 1)
    }

    @MainActor
    func test_searchCaseInsensitive_findsMatch() throws {
        let doc = Document(filename: "PAYSLIP_JAN.pdf", localPath: "/j.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        sut.searchText = "payslip"

        XCTAssertFalse(sut.displayedDocuments.isEmpty)
    }

    @MainActor
    func test_searchWithNoMatch_returnsEmpty() throws {
        let doc = Document(filename: "tax_return.pdf", localPath: "/t.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        sut.searchText = "zzznomatch"

        XCTAssertTrue(sut.displayedDocuments.isEmpty)
    }

    @MainActor
    func test_searchByNotes_findsMatch() throws {
        let doc = Document(filename: "doc.pdf", localPath: "/d.pdf")
        doc.notes = "important tax document"
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        sut.searchText = "important"

        XCTAssertFalse(sut.displayedDocuments.isEmpty)
    }

    // MARK: - deleteDocument Tests

    @MainActor
    func test_deleteDocument_removesFromDocumentsArray() throws {
        let doc = Document(filename: "to_delete.pdf", localPath: "/nonexistent/path.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        let countBefore = sut.documents.count

        sut.deleteDocument(doc, modelContext: modelContext)

        XCTAssertEqual(sut.documents.count, countBefore - 1)
    }

    @MainActor
    func test_deleteDocument_removesFromDatabase() throws {
        let doc = Document(filename: "to_delete.pdf", localPath: "/nonexistent/path.pdf")
        modelContext.insert(doc)
        try modelContext.save()

        sut.deleteDocument(doc, modelContext: modelContext)

        let descriptor = FetchDescriptor<Document>()
        let remaining = try modelContext.fetch(descriptor)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - documentsByType Tests

    @MainActor
    func test_documentsByType_groupsCorrectly() throws {
        let payslip1 = Document(filename: "p1.pdf", localPath: "/p1.pdf", documentType: .payslip)
        let payslip2 = Document(filename: "p2.pdf", localPath: "/p2.pdf", documentType: .payslip)
        let bill = Document(filename: "b.pdf", localPath: "/b.pdf", documentType: .bill)
        modelContext.insert(payslip1)
        modelContext.insert(payslip2)
        modelContext.insert(bill)
        try modelContext.save()

        sut.loadDocuments(modelContext: modelContext)
        let grouped = sut.documentsByType

        XCTAssertEqual(grouped[.payslip]?.count, 2)
        XCTAssertEqual(grouped[.bill]?.count, 1)
    }

    @MainActor
    func test_documentsByType_withNoDocuments_returnsEmptyDict() {
        sut.loadDocuments(modelContext: modelContext)
        XCTAssertTrue(sut.documentsByType.isEmpty)
    }

    // MARK: - DocumentError Tests

    func test_documentError_accessDeniedDescription() {
        let error = DocumentError.accessDenied
        XCTAssertEqual(error.errorDescription, "Could not access the file")
    }

    func test_documentError_copyFailedDescription() {
        let error = DocumentError.copyFailed
        XCTAssertEqual(error.errorDescription, "Failed to copy the file")
    }

    func test_documentError_invalidFileDescription() {
        let error = DocumentError.invalidFile
        XCTAssertEqual(error.errorDescription, "The file is invalid or corrupted")
    }
}
