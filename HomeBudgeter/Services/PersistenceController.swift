//
//  PersistenceController.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    static let appSchema = Schema([
        Transaction.self,
        BudgetCategory.self,
        Account.self,
        SavingsGoal.self,
        Document.self,
        Payslip.self,
        PensionData.self,
        RecurringTemplate.self,
        BillLineItem.self,
        HouseholdMember.self,
        Investment.self,
        InvestmentTransaction.self,
        SyncQueueEntry.self
    ])

    let modelContainer: ModelContainer

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    static var iCloudSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    init(inMemory: Bool = false) {
        let schema = PersistenceController.appSchema

        let modelConfiguration: ModelConfiguration

        if inMemory {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else if PersistenceController.iCloudSyncEnabled {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.homebudgeter.app")
            )
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }

        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    @MainActor
    func saveSwiftData() async {
        do {
            try modelContainer.mainContext.save()
        } catch {
            print("Failed to save SwiftData context: \(error)")
        }
    }
}
