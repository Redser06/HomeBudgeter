import Foundation
import SwiftData

enum AccountType: String, Codable, CaseIterable {
    case checking = "Checking"
    case savings = "Savings"
    case credit = "Credit Card"
    case investment = "Investment"
    case pension = "Pension"
    case cash = "Cash"
    case other = "Other"

    var icon: String {
        switch self {
        case .checking: return "building.columns.fill"
        case .savings: return "banknote.fill"
        case .credit: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .pension: return "clock.fill"
        case .cash: return "dollarsign.circle.fill"
        case .other: return "folder.fill"
        }
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var type: AccountType
    var balance: Decimal
    var currencyCode: String
    var isActive: Bool
    var institution: String?
    var accountNumber: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction]?

    init(
        name: String,
        type: AccountType,
        balance: Decimal = 0,
        currencyCode: String = "EUR",
        isActive: Bool = true,
        institution: String? = nil,
        accountNumber: String? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.balance = balance
        self.currencyCode = currencyCode
        self.isActive = isActive
        self.institution = institution
        self.accountNumber = accountNumber
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var isAsset: Bool {
        switch type {
        case .checking, .savings, .investment, .pension, .cash:
            return true
        case .credit, .other:
            return balance >= 0
        }
    }
}
