//
//  PensionViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Contribution Chart Data

struct PensionContributionData: Identifiable {
    let id = UUID()
    let date: Date
    let employeeAmount: Double
    let employerAmount: Double
    var total: Double { employeeAmount + employerAmount }
}

// MARK: - Projection Types

enum PensionGrowthBand: String, CaseIterable, Hashable, Identifiable {
    case conservative
    case moderate
    case aggressive
    case custom

    var id: String { rawValue }

    var annualRate: Double {
        switch self {
        case .conservative: return 3.0
        case .moderate: return 5.0
        case .aggressive: return 7.0
        case .custom: return 0 // determined by user input
        }
    }

    var color: Color {
        switch self {
        case .conservative: return .blue
        case .moderate: return .orange
        case .aggressive: return .red
        case .custom: return .purple
        }
    }

    var displayDescription: String {
        switch self {
        case .conservative: return "Conservative (3%)"
        case .moderate: return "Moderate (5%)"
        case .aggressive: return "Aggressive (7%)"
        case .custom: return "Custom"
        }
    }
}

struct PensionYearProjection: Identifiable {
    let id = UUID()
    let year: Int
    let age: Int
    let startValue: Double
    let contributions: Double
    let growth: Double
    var endValue: Double { startValue + contributions + growth }
}

struct PensionProjectionScenario: Identifiable {
    let id = UUID()
    let band: PensionGrowthBand
    let annualGrowthRate: Double
    let monthlyContribution: Double
    let yearProjections: [PensionYearProjection]

    var finalValue: Double {
        yearProjections.last?.endValue ?? 0
    }

    var totalContributions: Double {
        yearProjections.reduce(0) { $0 + $1.contributions }
    }

    var totalGrowth: Double {
        yearProjections.reduce(0) { $0 + $1.growth }
    }
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

    // MARK: - Projection State

    var projectionCurrentAge: Int = 30
    var projectionRetirementAge: Int = 65
    var projectionCustomGrowthRate: Double = 5.0
    var projectionAdditionalContribution: Double = 0
    var projectionScenarios: [PensionProjectionScenario] = []
    var selectedScenarioBands: Set<PensionGrowthBand> = [.conservative, .moderate, .aggressive]

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

    // MARK: - Projection Engine

    static func generateProjection(
        currentValue: Double,
        monthlyContribution: Double,
        annualGrowthRate: Double,
        currentAge: Int,
        retirementAge: Int
    ) -> [PensionYearProjection] {
        guard retirementAge > currentAge else { return [] }

        let monthlyRate = annualGrowthRate / 100.0 / 12.0
        var projections: [PensionYearProjection] = []
        var runningValue = currentValue
        let currentYear = Calendar.current.component(.year, from: Date())

        for yearOffset in 0..<(retirementAge - currentAge) {
            let yearStart = runningValue
            var yearContributions = 0.0
            var yearGrowth = 0.0

            for _ in 0..<12 {
                let monthGrowth = runningValue * monthlyRate
                yearGrowth += monthGrowth
                runningValue += monthGrowth
                runningValue += monthlyContribution
                yearContributions += monthlyContribution
            }

            let projection = PensionYearProjection(
                year: currentYear + yearOffset,
                age: currentAge + yearOffset,
                startValue: yearStart,
                contributions: yearContributions,
                growth: yearGrowth
            )
            projections.append(projection)
        }

        return projections
    }

    func calculateProjections() {
        let currentVal = Double(truncating: currentValue as NSNumber)

        // Derive average monthly contribution from history
        var avgMonthlyContribution: Double = 0
        if !contributionHistory.isEmpty {
            let totalMonthly = contributionHistory.reduce(0.0) { $0 + $1.total }
            avgMonthlyContribution = totalMonthly / Double(contributionHistory.count)
        }
        let totalMonthly = avgMonthlyContribution + projectionAdditionalContribution

        var scenarios: [PensionProjectionScenario] = []
        for band in selectedScenarioBands.sorted(by: { $0.annualRate < $1.annualRate }) {
            let rate = band == .custom ? projectionCustomGrowthRate : band.annualRate
            let yearProjections = PensionViewModel.generateProjection(
                currentValue: currentVal,
                monthlyContribution: totalMonthly,
                annualGrowthRate: rate,
                currentAge: projectionCurrentAge,
                retirementAge: projectionRetirementAge
            )
            scenarios.append(PensionProjectionScenario(
                band: band,
                annualGrowthRate: rate,
                monthlyContribution: totalMonthly,
                yearProjections: yearProjections
            ))
        }
        projectionScenarios = scenarios
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
        calculateProjections()
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
