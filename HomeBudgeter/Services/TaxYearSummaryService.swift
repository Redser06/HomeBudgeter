//
//  TaxYearSummaryService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

// MARK: - Data Structures

struct TaxYearSummary {
    let year: Int
    let locale: AppLocale
    let payslipCount: Int

    // Totals
    let grossIncome: Decimal
    let incomeTax: Decimal
    let socialInsurance: Decimal
    let universalCharge: Decimal
    let pensionEmployee: Decimal
    let pensionEmployer: Decimal
    let otherDeductions: Decimal
    let netIncome: Decimal

    // Rates
    let effectiveRate: Double
    let marginalRate: Double

    // Monthly breakdown
    let monthlyData: [MonthlyTaxData]

    // YoY comparison
    let previousYear: TaxYearComparison?
}

struct MonthlyTaxData: Identifiable {
    let id = UUID()
    let month: String
    let monthIndex: Int
    let gross: Decimal
    let tax: Decimal
    let net: Decimal
}

struct TaxYearComparison {
    let previousGross: Decimal
    let previousNet: Decimal
    let previousEffectiveRate: Double
    let grossChange: Double // percentage
    let netChange: Double
    let rateChange: Double // absolute change in percentage points
}

// MARK: - Service

class TaxYearSummaryService {
    static let shared = TaxYearSummaryService()
    private init() {}

    @MainActor
    func generateSummary(year: Int, modelContext: ModelContext, locale: AppLocale) throws -> TaxYearSummary {
        let calendar = Calendar.current

        // Tax year: Jan 1 – Dec 31 for IE/UK/US (simplified)
        let startComponents = DateComponents(year: year, month: 1, day: 1)
        let endComponents = DateComponents(year: year, month: 12, day: 31)

        guard let yearStart = calendar.date(from: startComponents),
              let yearEnd = calendar.date(from: endComponents) else {
            throw TaxYearError.invalidDateRange
        }

        let descriptor = FetchDescriptor<Payslip>(
            predicate: #Predicate<Payslip> {
                $0.payDate >= yearStart && $0.payDate <= yearEnd
            },
            sortBy: [SortDescriptor(\.payDate)]
        )
        let payslips = try modelContext.fetch(descriptor)

        let grossIncome = payslips.reduce(Decimal.zero) { $0 + $1.grossPay }
        let incomeTax = payslips.reduce(Decimal.zero) { $0 + $1.incomeTax }
        let socialInsurance = payslips.reduce(Decimal.zero) { $0 + $1.socialInsurance }
        let universalCharge = payslips.reduce(Decimal.zero) { $0 + ($1.universalCharge ?? 0) }
        let pensionEmployee = payslips.reduce(Decimal.zero) { $0 + $1.pensionContribution }
        let pensionEmployer = payslips.reduce(Decimal.zero) { $0 + $1.employerPensionContribution }
        let otherDeductions = payslips.reduce(Decimal.zero) { $0 + $1.otherDeductions }
        let netIncome = payslips.reduce(Decimal.zero) { $0 + $1.netPay }

        let totalDeductions = incomeTax + socialInsurance + universalCharge
        let effectiveRate = grossIncome > 0
            ? Double(truncating: (totalDeductions / grossIncome) as NSNumber) * 100
            : 0

        let marginalRate = TaxIntelligenceService.shared.estimatedMarginalRate(
            grossAnnual: grossIncome,
            locale: locale
        )

        // Monthly breakdown
        let monthlyData = buildMonthlyData(payslips: payslips, calendar: calendar)

        // Previous year comparison
        let previousYear = try? buildComparison(
            currentGross: grossIncome,
            currentNet: netIncome,
            currentRate: effectiveRate,
            previousYearInt: year - 1,
            modelContext: modelContext,
            locale: locale
        )

        return TaxYearSummary(
            year: year,
            locale: locale,
            payslipCount: payslips.count,
            grossIncome: grossIncome,
            incomeTax: incomeTax,
            socialInsurance: socialInsurance,
            universalCharge: universalCharge,
            pensionEmployee: pensionEmployee,
            pensionEmployer: pensionEmployer,
            otherDeductions: otherDeductions,
            netIncome: netIncome,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate,
            monthlyData: monthlyData,
            previousYear: previousYear
        )
    }

    @MainActor
    func availableYears(modelContext: ModelContext) throws -> [Int] {
        let descriptor = FetchDescriptor<Payslip>(
            sortBy: [SortDescriptor(\.payDate)]
        )
        let payslips = try modelContext.fetch(descriptor)
        let years = Set(payslips.map { Calendar.current.component(.year, from: $0.payDate) })
        return years.sorted().reversed()
    }

    // MARK: - Private

    private func buildMonthlyData(payslips: [Payslip], calendar: Calendar) -> [MonthlyTaxData] {
        let grouped = Dictionary(grouping: payslips) { payslip in
            calendar.component(.month, from: payslip.payDate)
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"

        return (1...12).compactMap { month in
            let slips = grouped[month] ?? []
            guard !slips.isEmpty else { return nil }

            let gross = slips.reduce(Decimal.zero) { $0 + $1.grossPay }
            let tax = slips.reduce(Decimal.zero) { $0 + $1.incomeTax + $1.socialInsurance + ($1.universalCharge ?? 0) }
            let net = slips.reduce(Decimal.zero) { $0 + $1.netPay }

            var components = DateComponents()
            components.month = month
            let monthDate = calendar.date(from: components) ?? Date()
            let monthName = monthFormatter.string(from: monthDate)

            return MonthlyTaxData(
                month: monthName,
                monthIndex: month,
                gross: gross,
                tax: tax,
                net: net
            )
        }
    }

    @MainActor
    private func buildComparison(
        currentGross: Decimal,
        currentNet: Decimal,
        currentRate: Double,
        previousYearInt: Int,
        modelContext: ModelContext,
        locale: AppLocale
    ) throws -> TaxYearComparison? {
        let calendar = Calendar.current
        let startComponents = DateComponents(year: previousYearInt, month: 1, day: 1)
        let endComponents = DateComponents(year: previousYearInt, month: 12, day: 31)

        guard let prevStart = calendar.date(from: startComponents),
              let prevEnd = calendar.date(from: endComponents) else { return nil }

        let descriptor = FetchDescriptor<Payslip>(
            predicate: #Predicate<Payslip> {
                $0.payDate >= prevStart && $0.payDate <= prevEnd
            }
        )
        let prevPayslips = try modelContext.fetch(descriptor)
        guard !prevPayslips.isEmpty else { return nil }

        let prevGross = prevPayslips.reduce(Decimal.zero) { $0 + $1.grossPay }
        let prevNet = prevPayslips.reduce(Decimal.zero) { $0 + $1.netPay }
        let prevTax = prevPayslips.reduce(Decimal.zero) { $0 + $1.incomeTax + $1.socialInsurance + ($1.universalCharge ?? 0) }
        let prevRate = prevGross > 0
            ? Double(truncating: (prevTax / prevGross) as NSNumber) * 100
            : 0

        let grossChange = prevGross > 0
            ? Double(truncating: ((currentGross - prevGross) / prevGross) as NSNumber) * 100
            : 0
        let netChange = prevNet > 0
            ? Double(truncating: ((currentNet - prevNet) / prevNet) as NSNumber) * 100
            : 0

        return TaxYearComparison(
            previousGross: prevGross,
            previousNet: prevNet,
            previousEffectiveRate: prevRate,
            grossChange: grossChange,
            netChange: netChange,
            rateChange: currentRate - prevRate
        )
    }
}

enum TaxYearError: Error, LocalizedError {
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .invalidDateRange: return "Could not construct valid date range for tax year"
        }
    }
}
