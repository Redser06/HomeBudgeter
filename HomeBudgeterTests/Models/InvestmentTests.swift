import XCTest
import SwiftData
@testable import Home_Budgeter

final class InvestmentTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

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
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }

    // MARK: - Persistence

    @MainActor
    func testCreateAndFetchInvestment() {
        let inv = Investment(symbol: "AAPL", name: "Apple Inc.", assetType: .stock)
        modelContext.insert(inv)
        try! modelContext.save()

        let fetched = try! modelContext.fetch(FetchDescriptor<Investment>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].symbol, "AAPL")
        XCTAssertEqual(fetched[0].name, "Apple Inc.")
        XCTAssertEqual(fetched[0].assetType, .stock)
        XCTAssertEqual(fetched[0].currencyCode, "EUR")
    }

    @MainActor
    func testDefaultValues() {
        let inv = Investment(symbol: "BTC", name: "Bitcoin", assetType: .crypto, currencyCode: "USD")
        XCTAssertEqual(inv.currencyCode, "USD")
        XCTAssertEqual(inv.assetType, .crypto)
        XCTAssertNotNil(inv.id)
        XCTAssertNotNil(inv.createdAt)
    }

    // MARK: - Computed Properties

    @MainActor
    func testTotalQuantityBuysOnly() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx1 = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!)
        tx1.investment = inv
        modelContext.insert(tx1)

        let tx2 = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "5")!, pricePerUnit: Decimal(string: "160")!)
        tx2.investment = inv
        modelContext.insert(tx2)

        try! modelContext.save()

        XCTAssertEqual(inv.totalQuantity, Decimal(string: "15")!)
    }

    @MainActor
    func testTotalQuantityWithSell() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let buy = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!)
        buy.investment = inv
        modelContext.insert(buy)

        let sell = InvestmentTransaction(transactionType: .sell, quantity: Decimal(string: "3")!, pricePerUnit: Decimal(string: "170")!)
        sell.investment = inv
        modelContext.insert(sell)

        try! modelContext.save()

        XCTAssertEqual(inv.totalQuantity, Decimal(string: "7")!)
    }

    @MainActor
    func testAverageCostBasis() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx1 = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "100")!)
        tx1.investment = inv
        modelContext.insert(tx1)

        let tx2 = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "200")!)
        tx2.investment = inv
        modelContext.insert(tx2)

        try! modelContext.save()

        XCTAssertEqual(inv.averageCostBasis, Decimal(string: "150")!)
    }

    @MainActor
    func testAverageCostBasisEmpty() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)
        try! modelContext.save()

        XCTAssertEqual(inv.averageCostBasis, 0)
    }

    @MainActor
    func testCurrentValue() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!)
        tx.investment = inv
        modelContext.insert(tx)

        inv.addPrice(Decimal(string: "175")!)
        try! modelContext.save()

        XCTAssertEqual(inv.currentValue, Decimal(string: "1750")!)
    }

    @MainActor
    func testCurrentValueNoPrice() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!)
        tx.investment = inv
        modelContext.insert(tx)
        try! modelContext.save()

        XCTAssertEqual(inv.currentValue, 0)
    }

    @MainActor
    func testGainLoss() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "100")!)
        tx.investment = inv
        modelContext.insert(tx)

        inv.addPrice(Decimal(string: "120")!)
        try! modelContext.save()

        // currentValue = 10 * 120 = 1200
        // costBasis = 10 * 100 = 1000
        // gainLoss = 200
        XCTAssertEqual(inv.totalGainLoss, Decimal(string: "200")!)
        XCTAssertEqual(inv.gainLossPercentage, 20.0, accuracy: 0.01)
    }

    @MainActor
    func testGainLossPercentageZeroCost() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)
        try! modelContext.save()

        XCTAssertEqual(inv.gainLossPercentage, 0)
    }

    // MARK: - Price History

    @MainActor
    func testPriceHistoryEncoding() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        inv.addPrice(Decimal(string: "150")!, on: Date())
        inv.addPrice(Decimal(string: "155")!, on: Date().addingTimeInterval(86400))
        try! modelContext.save()

        XCTAssertEqual(inv.priceHistory.count, 2)
        XCTAssertEqual(inv.latestPrice, Decimal(string: "155")!)
    }

    @MainActor
    func testEmptyPriceHistory() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        XCTAssertTrue(inv.priceHistory.isEmpty)
        XCTAssertNil(inv.latestPrice)
    }

    // MARK: - Relationships

    @MainActor
    func testHouseholdMemberRelationship() {
        let member = HouseholdMember(name: "Alice")
        modelContext.insert(member)

        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        inv.owner = member
        modelContext.insert(inv)
        try! modelContext.save()

        XCTAssertEqual(inv.owner?.name, "Alice")
        XCTAssertEqual(member.investments?.count, 1)
    }

    @MainActor
    func testAccountRelationship() {
        let account = Account(name: "Broker", type: .investment)
        modelContext.insert(account)

        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        inv.account = account
        modelContext.insert(inv)
        try! modelContext.save()

        XCTAssertEqual(inv.account?.name, "Broker")
    }

    @MainActor
    func testCascadeDeleteTransactions() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!)
        tx.investment = inv
        modelContext.insert(tx)
        try! modelContext.save()

        XCTAssertEqual(try! modelContext.fetch(FetchDescriptor<InvestmentTransaction>()).count, 1)

        modelContext.delete(inv)
        try! modelContext.save()

        XCTAssertEqual(try! modelContext.fetch(FetchDescriptor<InvestmentTransaction>()).count, 0)
    }

    // MARK: - Fees

    @MainActor
    func testTotalFees() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx1 = InvestmentTransaction(transactionType: .buy, quantity: Decimal(string: "10")!, pricePerUnit: Decimal(string: "150")!, fees: Decimal(string: "9.99")!)
        tx1.investment = inv
        modelContext.insert(tx1)

        let tx2 = InvestmentTransaction(transactionType: .sell, quantity: Decimal(string: "5")!, pricePerUnit: Decimal(string: "170")!, fees: Decimal(string: "4.99")!)
        tx2.investment = inv
        modelContext.insert(tx2)

        try! modelContext.save()

        XCTAssertEqual(inv.totalFees, Decimal(string: "14.98")!)
    }

    // MARK: - Asset Types

    func testAssetTypeIcons() {
        for type in AssetType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func testAssetTypeCaseIterable() {
        XCTAssertEqual(AssetType.allCases.count, 4)
    }
}
