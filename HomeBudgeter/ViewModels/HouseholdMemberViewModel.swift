import Foundation
import SwiftData
import SwiftUI

@Observable
class HouseholdMemberViewModel {
    var members: [HouseholdMember] = []
    var showingCreateSheet: Bool = false
    var selectedMember: HouseholdMember?

    static let colorPalette: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Green", "#34C759"),
        ("Red", "#FF3B30"),
        ("Orange", "#FF9500"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Teal", "#5AC8FA"),
        ("Indigo", "#5856D6")
    ]

    static let iconOptions: [String] = [
        "person.circle.fill",
        "person.fill",
        "figure.stand",
        "figure.dress.line.vertical.figure",
        "star.circle.fill",
        "heart.circle.fill",
        "house.fill",
        "briefcase.fill"
    ]

    // MARK: - Data Methods

    @MainActor
    func loadMembers(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<HouseholdMember>(
            sortBy: [SortDescriptor(\.name)]
        )

        do {
            members = try modelContext.fetch(descriptor)
        } catch {
            print("Error loading household members: \(error)")
        }
    }

    @MainActor
    func addMember(
        name: String,
        colorHex: String,
        icon: String,
        isDefault: Bool,
        modelContext: ModelContext
    ) {
        if isDefault {
            clearDefaultFlag(modelContext: modelContext)
        }

        let member = HouseholdMember(
            name: name,
            colorHex: colorHex,
            icon: icon,
            isDefault: isDefault
        )
        modelContext.insert(member)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(member, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "household_members", recordId: member.id, dto: dto, modelContext: modelContext) }
            }

            loadMembers(modelContext: modelContext)
        } catch {
            print("Error saving household member: \(error)")
        }
    }

    @MainActor
    func updateMember(
        _ member: HouseholdMember,
        name: String,
        colorHex: String,
        icon: String,
        isDefault: Bool,
        modelContext: ModelContext
    ) {
        if isDefault && !member.isDefault {
            clearDefaultFlag(modelContext: modelContext)
        }

        member.name = name
        member.colorHex = colorHex
        member.icon = icon
        member.isDefault = isDefault
        member.updatedAt = Date()

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(member, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "household_members", recordId: member.id, dto: dto, modelContext: modelContext) }
            }

            loadMembers(modelContext: modelContext)
        } catch {
            print("Error updating household member: \(error)")
        }
    }

    @MainActor
    func deleteMember(_ member: HouseholdMember, modelContext: ModelContext) {
        let recordId = member.id
        modelContext.delete(member)

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                Task { await SyncService.shared.pushDelete(table: "household_members", recordId: recordId, modelContext: modelContext) }
            }

            loadMembers(modelContext: modelContext)
        } catch {
            print("Error deleting household member: \(error)")
        }
    }

    @MainActor
    func setDefault(_ member: HouseholdMember, modelContext: ModelContext) {
        clearDefaultFlag(modelContext: modelContext)
        member.isDefault = true
        member.updatedAt = Date()

        do {
            try modelContext.save()

            if let userId = AuthManager.shared.currentUserId {
                let dto = SyncMapper.toDTO(member, userId: userId)
                Task { await SyncService.shared.pushUpsert(table: "household_members", recordId: member.id, dto: dto, modelContext: modelContext) }
            }

            loadMembers(modelContext: modelContext)
        } catch {
            print("Error setting default member: \(error)")
        }
    }

    var defaultMember: HouseholdMember? {
        members.first { $0.isDefault }
    }

    // MARK: - Private

    @MainActor
    private func clearDefaultFlag(modelContext: ModelContext) {
        for m in members where m.isDefault {
            m.isDefault = false
        }
    }
}
