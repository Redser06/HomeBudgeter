import Foundation
import SwiftData
import SwiftUI

@Observable
class InvestmentViewModel {
    var investments: [Investment] = []
    var showingAddInvestment: Bool = false
    var selectedInvestment: Investment?
    var showingAddTransaction: Bool = false
    var selectedMember: HouseholdMember?
    var householdMembers: [HouseholdMember] = []

    // MARK: - Filtered

    var filteredInvestments: [Investment] {
        guard let member = selectedMember else { return investments }
        return investments.filter { $0.owner?.id == member.id }
    }

    // MARK: - Portfolio Summary

    var totalPortfolioValue: Decimal {
        filteredInvestments.reduce(Decimal.zero) { $0 + $1.currentValue }
    }

    var totalCostBasis: Decimal {
        filteredInvestments.reduce(Decimal.zero) { $0 + $1.totalCostBasis }
    }

    var totalGainLoss: Decimal {
        filteredInvestments.reduce(Decimal.zero) { $0 + $1.totalGainLoss }
    }

    var totalGainLossPercentage: Double {
        guard totalCostBasis > 0 else { return 0 }
        return Double(truncating: (totalGainLoss / totalCostBasis) as NSNumber) * 100
    }

    var totalFees: Decimal {
        filteredInvestments.reduce(Decimal.zero) { $0 + $1.totalFees }
    }

    // MARK: - Allocation Data

    struct AllocationEntry: Identifiable {
        let id = UUID()
        let name: String
        let value: Double
        let percentage: Double
    }

    var allocationData: [AllocationEntry] {
        let total = Double(truncating: totalPortfolioValue as NSNumber)
        guard total > 0 else { return [] }

        return filteredInvestments
            .filter { $0.currentValue > 0 }
            .map { investment in
                let value = Double(truncating: investment.currentValue as NSNumber)
                return AllocationEntry(
                    name: investment.symbol,
                    value: value,
                    percentage: (value / total) * 100
                )
            }
            .sorted { $0.value > $1.value }
    }

    // MARK: - Data Methods

    @MainActor
    func loadData(modelContext: ModelContext) {
        loadInvestments(modelContext: modelContext)
        loadHouseholdMembers(modelContext: modelContext)
    }

    @MainActor
    private func loadInvestments(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Investment>(
            sortBy: [SortDescriptor(\.symbol)]
        )

        do {
            investments = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading investments: \(error)")
        }
    }

    @MainActor
    private func loadHouseholdMembers(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<HouseholdMember>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            householdMembers = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading household members: \(error)")
        }
    }

    // MARK: - CRUD

    @MainActor
    func addInvestment(
        symbol: String,
        name: String,
        assetType: AssetType,
        currencyCode: String,
        account: Account?,
        owner: HouseholdMember?,
        modelContext: ModelContext
    ) {
        let investment = Investment(
            symbol: symbol.uppercased(),
            name: name,
            assetType: assetType,
            currencyCode: currencyCode
        )
        investment.account = account
        investment.owner = owner
        modelContext.insert(investment)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(investment, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "investments", recordId: investment.id, dto: dto, modelContext: modelContext) }
            }

            loadInvestments(modelContext: modelContext)
        } catch {
            print("Error adding investment: \(error)")
        }
    }

    @MainActor
    func deleteInvestment(_ investment: Investment, modelContext: ModelContext) {
        let recordId = investment.id
        modelContext.delete(investment)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                Task { await SyncService.shared.pushDelete(table: "investments", recordId: recordId, modelContext: modelContext) }
            }

            loadInvestments(modelContext: modelContext)
        } catch {
            print("Error deleting investment: \(error)")
        }
    }

    @MainActor
    func addTransaction(
        to investment: Investment,
        type: InvestmentTransactionType,
        quantity: Decimal,
        pricePerUnit: Decimal,
        fees: Decimal,
        date: Date,
        notes: String?,
        modelContext: ModelContext
    ) {
        let tx = InvestmentTransaction(
            transactionType: type,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            fees: fees,
            date: date,
            notes: notes
        )
        tx.investment = investment
        modelContext.insert(tx)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(tx, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "investment_transactions", recordId: tx.id, dto: dto, modelContext: modelContext) }
            }

            loadInvestments(modelContext: modelContext)
        } catch {
            print("Error adding investment transaction: \(error)")
        }
    }

    @MainActor
    func updatePrice(
        for investment: Investment,
        price: Decimal,
        on date: Date = Date(),
        modelContext: ModelContext
    ) {
        investment.addPrice(price, on: date)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(investment, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "investments", recordId: investment.id, dto: dto, modelContext: modelContext) }
            }

            loadInvestments(modelContext: modelContext)
        } catch {
            print("Error updating price: \(error)")
        }
    }

    @MainActor
    func deleteTransaction(
        _ transaction: InvestmentTransaction,
        modelContext: ModelContext
    ) {
        let recordId = transaction.id
        modelContext.delete(transaction)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                Task { await SyncService.shared.pushDelete(table: "investment_transactions", recordId: recordId, modelContext: modelContext) }
            }

            loadInvestments(modelContext: modelContext)
        } catch {
            print("Error deleting transaction: \(error)")
        }
    }
}
