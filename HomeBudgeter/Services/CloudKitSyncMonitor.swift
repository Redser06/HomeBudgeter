import Foundation
import SwiftData
import CoreData

@Observable
final class CloudKitSyncMonitor {
    static let shared = CloudKitSyncMonitor()

    enum SyncStatus: Equatable {
        case disabled
        case idle
        case syncing
        case succeeded(Date)
        case failed(String)
    }

    private(set) var status: SyncStatus = .disabled
    private(set) var lastSyncDate: Date?

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
    }

    var statusDescription: String {
        switch status {
        case .disabled:
            return "iCloud Sync is off"
        case .idle:
            return "Waiting to sync"
        case .syncing:
            return "Syncing…"
        case .succeeded(let date):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last synced \(formatter.localizedString(for: date, relativeTo: Date()))"
        case .failed(let error):
            return "Sync error: \(error)"
        }
    }

    var statusIcon: String {
        switch status {
        case .disabled: return "icloud.slash"
        case .idle: return "icloud"
        case .syncing: return "icloud.and.arrow.up"
        case .succeeded: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        }
    }

    private init() {
        if isEnabled {
            startObserving()
        }
    }

    func startObserving() {
        status = .idle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloudKitEvent(_:)),
            name: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil
        )
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("NSPersistentCloudKitContainer.eventChangedNotification"),
            object: nil
        )
        status = .disabled
        lastSyncDate = nil
    }

    @objc private func handleCloudKitEvent(_ notification: Notification) {
        guard let event = notification.userInfo?["event"] as? NSObject else { return }

        let endDate = event.value(forKey: "endDate") as? Date
        let succeeded = event.value(forKey: "succeeded") as? Bool ?? false
        let error = event.value(forKey: "error") as? NSError

        if endDate == nil {
            status = .syncing
        } else if let error = error, !succeeded {
            status = .failed(error.localizedDescription)
        } else {
            let now = Date()
            lastSyncDate = now
            status = .succeeded(now)
        }
    }
}
