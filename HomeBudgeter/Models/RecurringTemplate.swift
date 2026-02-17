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
    var isVariableAmount: Bool
    var isAutoPay: Bool
    var createdAt: Date
    var updatedAt: Date

    // Price history for tracking increases (JSON-encoded)
    var priceHistoryData: Data?

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
        isVariableAmount: Bool = false,
        isAutoPay: Bool = false,
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
        self.isVariableAmount = isVariableAmount
        self.isAutoPay = isAutoPay
        self.notes = notes
        self.category = category
        self.account = account
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Computed Properties

    var isOverdue: Bool {
        nextDueDate < Date() && isActive && !isAutoPay
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

    // MARK: - Price History

    struct PriceEntry: Codable {
        let date: Date
        let amount: String // Stored as string for Decimal precision
    }

    var priceHistory: [PriceEntry] {
        get {
            guard let data = priceHistoryData else { return [] }
            return (try? JSONDecoder().decode([PriceEntry].self, from: data)) ?? []
        }
        set {
            priceHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    func recordPrice(_ amount: Decimal, date: Date = Date()) {
        var history = priceHistory
        history.append(PriceEntry(date: date, amount: "\(amount)"))
        priceHistory = history
    }

    /// Returns true if the last 2-3 recorded prices show a sustained increase (> 5% cumulative).
    var hasPriceIncrease: Bool {
        let history = priceHistory
        guard history.count >= 2 else { return false }

        let recent = Array(history.suffix(3))
        guard let firstAmount = Decimal(string: recent.first!.amount),
              let lastAmount = Decimal(string: recent.last!.amount),
              firstAmount > 0 else { return false }

        let change = (lastAmount - firstAmount) / firstAmount
        return change > Decimal(string: "0.05")!
    }

    /// The percentage increase from first to last recorded price.
    var priceIncreasePercentage: Double? {
        let history = priceHistory
        guard history.count >= 2,
              let first = Decimal(string: history.first!.amount),
              let last = Decimal(string: history.last!.amount),
              first > 0 else { return nil }

        return Double(truncating: ((last - first) / first) as NSNumber) * 100
    }
}
