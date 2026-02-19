import Foundation
import SwiftData

enum AssetType: String, Codable, CaseIterable, Identifiable {
    case stock = "Stock"
    case etf = "ETF"
    case fund = "Fund"
    case crypto = "Crypto"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .etf: return "chart.bar.fill"
        case .fund: return "building.columns"
        case .crypto: return "bitcoinsign.circle"
        }
    }
}

struct PriceEntry: Codable, Equatable {
    let date: Date
    let price: Decimal
}

@Model
final class Investment {
    @Attribute(.unique) var id: UUID
    var symbol: String
    var name: String
    var assetType: AssetType
    var currencyCode: String
    var notes: String?
    var priceHistoryData: Data?
    var createdAt: Date
    var updatedAt: Date

    var owner: HouseholdMember?
    var account: Account?

    @Relationship(deleteRule: .cascade, inverse: \InvestmentTransaction.investment)
    var transactions: [InvestmentTransaction]?

    init(
        symbol: String,
        name: String,
        assetType: AssetType = .stock,
        currencyCode: String = "EUR",
        notes: String? = nil
    ) {
        self.id = UUID()
        self.symbol = symbol
        self.name = name
        self.assetType = assetType
        self.currencyCode = currencyCode
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - Price History

    var priceHistory: [PriceEntry] {
        get {
            guard let data = priceHistoryData else { return [] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return (try? decoder.decode([PriceEntry].self, from: data)) ?? []
        }
        set {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            priceHistoryData = try? encoder.encode(newValue)
            updatedAt = Date()
        }
    }

    var latestPrice: Decimal? {
        priceHistory.sorted(by: { $0.date > $1.date }).first?.price
    }

    func addPrice(_ price: Decimal, on date: Date = Date()) {
        var history = priceHistory
        history.append(PriceEntry(date: date, price: price))
        priceHistory = history
    }

    // MARK: - Computed Properties

    var sortedTransactions: [InvestmentTransaction] {
        (transactions ?? []).sorted { $0.date < $1.date }
    }

    var totalQuantity: Decimal {
        (transactions ?? []).reduce(Decimal.zero) { result, tx in
            switch tx.transactionType {
            case .buy: return result + tx.quantity
            case .sell: return result - tx.quantity
            }
        }
    }

    var totalCostBasis: Decimal {
        (transactions ?? []).reduce(Decimal.zero) { result, tx in
            switch tx.transactionType {
            case .buy: return result + tx.totalAmount
            case .sell: return result - (tx.quantity * averageCostBasis)
            }
        }
    }

    var averageCostBasis: Decimal {
        let buys = (transactions ?? []).filter { $0.transactionType == .buy }
        let totalBuyQty = buys.reduce(Decimal.zero) { $0 + $1.quantity }
        guard totalBuyQty > 0 else { return 0 }
        let totalBuyCost = buys.reduce(Decimal.zero) { $0 + ($1.quantity * $1.pricePerUnit) }
        return totalBuyCost / totalBuyQty
    }

    var currentValue: Decimal {
        guard let price = latestPrice else { return 0 }
        return totalQuantity * price
    }

    var totalGainLoss: Decimal {
        guard latestPrice != nil else { return 0 }
        return currentValue - totalCostBasis
    }

    var gainLossPercentage: Double {
        guard totalCostBasis > 0 else { return 0 }
        return Double(truncating: (totalGainLoss / totalCostBasis) as NSNumber) * 100
    }

    var totalFees: Decimal {
        (transactions ?? []).reduce(Decimal.zero) { $0 + $1.fees }
    }
}
