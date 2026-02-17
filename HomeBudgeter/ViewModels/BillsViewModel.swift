//
//  BillsViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Observable
class BillsViewModel {
    var bills: [Transaction] = []
    var showingCreateSheet: Bool = false
    var selectedBill: Transaction?
    var filterYear: Int = Calendar.current.component(.year, from: Date())
    var filterBillType: BillType?
    var showingFileImporter: Bool = false
    var importedDocument: Document?
    var importError: String?
    var parsedData: ParsedBillData?
    var isParsing: Bool = false
    var parsingError: String?
    var detectedRecurring: RecurringBillDetector.DetectionResult?
    var showingRecurringSuggestion: Bool = false

    // MARK: - Bill Type Extraction

    /// Extracts all BillType tags from a transaction's notes, supporting both new and legacy tags.
    static func extractBillTypes(from notes: String?) -> [BillType] {
        guard let notes = notes else { return [] }
        var types: [BillType] = []

        // Match new tags
        for type in BillType.allCases {
            if notes.contains("[\(type.rawValue)]") {
                types.append(type)
            }
        }

        // Match legacy tags and map to new types
        for (legacyRaw, mappedTypes) in BillType.legacyMappings {
            if notes.contains("[\(legacyRaw)]") {
                for mapped in mappedTypes where !types.contains(mapped) {
                    types.append(mapped)
                }
            }
        }

        return types
    }

    /// Returns true if notes contain any bill type tag (new or legacy).
    static func hasBillTag(_ notes: String?) -> Bool {
        guard let notes = notes else { return false }

        // Check new tags
        if BillType.allCases.contains(where: { notes.contains("[\($0.rawValue)]") }) {
            return true
        }

        // Check legacy tags
        if BillType.legacyRawValues.contains(where: { notes.contains("[\($0)]") }) {
            return true
        }

        return false
    }

    // MARK: - Computed Properties

    var filteredBills: [Transaction] {
        var result = bills.filter { transaction in
            let year = Calendar.current.component(.year, from: transaction.date)
            return year == filterYear
        }

        if let billType = filterBillType {
            result = result.filter { transaction in
                guard let notes = transaction.notes else { return false }
                // Direct match
                if notes.contains("[\(billType.rawValue)]") { return true }
                // Legacy match: if filtering by .gas, also match [Gas & Electric]
                for (legacyRaw, mappedTypes) in BillType.legacyMappings {
                    if mappedTypes.contains(billType) && notes.contains("[\(legacyRaw)]") {
                        return true
                    }
                }
                return false
            }
        }

        return result.sorted { $0.date > $1.date }
    }

    var totalSpentYTD: Decimal {
        filteredBills.reduce(0) { $0 + $1.amount }
    }

    var totalThisMonth: Decimal {
        let now = Date()
        let month = Calendar.current.component(.month, from: now)
        let year = Calendar.current.component(.year, from: now)
        return filteredBills
            .filter {
                Calendar.current.component(.month, from: $0.date) == month &&
                Calendar.current.component(.year, from: $0.date) == year
            }
            .reduce(0) { $0 + $1.amount }
    }

    var averageMonthlyBill: Decimal {
        guard !filteredBills.isEmpty else { return 0 }
        let months = Set(filteredBills.map {
            "\(Calendar.current.component(.year, from: $0.date))-\(Calendar.current.component(.month, from: $0.date))"
        })
        guard !months.isEmpty else { return 0 }
        return totalSpentYTD / Decimal(months.count)
    }

    var billCount: Int {
        filteredBills.count
    }

    var availableYears: [Int] {
        var years = Set(bills.map { Calendar.current.component(.year, from: $0.date) })
        years.insert(filterYear)
        return years.sorted().reversed()
    }

    var billsGroupedByMonth: [(month: String, bills: [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredBills) { transaction -> String in
            formatter.string(from: transaction.date)
        }

        return grouped.map { (month: $0.key, bills: $0.value.sorted { $0.date > $1.date }) }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.bills.first?.date,
                      let rhsDate = rhs.bills.first?.date else { return false }
                return lhsDate > rhsDate
            }
    }

    // MARK: - Data Methods

    @MainActor
    func loadBills(modelContext: ModelContext) {
        // Bills are identified by their [BillType] tag in notes, not solely by linked documents.
        // This ensures both manually-added and document-uploaded bills appear in the list.
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.notes != nil
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let all = try modelContext.fetch(descriptor)
            bills = all.filter { transaction in
                Self.hasBillTag(transaction.notes)
            }
        } catch {
            print("Error loading bills: \(error)")
        }
    }

    func importBillFile(from url: URL, modelContext: ModelContext) async {
        guard url.startAccessingSecurityScopedResource() else {
            await MainActor.run { importError = "Could not access the file" }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("HomeBudgeter")
                .appendingPathComponent("Documents")
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)

            let destinationURL = documentsPath.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destinationURL)

            var finalURL = destinationURL
            var finalSize = fileSize
            let isEncryptionEnabled = UserDefaults.standard.bool(forKey: "encryptDocuments")
            if isEncryptionEnabled {
                let fileData = try Data(contentsOf: destinationURL)
                let encryptedData = try FileEncryptionService.shared.encrypt(data: fileData)
                let encryptedURL = destinationURL.appendingPathExtension("encrypted")
                try encryptedData.write(to: encryptedURL)
                try FileManager.default.removeItem(at: destinationURL)
                finalURL = encryptedURL
                finalSize = Int64(encryptedData.count)
            }

            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

            let document = Document(
                filename: url.lastPathComponent,
                localPath: finalURL.path,
                documentType: .bill,
                fileSize: finalSize,
                mimeType: mimeType
            )

            await MainActor.run {
                modelContext.insert(document)
                try? modelContext.save()
                importedDocument = document
            }

            // Auto-parse if enabled and file is PDF
            let autoParseEnabled = UserDefaults.standard.object(forKey: "autoParseBills") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "autoParseBills")

            if autoParseEnabled && document.mimeType == "application/pdf" {
                await parseImportedDocument(document, modelContext: modelContext)
            }

            await MainActor.run {
                showingCreateSheet = true
            }
        } catch {
            await MainActor.run { importError = error.localizedDescription }
        }
    }

    // MARK: - AI Parsing

    func parseImportedDocument(_ document: Document, modelContext: ModelContext) async {
        await MainActor.run {
            isParsing = true
            parsingError = nil
            parsedData = nil
        }

        do {
            let result = try await PayslipParsingService.shared.parseBillDocument(document)
            await MainActor.run {
                parsedData = result
                isParsing = false
                document.isProcessed = true
                if let jsonData = try? JSONEncoder().encode(result),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    document.extractedData = jsonString
                }
                try? modelContext.save()
            }
        } catch {
            await MainActor.run {
                isParsing = false
                parsingError = error.localizedDescription
            }
        }
    }

    // MARK: - Create Bill Transaction

    /// Creates a bill transaction with optional line items.
    /// If lineItems is non-empty, multi-tag notes and BillLineItem records are created.
    @MainActor
    func createBillTransaction(
        amount: Decimal,
        date: Date,
        vendor: String,
        billType: BillType,
        categoryType: CategoryType,
        notes: String?,
        dueDate: Date?,
        isRecurring: Bool,
        recurringFrequency: RecurringFrequency?,
        lineItems: [(billType: BillType, amount: Decimal, label: String?)] = [],
        modelContext: ModelContext
    ) {
        // Find matching BudgetCategory
        let categoryDescriptor = FetchDescriptor<BudgetCategory>()
        let categories = (try? modelContext.fetch(categoryDescriptor)) ?? []
        let matchingCategory = categories.first(where: { $0.type == categoryType })

        // Build notes with bill type tag(s) for filtering
        var billNotes: String
        if lineItems.isEmpty {
            billNotes = "[\(billType.rawValue)]"
        } else {
            // Multi-tag: [Gas][Electric]
            let tags = lineItems.map { "[\($0.billType.rawValue)]" }
            billNotes = tags.joined()
        }

        if let dueDate = dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            billNotes += " Due: \(formatter.string(from: dueDate))"
        }
        if let extra = notes, !extra.isEmpty {
            billNotes += " \(extra)"
        }

        let transaction = Transaction(
            amount: amount,
            date: date,
            descriptionText: vendor,
            type: .expense,
            isRecurring: isRecurring,
            recurringFrequency: recurringFrequency,
            notes: billNotes,
            category: matchingCategory
        )

        modelContext.insert(transaction)

        // Create BillLineItem records
        if !lineItems.isEmpty {
            for item in lineItems {
                let lineItem = BillLineItem(
                    billType: item.billType,
                    amount: item.amount,
                    label: item.label,
                    transaction: transaction
                )
                modelContext.insert(lineItem)
            }
        } else {
            // Single line item for consistency
            let lineItem = BillLineItem(
                billType: billType,
                amount: amount,
                label: nil,
                transaction: transaction
            )
            modelContext.insert(lineItem)
        }

        // Link uploaded document
        if let doc = importedDocument {
            transaction.linkedDocument = doc
            doc.linkedTransaction = transaction
        }

        try? modelContext.save()
        loadBills(modelContext: modelContext)

        // Auto-detect recurring pattern for this vendor
        if let result = RecurringBillDetector.shared.detectRecurringPattern(for: vendor, modelContext: modelContext) {
            detectedRecurring = result
            showingRecurringSuggestion = true
        }
    }

    @MainActor
    func deleteBill(_ bill: Transaction, modelContext: ModelContext) {
        // Also remove linked document if present
        if let doc = bill.linkedDocument {
            // Try to remove the file from disk
            try? FileManager.default.removeItem(atPath: doc.localPath)
            modelContext.delete(doc)
        }
        modelContext.delete(bill)
        try? modelContext.save()
        loadBills(modelContext: modelContext)
    }

    func resetImportState() {
        importedDocument = nil
        parsedData = nil
        parsingError = nil
        isParsing = false
    }
}
