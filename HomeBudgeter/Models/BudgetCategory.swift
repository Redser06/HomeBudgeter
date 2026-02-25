import Foundation
import SwiftData
import SwiftUI

enum CategoryType: String, Codable, CaseIterable {
    case housing = "Housing"
    case utilities = "Utilities"
    case groceries = "Groceries"
    case transport = "Transport"
    case healthcare = "Healthcare"
    case entertainment = "Entertainment"
    case dining = "Dining"
    case shopping = "Shopping"
    case personal = "Personal"
    case savings = "Savings"
    case childcare = "Childcare"
    case subscriptions = "Subscriptions"
    case other = "Other"

    var icon: String {
        switch self {
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .groceries: return "cart.fill"
        case .transport: return "car.fill"
        case .healthcare: return "cross.case.fill"
        case .entertainment: return "tv.fill"
        case .dining: return "fork.knife"
        case .shopping: return "bag.fill"
        case .personal: return "person.fill"
        case .savings: return "banknote.fill"
        case .childcare: return "figure.and.child.holdinghands"
        case .subscriptions: return "creditcard.and.123"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .housing: return Color(red: 233/255, green: 30/255, blue: 99/255)        // #E91E63 Pink
        case .utilities: return Color(red: 156/255, green: 39/255, blue: 176/255)     // #9C27B0 Purple
        case .groceries: return Color(red: 76/255, green: 175/255, blue: 80/255)      // #4CAF50 Green
        case .transport: return Color(red: 255/255, green: 152/255, blue: 0/255)      // #FF9800 Orange
        case .healthcare: return Color(red: 244/255, green: 67/255, blue: 54/255)     // #F44336 Red
        case .entertainment: return Color(red: 156/255, green: 39/255, blue: 176/255) // #9C27B0 Purple
        case .dining: return Color(red: 255/255, green: 87/255, blue: 34/255)         // #FF5722 Deep Orange
        case .shopping: return Color(red: 63/255, green: 81/255, blue: 181/255)       // #3F51B5 Indigo
        case .personal: return Color(red: 0/255, green: 188/255, blue: 212/255)       // #00BCD4 Cyan
        case .savings: return Color(red: 139/255, green: 195/255, blue: 74/255)       // #8BC34A Light Green
        case .childcare: return Color(red: 255/255, green: 183/255, blue: 77/255)     // #FFB74D Amber
        case .subscriptions: return Color(red: 171/255, green: 71/255, blue: 188/255) // #AB47BC Purple
        case .other: return Color(red: 96/255, green: 125/255, blue: 139/255)         // #607D8B Blue Gray
        }
    }

    var order: Int {
        switch self {
        case .housing: return 0
        case .utilities: return 1
        case .groceries: return 2
        case .transport: return 3
        case .healthcare: return 4
        case .entertainment: return 5
        case .dining: return 6
        case .shopping: return 7
        case .personal: return 8
        case .savings: return 9
        case .childcare: return 10
        case .subscriptions: return 11
        case .other: return 12
        }
    }
}

@Model
final class BudgetCategory {
    @Attribute(.unique) var id: UUID
    var type: CategoryType
    var budgetAmount: Decimal
    var spentAmount: Decimal
    var period: BudgetPeriod
    var isActive: Bool
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Transaction.category)
    var transactions: [Transaction]?

    init(
        type: CategoryType,
        budgetAmount: Decimal = 0,
        spentAmount: Decimal = 0,
        period: BudgetPeriod = .monthly,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.type = type
        self.budgetAmount = budgetAmount
        self.spentAmount = spentAmount
        self.period = period
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var remainingAmount: Decimal {
        budgetAmount - spentAmount
    }

    var percentageUsed: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(truncating: (spentAmount / budgetAmount) as NSNumber) * 100
    }

    var isOverBudget: Bool {
        spentAmount > budgetAmount
    }

    var statusColor: Color {
        let percentage = percentageUsed
        if percentage >= 90 { return Color(red: 239/255, green: 68/255, blue: 68/255) }   // #EF4444 Danger Red
        if percentage >= 75 { return Color(red: 245/255, green: 158/255, blue: 11/255) }  // #F59E0B Warning Amber
        return Color(red: 34/255, green: 197/255, blue: 94/255)                            // #22C55E Success Green
    }
}

enum BudgetPeriod: String, Codable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
}
