import XCTest
import SwiftData
@testable import Home_Budgeter

final class InvestmentViewModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: InvestmentViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Account.self,
            Document.self,
            SavingsGoal.self,
            Payslip.self,
            PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self,
            HouseholdMember.self,
            Investment.self,
            InvestmentTransaction.self,
            SyncQueueEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        viewModel = InvestmentViewModel()
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Load

    @MainActor
    func testLoadDataEmpty() {
        viewModel.loadData(modelContext: modelContext)
        XCTAssertTrue(viewModel.investments.isEmpty)
        XCTAssertEqual(viewModel.totalPortfolioValue, 0)
    }

    @MainActor
    func testLoadDataWithInvestments() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)
        try! modelContext.save()

        viewModel.loadData(modelContext: modelContext)
        XCTAssertEqual(viewModel.investments.count, 1)
    }

    // MARK: - Add Investment

    @MainActor
    func testAddInvestment() {
        viewModel.addInvestment(
            symbol: "aapl",
            name: "Apple Inc.",
            assetType: .stock,
            currencyCode: "USD",
            account: nil,
            owner: nil,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.investments.count, 1)
        XCTAssertEqual(viewModel.investments[0].symbol, "AAPL") // uppercased
        XCTAssertEqual(viewModel.investments[0].name, "Apple Inc.")
        XCTAssertEqual(viewModel.investments[0].currencyCode, "USD")
    }

    @MainActor
    func testAddInvestmentWithOwner() {
        let member = HouseholdMember(name: "Alice")
        modelContext.insert(member)
        try! modelContext.save()

        viewModel.addInvestment(
            symbol: "MSFT",
            name: "Microsoft",
            assetType: .stock,
            currencyCode: "EUR",
            account: nil,
            owner: member,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.investments[0].owner?.name, "Alice")
    }

    // MARK: - Delete Investment

    @MainActor
    func testDeleteInvestment() {
        viewModel.addInvestment(
            symbol: "AAPL",
            name: "Apple",
            assetType: .stock,
            currencyCode: "EUR",
            account: nil,
            owner: nil,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.investments.count, 1)
        viewModel.deleteInvestment(viewModel.investments[0], modelContext: modelContext)
        XCTAssertTrue(viewModel.investments.isEmpty)
    }

    // MARK: - Add Transaction

    @MainActor
    func testAddTransaction() {
        viewModel.addInvestment(
            symbol: "AAPL",
            name: "Apple",
            assetType: .stock,
            currencyCode: "EUR",
            account: nil,
            owner: nil,
            modelContext: modelContext
        )

        let inv = viewModel.investments[0]
        viewModel.addTransaction(
            to: inv,
            type: .buy,
            quantity: Decimal(string: "10")!,
            pricePerUnit: Decimal(string: "150")!,
            fees: Decimal(string: "5")!,
            date: Date(),
            notes: "First buy",
            modelContext: modelContext
        )

        let refreshed = viewModel.investments[0]
        XCTAssertEqual(refreshed.transactions?.count, 1)
        XCTAssertEqual(refreshed.totalQuantity, Decimal(string: "10")!)
    }

    // MARK: - Update Price

    @MainActor
    func testUpdatePrice() {
        viewModel.addInvestment(
            symbol: "AAPL",
            name: "Apple",
            assetType: .stock,
            currencyCode: "EUR",
            account: nil,
            owner: nil,
            modelContext: modelContext
        )

        let inv = viewModel.investments[0]
        viewModel.updatePrice(for: inv, price: Decimal(string: "175")!, modelContext: modelContext)

        let refreshed = viewModel.investments[0]
        XCTAssertEqual(refreshed.latestPrice, Decimal(string: "175")!)
        XCTAssertEqual(refreshed.priceHistory.count, 1)
    }

    // MARK: - Portfolio Summary

    @MainActor
    func testPortfolioValueAndGainLoss() {
        viewModel.addInvestment(
            symbol: "AAPL",
            name: "Apple",
            assetType: .stock,
            currencyCode: "EUR",
            account: nil,
            owner: nil,
            modelContext: modelContext
        )

        let inv = viewModel.investments[0]
        viewModel.addTransaction(
            to: inv,
            type: .buy,
            quantity: Decimal(string: "10")!,
            pricePerUnit: Decimal(string: "100")!,
            fees: 0,
            date: Date(),
            notes: nil,
            modelContext: modelContext
        )

        viewModel.updatePrice(for: inv, price: Decimal(string: "120")!, modelContext: modelContext)

        // Portfolio value = 10 * 120 = 1200
        XCTAssertEqual(viewModel.totalPortfolioValue, Decimal(string: "1200")!)
        // Cost basis = 10 * 100 = 1000
        XCTAssertEqual(viewModel.totalCostBasis, Decimal(string: "1000")!)
        // Gain = 200
        XCTAssertEqual(viewModel.totalGainLoss, Decimal(string: "200")!)
        // Return = 20%
        XCTAssertEqual(viewModel.totalGainLossPercentage, 20.0, accuracy: 0.01)
    }

    // MARK: - Member Filtering

    @MainActor
    func testFilterByMember() {
        let alice = HouseholdMember(name: "Alice")
        let bob = HouseholdMember(name: "Bob")
        modelContext.insert(alice)
        modelContext.insert(bob)
        try! modelContext.save()

        viewModel.addInvestment(symbol: "AAPL", name: "Apple", assetType: .stock, currencyCode: "EUR", account: nil, owner: alice, modelContext: modelContext)
        viewModel.addInvestment(symbol: "MSFT", name: "Microsoft", assetType: .stock, currencyCode: "EUR", account: nil, owner: bob, modelContext: modelContext)

        XCTAssertEqual(viewModel.filteredInvestments.count, 2)

        viewModel.selectedMember = alice
        XCTAssertEqual(viewModel.filteredInvestments.count, 1)
        XCTAssertEqual(viewModel.filteredInvestments[0].symbol, "AAPL")

        viewModel.selectedMember = nil
        XCTAssertEqual(viewModel.filteredInvestments.count, 2)
    }

    // MARK: - Allocation Data

    @MainActor
    func testAllocationDataEmpty() {
        viewModel.loadData(modelContext: modelContext)
        XCTAssertTrue(viewModel.allocationData.isEmpty)
    }

    @MainActor
    func testAllocationDataWithInvestments() {
        viewModel.addInvestment(symbol: "AAPL", name: "Apple", assetType: .stock, currencyCode: "EUR", account: nil, owner: nil, modelContext: modelContext)

        let inv = viewModel.investments[0]
        viewModel.addTransaction(to: inv, type: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "100")!, fees: 0, date: Date(), notes: nil, modelContext: modelContext)
        viewModel.updatePrice(for: inv, price: Decimal(string: "100")!, modelContext: modelContext)

        let allocation = viewModel.allocationData
        XCTAssertEqual(allocation.count, 1)
        XCTAssertEqual(allocation[0].name, "AAPL")
        XCTAssertEqual(allocation[0].percentage, 100.0, accuracy: 0.01)
    }

    // MARK: - Delete Transaction

    @MainActor
    func testDeleteTransaction() {
        viewModel.addInvestment(symbol: "AAPL", name: "Apple", assetType: .stock, currencyCode: "EUR", account: nil, owner: nil, modelContext: modelContext)

        let inv = viewModel.investments[0]
        viewModel.addTransaction(to: inv, type: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "100")!, fees: 0, date: Date(), notes: nil, modelContext: modelContext)

        let txs = try! modelContext.fetch(FetchDescriptor<InvestmentTransaction>())
        XCTAssertEqual(txs.count, 1)

        viewModel.deleteTransaction(txs[0], modelContext: modelContext)

        let remaining = try! modelContext.fetch(FetchDescriptor<InvestmentTransaction>())
        XCTAssertTrue(remaining.isEmpty)
    }
}
