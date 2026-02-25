import XCTest
import SwiftData
import SwiftUI
@testable import Home_Budgeter

final class HouseholdMemberTests: XCTestCase {

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
    func testCreateAndFetchHouseholdMember() {
        let member = HouseholdMember(name: "Alice", colorHex: "#FF5733", icon: "person.fill")
        modelContext.insert(member)
        try! modelContext.save()

        let descriptor = FetchDescriptor<HouseholdMember>()
        let fetched = try! modelContext.fetch(descriptor)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Alice")
        XCTAssertEqual(fetched.first?.colorHex, "#FF5733")
        XCTAssertEqual(fetched.first?.icon, "person.fill")
        XCTAssertFalse(fetched.first!.isDefault)
    }

    @MainActor
    func testDefaultValues() {
        let member = HouseholdMember(name: "Bob")

        XCTAssertEqual(member.colorHex, "#007AFF")
        XCTAssertEqual(member.icon, "person.circle.fill")
        XCTAssertFalse(member.isDefault)
        XCTAssertNotNil(member.id)
        XCTAssertNotNil(member.createdAt)
        XCTAssertNotNil(member.updatedAt)
    }

    @MainActor
    func testIsDefaultMember() {
        let member = HouseholdMember(name: "Primary", isDefault: true)
        modelContext.insert(member)
        try! modelContext.save()

        let descriptor = FetchDescriptor<HouseholdMember>()
        let fetched = try! modelContext.fetch(descriptor)

        XCTAssertTrue(fetched.first!.isDefault)
    }

    // MARK: - Relationships

    @MainActor
    func testAccountRelationship() {
        let member = HouseholdMember(name: "Alice")
        modelContext.insert(member)

        let account = Account(name: "Checking", type: .checking)
        account.owner = member
        modelContext.insert(account)
        try! modelContext.save()

        XCTAssertEqual(member.accounts?.count, 1)
        XCTAssertEqual(member.accounts?.first?.name, "Checking")
        XCTAssertEqual(account.owner?.name, "Alice")
    }

    @MainActor
    func testPayslipRelationship() {
        let member = HouseholdMember(name: "Bob")
        modelContext.insert(member)

        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: Decimal(string: "5000")!,
            netPay: Decimal(string: "3500")!,
            incomeTax: Decimal(string: "1000")!,
            socialInsurance: Decimal(string: "500")!
        )
        payslip.member = member
        modelContext.insert(payslip)
        try! modelContext.save()

        XCTAssertEqual(member.payslips?.count, 1)
        XCTAssertEqual(payslip.member?.name, "Bob")
    }

    @MainActor
    func testPensionRelationship() {
        let member = HouseholdMember(name: "Carol")
        modelContext.insert(member)

        let pension = PensionData(currentValue: Decimal(string: "50000")!)
        pension.member = member
        modelContext.insert(pension)
        try! modelContext.save()

        XCTAssertEqual(member.pensions?.count, 1)
        XCTAssertEqual(pension.member?.name, "Carol")
    }

    @MainActor
    func testSavingsGoalRelationship() {
        let member = HouseholdMember(name: "Dave")
        modelContext.insert(member)

        let goal = SavingsGoal(name: "Holiday Fund", targetAmount: Decimal(string: "2000")!)
        goal.member = member
        modelContext.insert(goal)
        try! modelContext.save()

        XCTAssertEqual(member.savingsGoals?.count, 1)
        XCTAssertEqual(goal.member?.name, "Dave")
    }

    @MainActor
    func testMultipleRelationships() {
        let member = HouseholdMember(name: "Eve")
        modelContext.insert(member)

        let account1 = Account(name: "Current", type: .checking)
        account1.owner = member
        let account2 = Account(name: "Savings", type: .savings)
        account2.owner = member
        modelContext.insert(account1)
        modelContext.insert(account2)
        try! modelContext.save()

        XCTAssertEqual(member.accounts?.count, 2)
    }

    // MARK: - Nullify Delete Rule

    @MainActor
    func testDeletingMemberNullifiesAccountOwner() {
        let member = HouseholdMember(name: "Temp")
        modelContext.insert(member)

        let account = Account(name: "Orphan Account", type: .checking)
        account.owner = member
        modelContext.insert(account)
        try! modelContext.save()

        XCTAssertNotNil(account.owner)

        modelContext.delete(member)
        try! modelContext.save()

        let accounts = try! modelContext.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertNil(accounts.first?.owner)
    }

    @MainActor
    func testDeletingMemberNullifiesPayslipMember() {
        let member = HouseholdMember(name: "Temp")
        modelContext.insert(member)

        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: Decimal(string: "3000")!,
            netPay: Decimal(string: "2100")!,
            incomeTax: Decimal(string: "600")!,
            socialInsurance: Decimal(string: "300")!
        )
        payslip.member = member
        modelContext.insert(payslip)
        try! modelContext.save()

        modelContext.delete(member)
        try! modelContext.save()

        let payslips = try! modelContext.fetch(FetchDescriptor<Payslip>())
        XCTAssertEqual(payslips.count, 1)
        XCTAssertNil(payslips.first?.member)
    }

    @MainActor
    func testDeletingMemberNullifiesPensionMember() {
        let member = HouseholdMember(name: "Temp")
        modelContext.insert(member)

        let pension = PensionData(currentValue: Decimal(string: "10000")!)
        pension.member = member
        modelContext.insert(pension)
        try! modelContext.save()

        modelContext.delete(member)
        try! modelContext.save()

        let pensions = try! modelContext.fetch(FetchDescriptor<PensionData>())
        XCTAssertEqual(pensions.count, 1)
        XCTAssertNil(pensions.first?.member)
    }

    @MainActor
    func testDeletingMemberNullifiesSavingsGoalMember() {
        let member = HouseholdMember(name: "Temp")
        modelContext.insert(member)

        let goal = SavingsGoal(name: "Test Goal", targetAmount: Decimal(string: "1000")!)
        goal.member = member
        modelContext.insert(goal)
        try! modelContext.save()

        modelContext.delete(member)
        try! modelContext.save()

        let goals = try! modelContext.fetch(FetchDescriptor<SavingsGoal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertNil(goals.first?.member)
    }

    // MARK: - Color Parsing

    @MainActor
    func testColorFromValidHex() {
        let member = HouseholdMember(name: "Test", colorHex: "#FF0000")
        let color = member.color
        XCTAssertNotNil(color)
    }

    @MainActor
    func testColorFromHexWithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    @MainActor
    func testColorFromInvalidHex() {
        let color = Color(hex: "ZZZZZZ")
        XCTAssertNil(color)
    }

    @MainActor
    func testColorFromShortHex() {
        let color = Color(hex: "#FFF")
        XCTAssertNil(color)
    }

    @MainActor
    func testColorFallbackForInvalidHex() {
        let member = HouseholdMember(name: "Test", colorHex: "invalid")
        // Should fall back to .blue without crashing
        let _ = member.color
    }

    @MainActor
    func testUniqueId() {
        let member1 = HouseholdMember(name: "A")
        let member2 = HouseholdMember(name: "B")
        XCTAssertNotEqual(member1.id, member2.id)
    }
}
