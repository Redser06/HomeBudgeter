//
//  PensionViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

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
}
