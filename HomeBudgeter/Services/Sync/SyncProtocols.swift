import Foundation

protocol SyncDTO: Codable, Sendable {
    var syncId: UUID { get }
    var syncUpdatedAt: Date { get }
}

protocol SyncableModel {
    var id: UUID { get }
    var updatedAt: Date { get set }
}
