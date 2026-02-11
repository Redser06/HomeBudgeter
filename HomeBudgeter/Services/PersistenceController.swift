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

    let modelContainer: ModelContainer

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()

    init(inMemory: Bool = false) {
        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Account.self,
            SavingsGoal.self,
            Document.self,
            Payslip.self,
            PensionData.self,
            RecurringTemplate.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

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
