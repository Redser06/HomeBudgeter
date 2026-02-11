//
//  RecurringTransactionService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@MainActor
final class RecurringTransactionService {
    static let shared = RecurringTransactionService()
    private init() {}

    // MARK: - Generate Due Transactions

    func generateDueTransactions(modelContext: ModelContext) {
        let now = Date()
        let descriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate { template in
                template.isActive && template.nextDueDate <= now
            }
        )

        do {
            let dueTemplates = try modelContext.fetch(descriptor)
            for template in dueTemplates {
                // Check end date
                if let endDate = template.endDate, template.nextDueDate > endDate {
                    template.isActive = false
                    continue
                }

                // Create child transaction
                let transaction = Transaction(
                    amount: template.amount,
                    date: template.nextDueDate,
                    descriptionText: template.name,
                    type: template.type,
                    isRecurring: false,
                    notes: template.notes,
                    category: template.category,
                    account: template.account
                )
                transaction.parentTemplate = template
                modelContext.insert(transaction)
                template.generatedTransactions.append(transaction)

                // Advance next due date
                template.lastProcessedDate = template.nextDueDate
                if let next = calculateNextDueDate(from: template.nextDueDate, frequency: template.frequency) {
                    if let endDate = template.endDate, next > endDate {
                        template.isActive = false
                    } else {
                        template.nextDueDate = next
                    }
                }
                template.updatedAt = Date()
            }
            try modelContext.save()
        } catch {
            print("Error generating recurring transactions: \(error)")
        }
    }

    // MARK: - Calculate Next Due Date

    func calculateNextDueDate(from date: Date, frequency: RecurringFrequency) -> Date? {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: date)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: date)
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
    }

    // MARK: - Queries

    func getOverdueTemplates(modelContext: ModelContext) -> [RecurringTemplate] {
        let now = Date()
        let descriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate { template in
                template.isActive && template.nextDueDate < now
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func getUpcomingTemplates(modelContext: ModelContext, within days: Int = 7) -> [RecurringTemplate] {
        let now = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let descriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate { template in
                template.isActive && template.nextDueDate >= now && template.nextDueDate <= futureDate
            },
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
