//
//  RecurringTemplate.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@Model
final class RecurringTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var type: TransactionType
    var frequency: RecurringFrequency
    var startDate: Date
    var endDate: Date?
    var nextDueDate: Date
    var lastProcessedDate: Date?
    var isActive: Bool
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    // Relationships
    var category: BudgetCategory?
    var account: Account?
    @Relationship(deleteRule: .cascade) var generatedTransactions: [Transaction] = []

    init(
        name: String,
        amount: Decimal,
        type: TransactionType = .expense,
        frequency: RecurringFrequency,
        startDate: Date = Date(),
        endDate: Date? = nil,
        nextDueDate: Date? = nil,
        isActive: Bool = true,
        notes: String? = nil,
        category: BudgetCategory? = nil,
        account: Account? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.type = type
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.nextDueDate = nextDueDate ?? startDate
        self.lastProcessedDate = nil
        self.isActive = isActive
        self.notes = notes
        self.category = category
        self.account = account
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var isOverdue: Bool {
        nextDueDate < Date() && isActive
    }

    var daysUntilDue: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: nextDueDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDue)
        return components.day ?? 0
    }

    var formattedAmount: String {
        CurrencyFormatter.shared.format(amount)
    }

    var monthlyEquivalentAmount: Decimal {
        switch frequency {
        case .daily: return amount * 30
        case .weekly: return amount * 4
        case .biweekly: return amount * 2
        case .monthly: return amount
        case .quarterly: return amount / 3
        case .yearly: return amount / 12
        }
    }
}
