//
//  PayslipViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Observable
class PayslipViewModel {
    var payslips: [Payslip] = []
    var showingCreateSheet: Bool = false
    var selectedPayslip: Payslip?
    var filterYear: Int = Calendar.current.component(.year, from: Date())
    var filterEmployer: String?
    var showingFileImporter: Bool = false
    var importedDocument: Document?
    var importError: String?
    var parsedData: ParsedPayslipData?
    var isParsing: Bool = false
    var parsingError: String?

    // MARK: - Computed Properties

    var filteredPayslips: [Payslip] {
        var result = payslips.filter { payslip in
            let year = Calendar.current.component(.year, from: payslip.payDate)
            return year == filterYear
        }

        if let employer = filterEmployer, !employer.isEmpty {
            result = result.filter { $0.employer == employer }
        }

        return result.sorted { $0.payDate > $1.payDate }
    }

    var totalGrossYTD: Decimal {
        filteredPayslips.reduce(0) { $0 + $1.grossPay }
    }

    var totalNetYTD: Decimal {
        filteredPayslips.reduce(0) { $0 + $1.netPay }
    }

    var totalTaxYTD: Decimal {
        filteredPayslips.reduce(0) { $0 + $1.incomeTax }
    }

    var averageNetPay: Decimal {
        guard !filteredPayslips.isEmpty else { return 0 }
        return totalNetYTD / Decimal(filteredPayslips.count)
    }

    var availableYears: [Int] {
        let years = Set(payslips.map { Calendar.current.component(.year, from: $0.payDate) })
        return years.sorted().reversed()
    }

    var availableEmployers: [String] {
        let employers = Set(payslips.compactMap { $0.employer })
        return employers.sorted()
    }

    var payslipsGroupedByMonth: [(month: String, payslips: [Payslip])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredPayslips) { payslip -> String in
            formatter.string(from: payslip.payDate)
        }

        return grouped.map { (month: $0.key, payslips: $0.value.sorted { $0.payDate > $1.payDate }) }
            .sorted { lhs, rhs in
                guard let lhsDate = lhs.payslips.first?.payDate,
                      let rhsDate = rhs.payslips.first?.payDate else { return false }
                return lhsDate > rhsDate
            }
    }

    // MARK: - Data Methods

    func loadPayslips(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Payslip>(
            sortBy: [SortDescriptor(\.payDate, order: .reverse)]
        )

        do {
            payslips = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading payslips: \(error)")
        }
    }

    func createPayslip(
        payDate: Date,
        payPeriodStart: Date,
        payPeriodEnd: Date,
        grossPay: Decimal,
        netPay: Decimal,
        incomeTax: Decimal,
        socialInsurance: Decimal,
        universalCharge: Decimal?,
        pensionContribution: Decimal,
        employerPensionContribution: Decimal,
        otherDeductions: Decimal,
        employer: String?,
        notes: String?,
        modelContext: ModelContext
    ) {
        let payslip = Payslip(
            payDate: payDate,
            payPeriodStart: payPeriodStart,
            payPeriodEnd: payPeriodEnd,
            grossPay: grossPay,
            netPay: netPay,
            incomeTax: incomeTax,
            socialInsurance: socialInsurance,
            universalCharge: universalCharge,
            pensionContribution: pensionContribution,
            employerPensionContribution: employerPensionContribution,
            otherDeductions: otherDeductions,
            employer: employer
        )
        payslip.notes = notes
        modelContext.insert(payslip)

        // Update pension data if it exists
        let pensionDescriptor = FetchDescriptor<PensionData>()
        if let pensionData = try? modelContext.fetch(pensionDescriptor).first {
            pensionData.updateFromPayslip(payslip)
        }

        try? modelContext.save()
        loadPayslips(modelContext: modelContext)
    }

    func deletePayslip(_ payslip: Payslip, modelContext: ModelContext) {
        modelContext.delete(payslip)
        try? modelContext.save()
        loadPayslips(modelContext: modelContext)
    }

    func updatePayslip(_ payslip: Payslip, modelContext: ModelContext) {
        try? modelContext.save()
        loadPayslips(modelContext: modelContext)
    }

    // MARK: - File Import

    func importPayslipFile(from url: URL, modelContext: ModelContext) async {
        guard url.startAccessingSecurityScopedResource() else {
            await MainActor.run { importError = "Could not access the file" }
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            // Create documents directory if needed
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("HomeBudgeter")
                .appendingPathComponent("Documents")
            try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true)

            // Copy file
            let destinationURL = documentsPath.appendingPathComponent(UUID().uuidString + "_" + url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destinationURL)

            // Encrypt if enabled
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
                documentType: .payslip,
                fileSize: finalSize,
                mimeType: mimeType
            )

            await MainActor.run {
                modelContext.insert(document)
                try? modelContext.save()
                importedDocument = document
            }

            // Attempt AI parsing if auto-parse is enabled and file is PDF
            let autoParseEnabled = UserDefaults.standard.object(forKey: "autoParsePayslips") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "autoParsePayslips")

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

    func linkDocumentToPayslip(_ payslip: Payslip, document: Document, modelContext: ModelContext) {
        payslip.sourceDocument = document
        document.linkedPayslip = payslip
        try? modelContext.save()
    }

    // MARK: - AI Parsing

    func parseImportedDocument(_ document: Document, modelContext: ModelContext) async {
        await MainActor.run {
            isParsing = true
            parsingError = nil
            parsedData = nil
        }

        do {
            let result = try await PayslipParsingService.shared.parseDocument(document)
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
}
