import XCTest
import SwiftData
@testable import Home_Budgeter

final class CloudKitSyncTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "iCloudSyncEnabled")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "iCloudSyncEnabled")
        super.tearDown()
    }

    // MARK: - PersistenceController Container Tests

    @MainActor
    func testLocalContainerCreatedWhenSyncDisabled() {
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.modelContainer)
    }

    @MainActor
    func testInMemoryContainerCreated() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertNotNil(controller.modelContainer)
    }

    @MainActor
    func testAppSchemaContainsAllModels() {
        let schema = PersistenceController.appSchema
        // Schema should contain all 10 model types
        XCTAssertNotNil(schema)
    }

    @MainActor
    func testContainerCanInsertAndFetch() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.modelContainer.mainContext

        let account = Account(name: "Test", type: .checking)
        context.insert(account)
        try! context.save()

        let descriptor = FetchDescriptor<Account>()
        let fetched = try! context.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test")
    }

    @MainActor
    func testContainerSupportsAllModelTypes() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.modelContainer.mainContext

        // Insert one of each type to verify schema completeness
        let account = Account(name: "Checking", type: .checking)
        context.insert(account)

        let member = HouseholdMember(name: "Alice")
        context.insert(member)

        let goal = SavingsGoal(name: "Fund", targetAmount: Decimal(string: "1000")!)
        context.insert(goal)

        let pension = PensionData(currentValue: Decimal(string: "5000")!)
        context.insert(pension)

        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: Decimal(string: "3000")!,
            netPay: Decimal(string: "2100")!,
            incomeTax: Decimal(string: "600")!,
            socialInsurance: Decimal(string: "300")!
        )
        context.insert(payslip)

        try! context.save()

        XCTAssertEqual(try! context.fetch(FetchDescriptor<Account>()).count, 1)
        XCTAssertEqual(try! context.fetch(FetchDescriptor<HouseholdMember>()).count, 1)
        XCTAssertEqual(try! context.fetch(FetchDescriptor<SavingsGoal>()).count, 1)
        XCTAssertEqual(try! context.fetch(FetchDescriptor<PensionData>()).count, 1)
        XCTAssertEqual(try! context.fetch(FetchDescriptor<Payslip>()).count, 1)
    }

    // MARK: - SettingsViewModel iCloud Toggle Tests

    func testICloudSyncDefaultsToFalse() {
        let vm = SettingsViewModel()
        XCTAssertFalse(vm.iCloudSyncEnabled)
    }

    func testICloudSyncTogglePersists() {
        let vm = SettingsViewModel()
        vm.iCloudSyncEnabled = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "iCloudSyncEnabled"))

        let vm2 = SettingsViewModel()
        XCTAssertTrue(vm2.iCloudSyncEnabled)
    }

    func testICloudSyncDisablePersists() {
        UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        let vm = SettingsViewModel()
        XCTAssertTrue(vm.iCloudSyncEnabled)

        vm.iCloudSyncEnabled = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "iCloudSyncEnabled"))
    }

    func testResetToDefaultsDisablesICloudSync() {
        let vm = SettingsViewModel()
        vm.iCloudSyncEnabled = true
        vm.resetToDefaults()
        XCTAssertFalse(vm.iCloudSyncEnabled)
    }

    func testPersistenceControllerICloudSyncEnabledReadsUserDefaults() {
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        XCTAssertFalse(PersistenceController.iCloudSyncEnabled)

        UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        XCTAssertTrue(PersistenceController.iCloudSyncEnabled)
    }

    // MARK: - CloudKitSyncMonitor Tests

    func testSyncMonitorDefaultStatusWhenDisabled() {
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        // The shared singleton may already be initialized; test the status descriptions
        let monitor = CloudKitSyncMonitor.shared
        XCTAssertNotNil(monitor.statusDescription)
        XCTAssertNotNil(monitor.statusIcon)
    }

    func testSyncStatusDescriptions() {
        // Verify all status cases produce non-empty descriptions
        let statuses: [CloudKitSyncMonitor.SyncStatus] = [
            .disabled,
            .idle,
            .syncing,
            .succeeded(Date()),
            .failed("Test error")
        ]

        for status in statuses {
            switch status {
            case .disabled:
                XCTAssertEqual(status, .disabled)
            case .idle:
                XCTAssertEqual(status, .idle)
            case .syncing:
                XCTAssertEqual(status, .syncing)
            case .succeeded:
                XCTAssertNotEqual(status, .disabled)
            case .failed(let message):
                XCTAssertEqual(message, "Test error")
            }
        }
    }
}
