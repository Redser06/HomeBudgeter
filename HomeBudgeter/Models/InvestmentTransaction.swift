import Foundation
import SwiftData

enum InvestmentTransactionType: String, Codable, CaseIterable, Identifiable {
    case buy = "Buy"
    case sell = "Sell"

    var id: String { rawValue }
}

@Model
final class InvestmentTransaction {
    @Attribute(.unique) var id: UUID
    var transactionType: InvestmentTransactionType
    var quantity: Decimal
    var pricePerUnit: Decimal
    var fees: Decimal
    var date: Date
    var notes: String?
    var createdAt: Date

    var investment: Investment?

    init(
        transactionType: InvestmentTransactionType,
        quantity: Decimal,
        pricePerUnit: Decimal,
        fees: Decimal = 0,
        date: Date = Date(),
        notes: String? = nil
    ) {
        self.id = UUID()
        self.transactionType = transactionType
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.fees = fees
        self.date = date
        self.notes = notes
        self.createdAt = Date()
    }

    var totalAmount: Decimal {
        (quantity * pricePerUnit) + fees
    }
}
