import Foundation
import SwiftData

@Model
final class PensionData {
    @Attribute(.unique) var id: UUID
    var currentValue: Decimal
    var totalEmployeeContributions: Decimal
    var totalEmployerContributions: Decimal
    var totalInvestmentReturns: Decimal
    var retirementGoal: Decimal?
    var targetRetirementAge: Int?
    var lastUpdated: Date
    var provider: String?
    var notes: String?
    var createdAt: Date

    init(
        currentValue: Decimal = 0,
        totalEmployeeContributions: Decimal = 0,
        totalEmployerContributions: Decimal = 0,
        totalInvestmentReturns: Decimal = 0,
        retirementGoal: Decimal? = nil,
        targetRetirementAge: Int? = nil,
        provider: String? = nil
    ) {
        self.id = UUID()
        self.currentValue = currentValue
        self.totalEmployeeContributions = totalEmployeeContributions
        self.totalEmployerContributions = totalEmployerContributions
        self.totalInvestmentReturns = totalInvestmentReturns
        self.retirementGoal = retirementGoal
        self.targetRetirementAge = targetRetirementAge
        self.provider = provider
        self.lastUpdated = Date()
        self.createdAt = Date()
    }

    var totalContributions: Decimal {
        totalEmployeeContributions + totalEmployerContributions
    }

    var returnPercentage: Double {
        guard totalContributions > 0 else { return 0 }
        return Double(truncating: (totalInvestmentReturns / totalContributions) as NSNumber) * 100
    }

    var progressToGoal: Double? {
        guard let goal = retirementGoal, goal > 0 else { return nil }
        return Double(truncating: (currentValue / goal) as NSNumber) * 100
    }

    func updateFromPayslip(_ payslip: Payslip) {
        totalEmployeeContributions += payslip.pensionContribution
        totalEmployerContributions += payslip.employerPensionContribution
        lastUpdated = Date()
    }
}
