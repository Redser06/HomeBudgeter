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
            RootView()
                .onAppear {
                    BillMigrationService.shared.migrateIfNeeded(
                        modelContext: sharedModelContainer.mainContext
                    )
                    BillMigrationService.shared.migrateProvidersIfNeeded(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .task {
                    _ = await NotificationService.shared.requestPermission()
                    await NotificationService.shared.scheduleUpcomingReminders(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .task {
                    // Full sync on launch after auth resolves
                    guard AuthManager.shared.isSignedIn else { return }
                    await SyncService.shared.fullSync(
                        modelContext: sharedModelContainer.mainContext
                    )
                }
                .onOpenURL { url in
                    Task {
                        await AuthManager.shared.handleOAuthCallback(url: url)
                    }
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
