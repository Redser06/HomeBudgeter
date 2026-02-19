import Foundation
import SwiftData
import SwiftUI

enum GoalPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal
    var currentAmount: Decimal
    var deadline: Date?
    var priority: GoalPriority
    var icon: String
    var notes: String?
    var isCompleted: Bool
    var member: HouseholdMember?
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        deadline: Date? = nil,
        priority: GoalPriority = .medium,
        icon: String = "target",
        notes: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.deadline = deadline
        self.priority = priority
        self.icon = icon
        self.notes = notes
        self.isCompleted = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var progressPercentage: Double {
        guard targetAmount > 0 else { return 0 }
        return min(Double(truncating: (currentAmount / targetAmount) as NSNumber) * 100, 100)
    }

    var remainingAmount: Decimal {
        max(targetAmount - currentAmount, 0)
    }

    var daysRemaining: Int? {
        guard let deadline = deadline else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        return components.day
    }

    var monthlyContributionNeeded: Decimal? {
        guard let days = daysRemaining, days > 0 else { return nil }
        let months = Decimal(days) / 30
        guard months > 0 else { return remainingAmount }
        return remainingAmount / months
    }
}
