//
//  PersistenceTests.swift
//  HomeBudgeterTests
//
//  Integration tests verifying that data survives save/reload cycles.
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class PersistenceTests: XCTestCase {

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
            InvestmentTransaction.self,
            SyncQueueEntry.self
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

    // MARK: - Transaction Persistence

    @MainActor
    func test_transaction_survivesInsertAndFetch() throws {
        let tx = Transaction(
            amount: 250.75,
            date: Date(),
            descriptionText: "Groceries run",
            type: .expense,
            isRecurring: true,
            recurringFrequency: .monthly,
            notes: "Lidl weekly shop"
        )
        modelContext.insert(tx)
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.amount, 250.75)
        XCTAssertEqual(saved.descriptionText, "Groceries run")
        XCTAssertEqual(saved.type, .expense)
        XCTAssertTrue(saved.isRecurring)
        XCTAssertEqual(saved.recurringFrequency, .monthly)
        XCTAssertEqual(saved.notes, "Lidl weekly shop")
    }

    @MainActor
    func test_transaction_update_persistsChange() throws {
        let tx = Transaction(amount: 100, date: Date(), descriptionText: "Initial")
        modelContext.insert(tx)
        try modelContext.save()

        tx.amount = 200
        tx.descriptionText = "Updated"
        tx.updatedAt = Date()
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.first?.amount, 200)
        XCTAssertEqual(fetched.first?.descriptionText, "Updated")
    }

    @MainActor
    func test_transaction_delete_removesFromStore() throws {
        let tx = Transaction(amount: 50, date: Date(), descriptionText: "To delete")
        modelContext.insert(tx)
        try modelContext.save()

        modelContext.delete(tx)
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertTrue(fetched.isEmpty)
    }

    @MainActor
    func test_multipleTransactions_allPersisted() throws {
        let transactions = (1...10).map { i in
            Transaction(amount: Decimal(i * 100), date: Date(), descriptionText: "Tx \(i)", type: .expense)
        }
        for tx in transactions {
            modelContext.insert(tx)
        }
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 10)
    }

    // MARK: - Account Persistence

    @MainActor
    func test_account_survivesInsertAndFetch() throws {
        let account = Account(
            name: "AIB Current",
            type: .checking,
            balance: 3500.50,
            currencyCode: "EUR",
            institution: "AIB",
            accountNumber: "IE29AIBK93115212345678"
        )
        modelContext.insert(account)
        try modelContext.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.name, "AIB Current")
        XCTAssertEqual(saved.type, .checking)
        XCTAssertEqual(saved.balance, 3500.50)
        XCTAssertEqual(saved.institution, "AIB")
    }

    @MainActor
    func test_account_update_balancePersists() throws {
        let account = Account(name: "Savings", type: .savings, balance: 1000)
        modelContext.insert(account)
        try modelContext.save()

        account.balance = 5000
        try modelContext.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.first?.balance, 5000)
    }

    // MARK: - BudgetCategory Persistence

    @MainActor
    func test_budgetCategory_survivesInsertAndFetch() throws {
        let cat = BudgetCategory(
            type: .housing,
            budgetAmount: 1200,
            spentAmount: 800,
            period: .monthly,
            isActive: true
        )
        modelContext.insert(cat)
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.type, .housing)
        XCTAssertEqual(saved.budgetAmount, 1200)
        XCTAssertEqual(saved.spentAmount, 800)
        XCTAssertEqual(saved.period, .monthly)
        XCTAssertTrue(saved.isActive)
    }

    @MainActor
    func test_budgetCategory_update_persistsAmountChange() throws {
        let cat = BudgetCategory(type: .transport, budgetAmount: 200)
        modelContext.insert(cat)
        try modelContext.save()

        cat.budgetAmount = 350
        cat.spentAmount = 150
        try modelContext.save()

        let descriptor = FetchDescriptor<BudgetCategory>()
        let fetched = try modelContext.fetch(descriptor)
        XCTAssertEqual(fetched.first?.budgetAmount, 350)
        XCTAssertEqual(fetched.first?.spentAmount, 150)
    }

    // MARK: - Document Persistence

    @MainActor
    func test_document_survivesInsertAndFetch() throws {
        let doc = Document(
            filename: "payslip_jan.pdf",
            localPath: "/docs/payslip_jan.pdf",
            documentType: .payslip,
            fileSize: 204_800,
            mimeType: "application/pdf"
        )
        doc.notes = "January payslip"
        doc.isProcessed = true
        modelContext.insert(doc)
        try modelContext.save()

        let descriptor = FetchDescriptor<Document>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.filename, "payslip_jan.pdf")
        XCTAssertEqual(saved.documentType, .payslip)
        XCTAssertEqual(saved.fileSize, 204_800)
        XCTAssertEqual(saved.notes, "January payslip")
        XCTAssertTrue(saved.isProcessed)
    }

    // MARK: - SavingsGoal Persistence

    @MainActor
    func test_savingsGoal_survivesInsertAndFetch() throws {
        let goal = SavingsGoal(
            name: "Holiday Fund",
            targetAmount: 3000,
            currentAmount: 750,
            priority: .high
        )
        modelContext.insert(goal)
        try modelContext.save()

        let descriptor = FetchDescriptor<SavingsGoal>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.name, "Holiday Fund")
        XCTAssertEqual(saved.targetAmount, 3000)
        XCTAssertEqual(saved.currentAmount, 750)
        XCTAssertEqual(saved.priority, .high)
        XCTAssertFalse(saved.isCompleted)
    }

    // MARK: - PensionData Persistence

    @MainActor
    func test_pensionData_survivesInsertAndFetch() throws {
        let pension = PensionData(
            currentValue: 45000,
            totalEmployeeContributions: 12000,
            totalEmployerContributions: 9000,
            totalInvestmentReturns: 5000,
            retirementGoal: 500000,
            targetRetirementAge: 65,
            provider: "Irish Life"
        )
        modelContext.insert(pension)
        try modelContext.save()

        let descriptor = FetchDescriptor<PensionData>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.currentValue, 45000)
        XCTAssertEqual(saved.totalEmployeeContributions, 12000)
        XCTAssertEqual(saved.totalEmployerContributions, 9000)
        XCTAssertEqual(saved.retirementGoal, 500000)
        XCTAssertEqual(saved.targetRetirementAge, 65)
        XCTAssertEqual(saved.provider, "Irish Life")
    }

    // MARK: - Payslip Persistence

    @MainActor
    func test_payslip_survivesInsertAndFetch() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!

        let payslip = Payslip(
            payDate: now,
            payPeriodStart: startOfMonth,
            payPeriodEnd: endOfMonth,
            grossPay: 4500,
            netPay: 3200,
            incomeTax: 900,
            socialInsurance: 250,
            universalCharge: 150,
            pensionContribution: 200,
            employerPensionContribution: 300,
            employer: "ACME Corp"
        )
        modelContext.insert(payslip)
        try modelContext.save()

        let descriptor = FetchDescriptor<Payslip>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        let saved = fetched.first!
        XCTAssertEqual(saved.grossPay, 4500)
        XCTAssertEqual(saved.netPay, 3200)
        XCTAssertEqual(saved.incomeTax, 900)
        XCTAssertEqual(saved.employer, "ACME Corp")
    }

    // MARK: - Cascade Delete Tests

    @MainActor
    func test_deleteAccount_cascadeDeletesTransactions() throws {
        let account = Account(name: "Bank Account", type: .checking, balance: 1000)
        modelContext.insert(account)
        try modelContext.save()

        let tx = Transaction(amount: 50, date: Date(), descriptionText: "Purchase", type: .expense)
        tx.account = account
        modelContext.insert(tx)
        try modelContext.save()

        // Delete the account - transactions should be cascade deleted
        modelContext.delete(account)
        try modelContext.save()

        let txDescriptor = FetchDescriptor<Transaction>()
        let remainingTxs = try modelContext.fetch(txDescriptor)
        XCTAssertTrue(remainingTxs.isEmpty)
    }

    @MainActor
    func test_deleteBudgetCategory_cascadeDeletesTransactions() throws {
        let category = BudgetCategory(type: .groceries, budgetAmount: 400)
        modelContext.insert(category)
        try modelContext.save()

        let tx = Transaction(amount: 80, date: Date(), descriptionText: "Food", type: .expense)
        tx.category = category
        modelContext.insert(tx)
        try modelContext.save()

        modelContext.delete(category)
        try modelContext.save()

        let txDescriptor = FetchDescriptor<Transaction>()
        let remaining = try modelContext.fetch(txDescriptor)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - Cross-Model Relationship Persistence

    @MainActor
    func test_transaction_withCategoryAndAccount_persistsRelationships() throws {
        let category = BudgetCategory(type: .transport, budgetAmount: 200)
        let account = Account(name: "Debit Card", type: .checking, balance: 2000)
        modelContext.insert(category)
        modelContext.insert(account)
        try modelContext.save()

        let tx = Transaction(amount: 45, date: Date(), descriptionText: "Bus pass", type: .expense)
        tx.category = category
        tx.account = account
        modelContext.insert(tx)
        try modelContext.save()

        let descriptor = FetchDescriptor<Transaction>()
        let fetched = try modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.category?.type, .transport)
        XCTAssertEqual(fetched.first?.account?.name, "Debit Card")
    }
}
