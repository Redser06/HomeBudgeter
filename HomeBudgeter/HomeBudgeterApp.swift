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
    let sharedModelContainer = PersistenceController.shared.modelContainer

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
