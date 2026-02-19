//
//  AccountTests.swift
//  HomeBudgeterTests
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class AccountTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Transaction.self, BudgetCategory.self, Account.self,
            Document.self, SavingsGoal.self, Payslip.self, PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self,
            HouseholdMember.self,
            Investment.self,
            InvestmentTransaction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initialisation Tests

    func test_init_withRequiredParams_setsDefaults() {
        let account = Account(name: "My Checking", type: .checking)
        XCTAssertNotNil(account.id)
        XCTAssertEqual(account.name, "My Checking")
        XCTAssertEqual(account.type, .checking)
        XCTAssertEqual(account.balance, 0)
        XCTAssertEqual(account.currencyCode, "EUR")
        XCTAssertTrue(account.isActive)
        XCTAssertNil(account.institution)
        XCTAssertNil(account.accountNumber)
        XCTAssertNil(account.notes)
    }

    func test_init_withAllParams_setsAllProperties() {
        let account = Account(
            name: "HSBC Savings",
            type: .savings,
            balance: 5000.00,
            currencyCode: "GBP",
            isActive: false,
            institution: "HSBC",
            accountNumber: "12345678",
            notes: "Emergency fund"
        )
        XCTAssertEqual(account.name, "HSBC Savings")
        XCTAssertEqual(account.type, .savings)
        XCTAssertEqual(account.balance, 5000.00)
        XCTAssertEqual(account.currencyCode, "GBP")
        XCTAssertFalse(account.isActive)
        XCTAssertEqual(account.institution, "HSBC")
        XCTAssertEqual(account.accountNumber, "12345678")
        XCTAssertEqual(account.notes, "Emergency fund")
    }

    func test_init_setsCreatedAtAndUpdatedAt() {
        let before = Date()
        let account = Account(name: "Test", type: .cash)
        let after = Date()
        XCTAssertGreaterThanOrEqual(account.createdAt, before)
        XCTAssertLessThanOrEqual(account.createdAt, after)
        XCTAssertGreaterThanOrEqual(account.updatedAt, before)
    }

    func test_init_generatesUniqueIds() {
        let a1 = Account(name: "Acc 1", type: .checking)
        let a2 = Account(name: "Acc 2", type: .savings)
        XCTAssertNotEqual(a1.id, a2.id)
    }

    // MARK: - isAsset Tests

    func test_isAsset_checkingAccount_returnsTrue() {
        let account = Account(name: "Checking", type: .checking, balance: 500)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_savingsAccount_returnsTrue() {
        let account = Account(name: "Savings", type: .savings, balance: 10000)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_investmentAccount_returnsTrue() {
        let account = Account(name: "Portfolio", type: .investment, balance: 50000)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_pensionAccount_returnsTrue() {
        let account = Account(name: "Pension", type: .pension, balance: 200000)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_cashAccount_returnsTrue() {
        let account = Account(name: "Wallet", type: .cash, balance: 100)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_checkingAccountWithNegativeBalance_returnsTrue() {
        // Checking is always an asset regardless of balance
        let account = Account(name: "Overdrawn", type: .checking, balance: -500)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_creditCardWithPositiveBalance_returnsTrue() {
        let account = Account(name: "Credit Card", type: .credit, balance: 100)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_creditCardWithZeroBalance_returnsTrue() {
        let account = Account(name: "Credit Card", type: .credit, balance: 0)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_creditCardWithNegativeBalance_returnsFalse() {
        let account = Account(name: "Credit Card", type: .credit, balance: -1000)
        XCTAssertFalse(account.isAsset)
    }

    func test_isAsset_otherAccountWithPositiveBalance_returnsTrue() {
        let account = Account(name: "Other", type: .other, balance: 200)
        XCTAssertTrue(account.isAsset)
    }

    func test_isAsset_otherAccountWithNegativeBalance_returnsFalse() {
        let account = Account(name: "Other", type: .other, balance: -50)
        XCTAssertFalse(account.isAsset)
    }

    // MARK: - AccountType Tests

    func test_accountType_allCasesExist() {
        let expected: [AccountType] = [.checking, .savings, .credit, .investment, .pension, .cash, .other]
        XCTAssertEqual(AccountType.allCases.count, expected.count)
        for type in expected {
            XCTAssertTrue(AccountType.allCases.contains(type))
        }
    }

    func test_accountType_rawValues() {
        XCTAssertEqual(AccountType.checking.rawValue, "Checking")
        XCTAssertEqual(AccountType.savings.rawValue, "Savings")
        XCTAssertEqual(AccountType.credit.rawValue, "Credit Card")
        XCTAssertEqual(AccountType.investment.rawValue, "Investment")
        XCTAssertEqual(AccountType.pension.rawValue, "Pension")
        XCTAssertEqual(AccountType.cash.rawValue, "Cash")
        XCTAssertEqual(AccountType.other.rawValue, "Other")
    }

    func test_accountType_icons_areNonEmpty() {
        for type in AccountType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "Icon for \(type.rawValue) should not be empty")
        }
    }

    func test_accountType_checkingIcon() {
        XCTAssertEqual(AccountType.checking.icon, "building.columns.fill")
    }

    func test_accountType_savingsIcon() {
        XCTAssertEqual(AccountType.savings.icon, "banknote.fill")
    }

    func test_accountType_creditIcon() {
        XCTAssertEqual(AccountType.credit.icon, "creditcard.fill")
    }

    func test_accountType_investmentIcon() {
        XCTAssertEqual(AccountType.investment.icon, "chart.line.uptrend.xyaxis")
    }

    func test_accountType_pensionIcon() {
        XCTAssertEqual(AccountType.pension.icon, "clock.fill")
    }

    func test_accountType_cashIcon() {
        XCTAssertEqual(AccountType.cash.icon, "dollarsign.circle.fill")
    }

    func test_accountType_otherIcon() {
        XCTAssertEqual(AccountType.other.icon, "folder.fill")
    }

    // MARK: - Persistence Tests

    @MainActor
    func test_saveAndFetch_account_persistsCorrectly() throws {
        let balance = Decimal(string: "1234.56")!
        let account = Account(name: "Test Bank", type: .checking, balance: balance)
        modelContext.insert(account)
        try modelContext.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Bank")
        // Compare as Double to avoid Decimal precision issues from floating point literal coercion
        let fetchedBalance = Double(truncating: (fetched.first?.balance ?? 0) as NSNumber)
        XCTAssertEqual(fetchedBalance, 1234.56, accuracy: 0.001)
    }

    @MainActor
    func test_delete_account_removesFromStore() throws {
        let account = Account(name: "To Delete", type: .cash, balance: 50)
        modelContext.insert(account)
        try modelContext.save()

        modelContext.delete(account)
        try modelContext.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertTrue(fetched.isEmpty)
    }

    // MARK: - Balance Edge Cases

    func test_account_withZeroBalance_isValid() {
        let account = Account(name: "Zero Balance", type: .checking, balance: 0)
        XCTAssertEqual(account.balance, 0)
    }

    func test_account_withVeryLargeBalance_handlesCorrectly() {
        let largeBalance: Decimal = 999_999_999.99
        let account = Account(name: "Wealthy", type: .investment, balance: largeBalance)
        XCTAssertEqual(account.balance, largeBalance)
    }

    func test_account_withNegativeBalance_creditCard() {
        let account = Account(name: "Visa", type: .credit, balance: -2500.00)
        XCTAssertEqual(account.balance, -2500.00)
        XCTAssertFalse(account.isAsset)
    }
}
