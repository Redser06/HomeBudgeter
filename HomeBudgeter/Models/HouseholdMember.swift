import Foundation
import SwiftData
import SwiftUI

@Model
final class HouseholdMember {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Account.owner)
    var accounts: [Account]?

    @Relationship(deleteRule: .nullify, inverse: \Payslip.member)
    var payslips: [Payslip]?

    @Relationship(deleteRule: .nullify, inverse: \PensionData.member)
    var pensions: [PensionData]?

    @Relationship(deleteRule: .nullify, inverse: \SavingsGoal.member)
    var savingsGoals: [SavingsGoal]?

    @Relationship(deleteRule: .nullify, inverse: \Investment.owner)
    var investments: [Investment]?

    init(
        name: String,
        colorHex: String = "#007AFF",
        icon: String = "person.circle.fill",
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
