//
//  PensionViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Contribution Chart Data

struct PensionContributionData: Identifiable {
    let id = UUID()
    let date: Date
    let employeeAmount: Double
    let employerAmount: Double
    var total: Double { employeeAmount + employerAmount }
}

// MARK: - PensionViewModel

@Observable
class PensionViewModel {
    var pensionData: PensionData?
    var contributionHistory: [PensionContributionData] = []
    var showingEditSheet: Bool = false
    var showingSetupSheet: Bool = false
    var showingFileImporter: Bool = false
    var showingStatementReview: Bool = false
    var importedDocument: Document?
    var importError: String?
    var parsedStatementData: ParsedPensionStatementData?
    var isParsing: Bool = false
    var parsingError: String?

    // MARK: - Computed Properties

    var currentValue: Decimal {
        pensionData?.currentValue ?? 0
    }

    var totalContributions: Decimal {
        pensionData?.totalContributions ?? 0
    }

    var employeeContributions: Decimal {
        pensionData?.totalEmployeeContributions ?? 0
    }

    var employerContributions: Decimal {
        pensionData?.totalEmployerContributions ?? 0
    }

    var investmentReturns: Decimal {
        pensionData?.totalInvestmentReturns ?? 0
    }

    var progressToGoal: Double? {
        pensionData?.progressToGoal
    }

    var returnPercentage: Double {
        pensionData?.returnPercentage ?? 0
    }

    var projectedValueAtRetirement: Decimal? {
        guard let pension = pensionData,
              let targetAge = pension.targetRetirementAge else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let birthYear = calendar.component(.year, from: now) - 30
        let retirementYear = birthYear + targetAge
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        let monthsUntilRetirement = max(0, (retirementYear - currentYear) * 12 - currentMonth + 1)

        guard monthsUntilRetirement > 0 else {
            return pension.currentValue
        }

        let monthlyContributionRate: Decimal
        if !contributionHistory.isEmpty {
            let totalMonthly = contributionHistory.reduce(0.0) { $0 + $1.total }
            let averageMonthly = totalMonthly / Double(contributionHistory.count)
            monthlyContributionRate = Decimal(averageMonthly)
        } else if pension.totalContributions > 0 {
            let monthsSinceCreation = max(1, calendar.dateComponents([.month], from: pension.createdAt, to: now).month ?? 1)
            monthlyContributionRate = pension.totalContributions / Decimal(monthsSinceCreation)
        } else {
            monthlyContributionRate = 0
        }

        let projected = pension.currentValue + (monthlyContributionRate * Decimal(monthsUntilRetirement))
        return projected
    }

    // MARK: - Data Methods

    func loadPensionData(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PensionData>()

        do {
            let results = try modelContext.fetch(descriptor)
            pensionData = results.first
        } catch {
            print("Error loading pension data: \(error)")
        }

        loadContributionHistory(modelContext: modelContext)
    }

    func loadContributionHistory(modelContext: ModelContext) {
        let calendar = Calendar.current
        let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: Date()) ?? Date()

        var descriptor = FetchDescriptor<Payslip>(
            predicate: #Predicate<Payslip> { payslip in
                payslip.payDate >= twelveMonthsAgo
            },
            sortBy: [SortDescriptor(\.payDate, order: .forward)]
        )
        descriptor.fetchLimit = 365

        do {
            let payslips = try modelContext.fetch(descriptor)

            var monthlyData: [String: (date: Date, employee: Double, employer: Double)] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"

            for payslip in payslips {
                let key = dateFormatter.string(from: payslip.payDate)
                let employeeAmount = Double(truncating: payslip.pensionContribution as NSNumber)
                let employerAmount = Double(truncating: payslip.employerPensionContribution as NSNumber)

                if var existing = monthlyData[key] {
                    existing.employee += employeeAmount
                    existing.employer += employerAmount
                    monthlyData[key] = existing
                } else {
                    let components = calendar.dateComponents([.year, .month], from: payslip.payDate)
                    let monthStart = calendar.date(from: components) ?? payslip.payDate
                    monthlyData[key] = (date: monthStart, employee: employeeAmount, employer: employerAmount)
                }
            }

            contributionHistory = monthlyData.values
                .sorted { $0.date < $1.date }
                .map { PensionContributionData(date: $0.date, employeeAmount: $0.employee, employerAmount: $0.employer) }
        } catch {
            print("Error loading contribution history: \(error)")
        }
    }

    func createPensionData(
        currentValue: Decimal,
        provider: String?,
        retirementGoal: Decimal?,
        targetRetirementAge: Int?,
        notes: String?,
        modelContext: ModelContext
    ) {
        let pension = PensionData(
            currentValue: currentValue,
            retirementGoal: retirementGoal,
            targetRetirementAge: targetRetirementAge,
            provider: provider
        )
        pension.notes = notes
        modelContext.insert(pension)
        try? modelContext.save()
        loadPensionData(modelContext: modelContext)
    }

    func updatePensionData(
        currentValue: Decimal,
        investmentReturns: Decimal,
        provider: String?,
        retirementGoal: Decimal?,
        targetRetirementAge: Int?,
        notes: String?,
        modelContext: ModelContext
    ) {
        guard let pension = pensionData else { return }
        pension.currentValue = currentValue
        pension.totalInvestmentReturns = investmentReturns
        pension.provider = provider
        pension.retirementGoal = retirementGoal
        pension.targetRetirementAge = targetRetirementAge
        pension.notes = notes
        pension.lastUpdated = Date()
        try? modelContext.save()
        loadPensionData(modelContext: modelContext)
    }

    // MARK: - Statement File Import

    func importStatementFile(from url: URL, modelContext: ModelContext) async {
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
                documentType: .statement,
                fileSize: finalSize,
                mimeType: mimeType
            )

            await MainActor.run {
                modelContext.insert(document)
                try? modelContext.save()
                importedDocument = document
            }

            let autoParseEnabled = UserDefaults.standard.object(forKey: "autoParsePayslips") == nil
                ? true
                : UserDefaults.standard.bool(forKey: "autoParsePayslips")

            if autoParseEnabled && document.mimeType == "application/pdf" {
                await parseImportedDocument(document, modelContext: modelContext)
            }

            await MainActor.run {
                showingStatementReview = true
            }
        } catch {
            await MainActor.run { importError = error.localizedDescription }
        }
    }

    func parseImportedDocument(_ document: Document, modelContext: ModelContext) async {
        await MainActor.run {
            isParsing = true
            parsingError = nil
            parsedStatementData = nil
        }

        do {
            let result = try await PayslipParsingService.shared.parsePensionStatement(document)
            await MainActor.run {
                parsedStatementData = result
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

    func applyParsedStatement(modelContext: ModelContext) {
        guard let data = parsedStatementData, let pension = pensionData else { return }

        let newValue = ParsedPensionStatementData.toDecimal(data.currentValue)
        if newValue > 0 { pension.currentValue = newValue }

        let employeeContribs = ParsedPensionStatementData.toDecimal(data.totalEmployeeContributions)
        if employeeContribs > 0 { pension.totalEmployeeContributions = employeeContribs }

        let employerContribs = ParsedPensionStatementData.toDecimal(data.totalEmployerContributions)
        if employerContribs > 0 { pension.totalEmployerContributions = employerContribs }

        let returns = ParsedPensionStatementData.toDecimal(data.totalInvestmentReturns)
        if returns != 0 { pension.totalInvestmentReturns = returns }

        if let provider = data.provider, !provider.isEmpty {
            pension.provider = provider
        }

        pension.lastUpdated = Date()

        if let document = importedDocument {
            if pension.sourceDocuments == nil {
                pension.sourceDocuments = []
            }
            pension.sourceDocuments?.append(document)
        }

        try? modelContext.save()
        parsedStatementData = nil
        importedDocument = nil
        loadPensionData(modelContext: modelContext)
    }
}
