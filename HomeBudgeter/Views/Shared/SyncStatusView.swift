import SwiftUI

struct SyncStatusView: View {
    @State private var syncService = SyncService.shared
    @State private var authManager = AuthManager.shared

    var body: some View {
        if authManager.isSignedIn {
            HStack(spacing: 6) {
                Image(systemName: syncService.statusIcon)
                    .foregroundColor(statusColor)
                    .font(.caption)
                    .rotationEffect(syncService.status == .syncing ? .degrees(360) : .degrees(0))
                    .animation(syncService.status == .syncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: syncService.status == .syncing)

                Text(syncService.statusDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var statusColor: Color {
        switch syncService.status {
        case .idle: return .secondary
        case .syncing: return .blue
        case .succeeded: return .budgetHealthy
        case .failed: return .budgetDanger
        case .offline: return .budgetWarning
        }
    }
}
