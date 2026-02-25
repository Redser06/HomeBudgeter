import Foundation
import SwiftData

@Model
final class Payslip {
    @Attribute(.unique) var id: UUID
    var payDate: Date
    var payPeriodStart: Date
    var payPeriodEnd: Date
    var grossPay: Decimal
    var netPay: Decimal
    var incomeTax: Decimal
    var socialInsurance: Decimal
    var universalCharge: Decimal?
    var pensionContribution: Decimal
    var employerPensionContribution: Decimal
    var otherDeductions: Decimal
    var healthInsurancePremium: Decimal
    var employer: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date = Date()

    var member: HouseholdMember?

    @Relationship(deleteRule: .nullify, inverse: \Document.linkedPayslip)
    var sourceDocument: Document?

    init(
        payDate: Date,
        payPeriodStart: Date,
        payPeriodEnd: Date,
        grossPay: Decimal,
        netPay: Decimal,
        incomeTax: Decimal,
        socialInsurance: Decimal,
        universalCharge: Decimal? = nil,
        pensionContribution: Decimal = 0,
        employerPensionContribution: Decimal = 0,
        otherDeductions: Decimal = 0,
        healthInsurancePremium: Decimal = 0,
        employer: String? = nil
    ) {
        self.id = UUID()
        self.payDate = payDate
        self.payPeriodStart = payPeriodStart
        self.payPeriodEnd = payPeriodEnd
        self.grossPay = grossPay
        self.netPay = netPay
        self.incomeTax = incomeTax
        self.socialInsurance = socialInsurance
        self.universalCharge = universalCharge
        self.pensionContribution = pensionContribution
        self.employerPensionContribution = employerPensionContribution
        self.otherDeductions = otherDeductions
        self.healthInsurancePremium = healthInsurancePremium
        self.employer = employer
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var totalDeductions: Decimal {
        incomeTax + socialInsurance + (universalCharge ?? 0) + pensionContribution + otherDeductions + healthInsurancePremium
    }

    var totalPensionContribution: Decimal {
        pensionContribution + employerPensionContribution
    }

    var formattedPayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: payDate)
    }

    var payPeriodDescription: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: payPeriodStart)) - \(formatter.string(from: payPeriodEnd))"
    }
}
