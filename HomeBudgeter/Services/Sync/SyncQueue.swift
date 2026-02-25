import Foundation
import SwiftData

@Model
final class SyncQueueEntry {
    @Attribute(.unique) var id: UUID
    var tableName: String
    var recordId: UUID
    var operation: String // "upsert" or "delete"
    var payload: Data?
    var retryCount: Int
    var createdAt: Date

    init(
        tableName: String,
        recordId: UUID,
        operation: String,
        payload: Data? = nil
    ) {
        self.id = UUID()
        self.tableName = tableName
        self.recordId = recordId
        self.operation = operation
        self.payload = payload
        self.retryCount = 0
        self.createdAt = Date()
    }
}
