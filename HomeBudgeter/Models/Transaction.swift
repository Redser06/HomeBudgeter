import Foundation
import SwiftData

enum TransactionType: String, Codable {
    case income = "Income"
    case expense = "Expense"
    case transfer = "Transfer"
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var date: Date
    var descriptionText: String
    var type: TransactionType
    var isRecurring: Bool
    var recurringFrequency: RecurringFrequency?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var category: BudgetCategory?
    var account: Account?
    var linkedDocument: Document?
    var parentTemplate: RecurringTemplate?

    init(
        amount: Decimal,
        date: Date = Date(),
        descriptionText: String,
        type: TransactionType = .expense,
        isRecurring: Bool = false,
        recurringFrequency: RecurringFrequency? = nil,
        notes: String? = nil,
        category: BudgetCategory? = nil,
        account: Account? = nil
    ) {
        self.id = UUID()
        self.amount = amount
        self.date = date
        self.descriptionText = descriptionText
        self.type = type
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.notes = notes
        self.category = category
        self.account = account
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: amount as NSNumber) ?? "€0.00"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    case yearly = "Yearly"
}
