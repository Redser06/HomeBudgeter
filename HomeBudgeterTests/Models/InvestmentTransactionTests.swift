import XCTest
import SwiftData
@testable import Home_Budgeter

final class InvestmentTransactionTests: XCTestCase {

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
    func testCreateAndFetchTransaction() {
        let inv = Investment(symbol: "AAPL", name: "Apple", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "10")!,
            pricePerUnit: Decimal(string: "150.50")!,
            fees: Decimal(string: "9.99")!
        )
        tx.investment = inv
        modelContext.insert(tx)
        try! modelContext.save()

        let fetched = try! modelContext.fetch(FetchDescriptor<InvestmentTransaction>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].transactionType, .buy)
        XCTAssertEqual(fetched[0].quantity, Decimal(string: "10")!)
        XCTAssertEqual(fetched[0].pricePerUnit, Decimal(string: "150.50")!)
        XCTAssertEqual(fetched[0].fees, Decimal(string: "9.99")!)
    }

    // MARK: - Total Amount

    @MainActor
    func testTotalAmountBuy() {
        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "10")!,
            pricePerUnit: Decimal(string: "100")!,
            fees: Decimal(string: "5")!
        )
        // (10 * 100) + 5 = 1005
        XCTAssertEqual(tx.totalAmount, Decimal(string: "1005")!)
    }

    @MainActor
    func testTotalAmountSell() {
        let tx = InvestmentTransaction(
            transactionType: .sell,
            quantity: Decimal(string: "5")!,
            pricePerUnit: Decimal(string: "200")!,
            fees: Decimal(string: "10")!
        )
        // (5 * 200) + 10 = 1010
        XCTAssertEqual(tx.totalAmount, Decimal(string: "1010")!)
    }

    @MainActor
    func testTotalAmountNoFees() {
        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "100")!,
            pricePerUnit: Decimal(string: "50")!
        )
        XCTAssertEqual(tx.totalAmount, Decimal(string: "5000")!)
    }

    @MainActor
    func testTotalAmountDecimalPrecision() {
        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "3.5")!,
            pricePerUnit: Decimal(string: "17.99")!,
            fees: Decimal(string: "1.50")!
        )
        // (3.5 * 17.99) + 1.50 = 62.965 + 1.50 = 64.465
        XCTAssertEqual(tx.totalAmount, Decimal(string: "64.465")!)
    }

    // MARK: - Default Values

    @MainActor
    func testDefaultFees() {
        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "1")!,
            pricePerUnit: Decimal(string: "100")!
        )
        XCTAssertEqual(tx.fees, 0)
    }

    @MainActor
    func testDefaultDate() {
        let before = Date()
        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "1")!,
            pricePerUnit: Decimal(string: "100")!
        )
        let after = Date()
        XCTAssertTrue(tx.date >= before && tx.date <= after)
    }

    // MARK: - Relationship

    @MainActor
    func testInvestmentRelationship() {
        let inv = Investment(symbol: "MSFT", name: "Microsoft", assetType: .stock)
        modelContext.insert(inv)

        let tx = InvestmentTransaction(
            transactionType: .buy,
            quantity: Decimal(string: "20")!,
            pricePerUnit: Decimal(string: "350")!
        )
        tx.investment = inv
        modelContext.insert(tx)
        try! modelContext.save()

        XCTAssertEqual(tx.investment?.symbol, "MSFT")
        XCTAssertEqual(inv.transactions?.count, 1)
    }

    // MARK: - Transaction Types

    func testTransactionTypeCaseIterable() {
        XCTAssertEqual(InvestmentTransactionType.allCases.count, 2)
    }

    func testTransactionTypeRawValues() {
        XCTAssertEqual(InvestmentTransactionType.buy.rawValue, "Buy")
        XCTAssertEqual(InvestmentTransactionType.sell.rawValue, "Sell")
    }
}
