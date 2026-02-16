//
//  RecurringBillDetector.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@MainActor
final class RecurringBillDetector {
    static let shared = RecurringBillDetector()
    private init() {}

    struct DetectionResult {
        let vendor: String
        let matchingTransactions: [Transaction]
        let suggestedFrequency: RecurringFrequency
        let suggestedAmount: Decimal
        let averageAmount: Decimal
        let isVariableAmount: Bool
        let billTypes: [BillType]
        let suggestedNotes: String?
        let hasBillTags: Bool
    }

    func detectRecurringPattern(for vendor: String, modelContext: ModelContext) -> DetectionResult? {
        let lowercasedVendor = vendor.lowercased()

        // Fetch all transactions
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date)]
        )

        guard let allTransactions = try? modelContext.fetch(descriptor) else { return nil }

        // Filter to matching vendor with no parentTemplate
        let matching = allTransactions.filter { transaction in
            transaction.descriptionText.lowercased() == lowercasedVendor
                && transaction.parentTemplate == nil
        }

        guard matching.count >= 2 else { return nil }

        // Check if an active RecurringTemplate already exists for this vendor
        let templateDescriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate<RecurringTemplate> { template in
                template.isActive
            }
        )

        if let templates = try? modelContext.fetch(templateDescriptor) {
            let hasExisting = templates.contains { $0.name.lowercased() == lowercasedVendor }
            if hasExisting { return nil }
        }

        // Sort by date
        let sorted = matching.sorted { $0.date < $1.date }

        // Infer frequency from average gap between sorted dates
        let frequency = inferFrequency(from: sorted)

        // Detect variable amounts
        let amounts = sorted.map { $0.amount }
        let minAmount = amounts.min() ?? 0
        let maxAmount = amounts.max() ?? 0
        let averageAmount = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)
        let isVariable: Bool
        if minAmount > 0 {
            let variation = (maxAmount - minAmount) / minAmount
            isVariable = variation > Decimal(string: "0.05")!
        } else {
            isVariable = maxAmount != minAmount
        }

        // Use latest bill's amount as suggested
        let suggestedAmount = sorted.last?.amount ?? averageAmount

        // Extract bill types from notes (optional enrichment)
        var billTypeSet: [BillType] = []
        var hasBillTags = false
        for transaction in sorted {
            let types = BillsViewModel.extractBillTypes(from: transaction.notes)
            if !types.isEmpty { hasBillTags = true }
            for type in types where !billTypeSet.contains(type) {
                billTypeSet.append(type)
            }
        }

        // Build suggested notes from bill type tags
        let tagNotes = billTypeSet.map { "[\($0.rawValue)]" }.joined()

        return DetectionResult(
            vendor: vendor,
            matchingTransactions: sorted,
            suggestedFrequency: frequency,
            suggestedAmount: suggestedAmount,
            averageAmount: averageAmount,
            isVariableAmount: isVariable,
            billTypes: billTypeSet,
            suggestedNotes: tagNotes.isEmpty ? nil : tagNotes,
            hasBillTags: hasBillTags
        )
    }

    private func inferFrequency(from sortedTransactions: [Transaction]) -> RecurringFrequency {
        guard sortedTransactions.count >= 2 else { return .monthly }

        let calendar = Calendar.current
        var totalDays = 0
        for i in 1..<sortedTransactions.count {
            let days = calendar.dateComponents([.day], from: sortedTransactions[i - 1].date, to: sortedTransactions[i].date).day ?? 30
            totalDays += days
        }
        let averageGap = totalDays / (sortedTransactions.count - 1)

        switch averageGap {
        case 0...10:
            return .weekly
        case 11...21:
            return .biweekly
        case 22...45:
            return .monthly
        case 46...120:
            return .quarterly
        default:
            return .yearly
        }
    }
}
