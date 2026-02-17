//
//  BillMigrationService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

/// Migrates legacy 6-case BillType tags to the new 13-case granular tags.
/// Runs once on launch, gated by a UserDefaults flag.
final class BillMigrationService {
    static let shared = BillMigrationService()

    private static let migrationKey = "billSegmentationMigrationV1"

    private init() {}

    /// Run migration if it hasn't been performed yet.
    @MainActor
    func migrateIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else { return }

        migrate(modelContext: modelContext)

        UserDefaults.standard.set(true, forKey: Self.migrationKey)
    }

    /// Performs the actual migration: rewrites legacy tags and creates BillLineItem records.
    @MainActor
    func migrate(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { transaction in
                transaction.notes != nil
            }
        )

        guard let transactions = try? modelContext.fetch(descriptor) else { return }

        for transaction in transactions {
            guard let notes = transaction.notes else { continue }

            var newNotes = notes
            var createdLineItems = false

            for (legacyRaw, mappedTypes) in BillType.legacyMappings {
                let legacyTag = "[\(legacyRaw)]"
                guard newNotes.contains(legacyTag) else { continue }

                // Replace legacy tag with new granular tags
                let newTags = mappedTypes.map { "[\($0.rawValue)]" }.joined()
                newNotes = newNotes.replacingOccurrences(of: legacyTag, with: newTags)

                // Create BillLineItem records if none exist
                let existingItems = transaction.billLineItems ?? []
                if existingItems.isEmpty {
                    // Split amount equally across inferred types
                    let splitCount = Decimal(mappedTypes.count)
                    let splitAmount = transaction.amount / splitCount

                    // Try to refine types using vendor keywords
                    let inferredTypes = BillType.inferAll(from: transaction.descriptionText)

                    // Use inferred types if they're a subset of the mapped types,
                    // otherwise fall back to mapped types
                    let typesToUse: [BillType]
                    if !inferredTypes.isEmpty && inferredTypes.allSatisfy({ mappedTypes.contains($0) }) {
                        typesToUse = inferredTypes
                    } else {
                        typesToUse = mappedTypes
                    }

                    let itemAmount = transaction.amount / Decimal(typesToUse.count)
                    for type in typesToUse {
                        let lineItem = BillLineItem(
                            billType: type,
                            amount: itemAmount,
                            label: nil,
                            transaction: transaction
                        )
                        modelContext.insert(lineItem)
                    }
                    createdLineItems = true
                }
            }

            if newNotes != notes {
                transaction.notes = newNotes
            }

            // For non-legacy bills that have tags but no line items, create a single line item
            if !createdLineItems {
                let existingItems = transaction.billLineItems ?? []
                if existingItems.isEmpty {
                    for type in BillType.allCases {
                        if newNotes.contains("[\(type.rawValue)]") {
                            let lineItem = BillLineItem(
                                billType: type,
                                amount: transaction.amount,
                                label: nil,
                                transaction: transaction
                            )
                            modelContext.insert(lineItem)
                            break
                        }
                    }
                }
            }
        }

        try? modelContext.save()
    }
}
