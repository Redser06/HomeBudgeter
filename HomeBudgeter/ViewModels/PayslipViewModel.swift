//
//  PayslipViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class PayslipViewModel {
    var payslips: [Payslip] = []
    var showingCreateSheet: Bool = false
    var selectedPayslip: Payslip?
    var filterYear: Int = Calendar.current.component(.year, from: Date())
    var filterEmployer: String?

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
}
