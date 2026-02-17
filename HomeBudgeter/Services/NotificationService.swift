//
//  NotificationService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import UserNotifications
import SwiftData

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let reminderDaysKey = "billReminderDays"

    var reminderDays: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: reminderDaysKey)
            return stored == 0 ? 3 : stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: reminderDaysKey)
        }
    }

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    var isAuthorised: Bool {
        get async {
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Schedule Reminders

    @MainActor
    func scheduleUpcomingReminders(modelContext: ModelContext) async {
        let enabled = UserDefaults.standard.bool(forKey: "enableNotifications")
        guard enabled else {
            center.removeAllPendingNotificationRequests()
            return
        }

        let authorised = await isAuthorised
        guard authorised else { return }

        // Remove old scheduled notifications
        center.removeAllPendingNotificationRequests()

        let days = reminderDays
        let upcoming = RecurringTransactionService.shared.getUpcomingTemplates(
            modelContext: modelContext,
            within: days
        )

        for template in upcoming {
            scheduleReminder(for: template)
        }

        // Also send immediate notifications for overdue (non-autopay) bills
        let overdue = RecurringTransactionService.shared.getOverdueTemplates(modelContext: modelContext)
            .filter { !$0.isAutoPay }
        for template in overdue {
            sendOverdueAlert(for: template)
        }
    }

    // MARK: - Private Scheduling

    private func scheduleReminder(for template: RecurringTemplate) {
        let content = UNMutableNotificationContent()
        content.title = "Bill Due Soon"
        content.body = "\(template.name) — \(CurrencyFormatter.shared.format(template.amount)) is due on \(formattedDate(template.nextDueDate))"
        content.sound = .default
        content.categoryIdentifier = "BILL_REMINDER"

        // Schedule for 9 AM on the day before the due date (or today if due tomorrow)
        let calendar = Calendar.current
        let reminderDate = calendar.date(byAdding: .day, value: -1, to: template.nextDueDate) ?? template.nextDueDate
        var components = calendar.dateComponents([.year, .month, .day], from: reminderDate)
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bill-reminder-\(template.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    private func sendOverdueAlert(for template: RecurringTemplate) {
        let content = UNMutableNotificationContent()
        content.title = "Overdue Bill"
        content.body = "\(template.name) — \(CurrencyFormatter.shared.format(template.amount)) was due on \(formattedDate(template.nextDueDate))"
        content.sound = .default
        content.categoryIdentifier = "BILL_OVERDUE"

        // Deliver in 2 seconds (immediate-ish)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bill-overdue-\(template.id.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - Cancel

    func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
