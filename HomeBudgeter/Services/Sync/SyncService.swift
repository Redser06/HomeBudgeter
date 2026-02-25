import Foundation
import SwiftData
import Network
import Supabase

@Observable
@MainActor
final class SyncService {
    static let shared = SyncService()

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case succeeded(Date)
        case failed(String)
        case offline
    }

    private(set) var status: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.homebudgeter.networkmonitor")
    private var isConnected = true
    private var pendingDrainContext: ModelContext?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    var statusDescription: String {
        switch status {
        case .idle: return "Ready to sync"
        case .syncing: return "Syncing..."
        case .succeeded(let date):
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Synced \(f.localizedString(for: date, relativeTo: Date()))"
        case .failed(let msg): return "Sync error: \(msg)"
        case .offline: return "Offline"
        }
    }

    var statusIcon: String {
        switch status {
        case .idle: return "arrow.triangle.2.circlepath"
        case .syncing: return "arrow.triangle.2.circlepath.circle.fill"
        case .succeeded: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        }
    }

    private init() {
        startNetworkMonitoring()
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isConnected
                self.isConnected = path.status == .satisfied

                if self.isConnected && wasOffline {
                    self.status = .idle
                    if let ctx = self.pendingDrainContext {
                        await self.drainSyncQueue(modelContext: ctx)
                    }
                } else if !self.isConnected {
                    self.status = .offline
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Full Sync

    func fullSync(modelContext: ModelContext) async {
        guard AuthManager.shared.isSignedIn else { return }
        pendingDrainContext = modelContext

        status = .syncing
        do {
            // 1. Drain any queued offline changes first
            await drainSyncQueue(modelContext: modelContext)

            // 2. Pull all remote data in dependency order
            try await pullHouseholdMembers(modelContext: modelContext)
            try await pullAccounts(modelContext: modelContext)
            try await pullBudgetCategories(modelContext: modelContext)
            try await pullRecurringTemplates(modelContext: modelContext)
            try await pullTransactions(modelContext: modelContext)
            try await pullBillLineItems(modelContext: modelContext)
            try await pullSavingsGoals(modelContext: modelContext)
            try await pullPayslips(modelContext: modelContext)
            try await pullPensionData(modelContext: modelContext)
            try await pullDocuments(modelContext: modelContext)
            try await pullInvestments(modelContext: modelContext)
            try await pullInvestmentTransactions(modelContext: modelContext)

            try modelContext.save()

            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastSyncDate")
            status = .succeeded(now)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Incremental Sync

    func incrementalSync(modelContext: ModelContext) async {
        guard AuthManager.shared.isSignedIn else { return }

        let since = lastSyncDate ?? Date(timeIntervalSince1970:
            UserDefaults.standard.double(forKey: "lastSyncDate"))

        status = .syncing
        do {
            await drainSyncQueue(modelContext: modelContext)

            let sinceISO = ISO8601DateFormatter.supabase.string(from: since)

            try await pullHouseholdMembers(modelContext: modelContext, since: sinceISO)
            try await pullAccounts(modelContext: modelContext, since: sinceISO)
            try await pullBudgetCategories(modelContext: modelContext, since: sinceISO)
            try await pullRecurringTemplates(modelContext: modelContext, since: sinceISO)
            try await pullTransactions(modelContext: modelContext, since: sinceISO)
            try await pullBillLineItems(modelContext: modelContext, since: sinceISO)
            try await pullSavingsGoals(modelContext: modelContext, since: sinceISO)
            try await pullPayslips(modelContext: modelContext, since: sinceISO)
            try await pullPensionData(modelContext: modelContext, since: sinceISO)
            try await pullDocuments(modelContext: modelContext, since: sinceISO)
            try await pullInvestments(modelContext: modelContext, since: sinceISO)
            try await pullInvestmentTransactions(modelContext: modelContext, since: sinceISO)

            try modelContext.save()

            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "lastSyncDate")
            status = .succeeded(now)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: - Push Operations

    func pushUpsert<T: SyncDTO>(table: String, recordId: UUID, dto: T, modelContext: ModelContext) async {
        guard isConnected else {
            queueOperation(table: table, recordId: recordId, operation: "upsert", dto: dto, modelContext: modelContext)
            return
        }

        do {
            try await supabase.from(table).upsert(dto, onConflict: "id").execute()
        } catch {
            queueOperation(table: table, recordId: recordId, operation: "upsert", dto: dto, modelContext: modelContext)
            print("Push upsert failed for \(table)/\(recordId): \(error.localizedDescription)")
        }
    }

    func pushDelete(table: String, recordId: UUID, modelContext: ModelContext) async {
        guard isConnected else {
            queueOperation(table: table, recordId: recordId, operation: "delete", dto: nil as HouseholdMemberDTO?, modelContext: modelContext)
            return
        }

        do {
            try await supabase.from(table).delete().eq("id", value: recordId.uuidString).execute()
        } catch {
            queueOperation(table: table, recordId: recordId, operation: "delete", dto: nil as HouseholdMemberDTO?, modelContext: modelContext)
            print("Push delete failed for \(table)/\(recordId): \(error.localizedDescription)")
        }
    }

    // MARK: - Queue Operations

    private func queueOperation<T: SyncDTO>(table: String, recordId: UUID, operation: String, dto: T?, modelContext: ModelContext) {
        let payload: Data?
        if let dto {
            payload = try? JSONEncoder.supabase.encode(dto)
        } else {
            payload = nil
        }

        let entry = SyncQueueEntry(tableName: table, recordId: recordId, operation: operation, payload: payload)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    func drainSyncQueue(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<SyncQueueEntry>(
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let entries = try? modelContext.fetch(descriptor), !entries.isEmpty else { return }
        guard isConnected else { return }

        for entry in entries {
            do {
                if entry.operation == "delete" {
                    try await supabase.from(entry.tableName)
                        .delete()
                        .eq("id", value: entry.recordId.uuidString)
                        .execute()
                } else if let payload = entry.payload {
                    try await supabase.from(entry.tableName)
                        .upsert(AnyJSON.object(
                            try JSONSerialization.jsonObject(with: payload) as? [String: AnyJSON] ?? [:]
                        ), onConflict: "id")
                        .execute()
                }
                modelContext.delete(entry)
            } catch {
                entry.retryCount += 1
                if entry.retryCount > 5 {
                    modelContext.delete(entry)
                }
                print("Queue drain failed for \(entry.tableName)/\(entry.recordId): \(error.localizedDescription)")
            }
        }

        try? modelContext.save()
    }

    // MARK: - Generic Pull

    private func pullAndReconcile<DTO: SyncDTO, Model: PersistentModel>(
        table: String,
        dtoType: DTO.Type,
        modelContext: ModelContext,
        since: String? = nil,
        fetchLocal: () throws -> [Model],
        getId: (Model) -> UUID,
        getUpdatedAt: (Model) -> Date,
        apply: (DTO, Model) -> Void,
        create: (DTO) -> Model
    ) async throws {
        var query = supabase.from(table).select()
        if let since {
            query = query.gte("updated_at", value: since)
        }

        let response = try await query.execute()
        let remoteDTOs = try JSONDecoder.supabase.decode([DTO].self, from: response.data)

        let localModels = try fetchLocal()
        let localById = Dictionary(uniqueKeysWithValues: localModels.map { (getId($0), $0) })

        for dto in remoteDTOs {
            if let existing = localById[dto.syncId] {
                // Last-write-wins: only apply if remote is newer
                if dto.syncUpdatedAt > getUpdatedAt(existing) {
                    apply(dto, existing)
                }
            } else {
                _ = create(dto)
            }
        }
    }

    // MARK: - Pull Methods

    private func pullHouseholdMembers(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "household_members", dtoType: HouseholdMemberDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<HouseholdMember>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullAccounts(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "accounts", dtoType: AccountDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<Account>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullBudgetCategories(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "budget_categories", dtoType: BudgetCategoryDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<BudgetCategory>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullRecurringTemplates(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "recurring_templates", dtoType: RecurringTemplateDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<RecurringTemplate>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullTransactions(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "transactions", dtoType: TransactionDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<Transaction>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullBillLineItems(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "bill_line_items", dtoType: BillLineItemDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<BillLineItem>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullSavingsGoals(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "savings_goals", dtoType: SavingsGoalDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<SavingsGoal>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullPayslips(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "payslips", dtoType: PayslipDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<Payslip>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullPensionData(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "pension_data", dtoType: PensionDataDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<PensionData>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullDocuments(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "documents", dtoType: DocumentDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<Document>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullInvestments(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "investments", dtoType: InvestmentDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<Investment>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }

    private func pullInvestmentTransactions(modelContext: ModelContext, since: String? = nil) async throws {
        try await pullAndReconcile(
            table: "investment_transactions", dtoType: InvestmentTransactionDTO.self,
            modelContext: modelContext, since: since,
            fetchLocal: { try modelContext.fetch(FetchDescriptor<InvestmentTransaction>()) },
            getId: { $0.id }, getUpdatedAt: { $0.updatedAt },
            apply: { SyncMapper.applyDTO($0, to: $1, context: modelContext) },
            create: { SyncMapper.createFromDTO($0, context: modelContext) }
        )
    }
}
