//
//  HomeBudgeterApp.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

@main
struct HomeBudgeterApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Account.self,
            SavingsGoal.self,
            Document.self,
            Payslip.self,
            PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    BillMigrationService.shared.migrateIfNeeded(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .task {
                    _ = await NotificationService.shared.requestPermission()
                    await NotificationService.shared.scheduleUpcomingReminders(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)

        #if os(macOS)
        Settings {
            SettingsView()
                .modelContainer(sharedModelContainer)
        }
        #endif
    }
}
