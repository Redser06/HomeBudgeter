import XCTest
import SwiftData
@testable import Home_Budgeter

final class HouseholdMemberViewModelTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var viewModel: HouseholdMemberViewModel!

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
            InvestmentTransaction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        viewModel = HouseholdMemberViewModel()
    }

    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        viewModel = nil
        super.tearDown()
    }

    // MARK: - Load

    @MainActor
    func testLoadMembersEmpty() {
        viewModel.loadMembers(modelContext: modelContext)
        XCTAssertTrue(viewModel.members.isEmpty)
    }

    @MainActor
    func testLoadMembersReturnsSorted() {
        let b = HouseholdMember(name: "Bob")
        let a = HouseholdMember(name: "Alice")
        modelContext.insert(b)
        modelContext.insert(a)
        try! modelContext.save()

        viewModel.loadMembers(modelContext: modelContext)
        XCTAssertEqual(viewModel.members.count, 2)
        XCTAssertEqual(viewModel.members[0].name, "Alice")
        XCTAssertEqual(viewModel.members[1].name, "Bob")
    }

    // MARK: - Add

    @MainActor
    func testAddMember() {
        viewModel.addMember(
            name: "Carol",
            colorHex: "#FF5733",
            icon: "star.circle.fill",
            isDefault: false,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.members.count, 1)
        XCTAssertEqual(viewModel.members[0].name, "Carol")
        XCTAssertEqual(viewModel.members[0].colorHex, "#FF5733")
        XCTAssertEqual(viewModel.members[0].icon, "star.circle.fill")
        XCTAssertFalse(viewModel.members[0].isDefault)
    }

    @MainActor
    func testAddDefaultMember() {
        viewModel.addMember(
            name: "First",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: true,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.members.count, 1)
        XCTAssertTrue(viewModel.members[0].isDefault)
    }

    // MARK: - Update

    @MainActor
    func testUpdateMember() {
        viewModel.addMember(
            name: "Dave",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: false,
            modelContext: modelContext
        )

        let member = viewModel.members[0]
        viewModel.updateMember(
            member,
            name: "David",
            colorHex: "#FF0000",
            icon: "star.fill",
            isDefault: true,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.members[0].name, "David")
        XCTAssertEqual(viewModel.members[0].colorHex, "#FF0000")
        XCTAssertEqual(viewModel.members[0].icon, "star.fill")
        XCTAssertTrue(viewModel.members[0].isDefault)
    }

    // MARK: - Delete

    @MainActor
    func testDeleteMember() {
        viewModel.addMember(
            name: "Eve",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: false,
            modelContext: modelContext
        )

        XCTAssertEqual(viewModel.members.count, 1)

        viewModel.deleteMember(viewModel.members[0], modelContext: modelContext)
        XCTAssertTrue(viewModel.members.isEmpty)
    }

    // MARK: - Default Member Logic

    @MainActor
    func testSetDefaultClearsOtherDefaults() {
        viewModel.addMember(
            name: "Alice",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: true,
            modelContext: modelContext
        )

        viewModel.addMember(
            name: "Bob",
            colorHex: "#34C759",
            icon: "person.fill",
            isDefault: false,
            modelContext: modelContext
        )

        let bob = viewModel.members.first { $0.name == "Bob" }!
        viewModel.setDefault(bob, modelContext: modelContext)

        let alice = viewModel.members.first { $0.name == "Alice" }!
        XCTAssertFalse(alice.isDefault)
        XCTAssertTrue(bob.isDefault)
    }

    @MainActor
    func testAddDefaultClearsExistingDefault() {
        viewModel.addMember(
            name: "First",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: true,
            modelContext: modelContext
        )

        viewModel.addMember(
            name: "Second",
            colorHex: "#FF3B30",
            icon: "person.fill",
            isDefault: true,
            modelContext: modelContext
        )

        let first = viewModel.members.first { $0.name == "First" }!
        let second = viewModel.members.first { $0.name == "Second" }!
        XCTAssertFalse(first.isDefault)
        XCTAssertTrue(second.isDefault)
    }

    @MainActor
    func testDefaultMemberComputed() {
        viewModel.addMember(
            name: "A",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: false,
            modelContext: modelContext
        )
        XCTAssertNil(viewModel.defaultMember)

        viewModel.addMember(
            name: "B",
            colorHex: "#34C759",
            icon: "person.fill",
            isDefault: true,
            modelContext: modelContext
        )
        XCTAssertEqual(viewModel.defaultMember?.name, "B")
    }

    // MARK: - Color & Icon Palettes

    func testColorPaletteNotEmpty() {
        XCTAssertFalse(HouseholdMemberViewModel.colorPalette.isEmpty)
        XCTAssertEqual(HouseholdMemberViewModel.colorPalette.count, 8)
    }

    func testIconOptionsNotEmpty() {
        XCTAssertFalse(HouseholdMemberViewModel.iconOptions.isEmpty)
        XCTAssertEqual(HouseholdMemberViewModel.iconOptions.count, 8)
    }

    // MARK: - Delete Orphans Records

    @MainActor
    func testDeleteMemberOrphansAccount() {
        viewModel.addMember(
            name: "Temp",
            colorHex: "#007AFF",
            icon: "person.fill",
            isDefault: false,
            modelContext: modelContext
        )

        let member = viewModel.members[0]
        let account = Account(name: "Orphan", type: .checking)
        account.owner = member
        modelContext.insert(account)
        try! modelContext.save()

        viewModel.deleteMember(member, modelContext: modelContext)

        let accounts = try! modelContext.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 1)
        XCTAssertNil(accounts[0].owner)
    }
}
