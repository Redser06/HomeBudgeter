//
//  RecurringViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class RecurringViewModel {
    var templates: [RecurringTemplate] = []
    var showingCreateSheet: Bool = false
    var selectedTemplate: RecurringTemplate?

    var overdueTemplates: [RecurringTemplate] {
        templates.filter { $0.isOverdue }
    }

    var activeTemplates: [RecurringTemplate] {
        templates.filter { $0.isActive && !$0.isOverdue }
    }

    var pausedTemplates: [RecurringTemplate] {
        templates.filter { !$0.isActive }
    }

    var monthlyCost: Decimal {
        templates.filter { $0.isActive }.reduce(0) { $0 + $1.monthlyEquivalentAmount }
    }

    // MARK: - Data Methods

    func loadTemplates(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<RecurringTemplate>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        do {
            let fetched = try modelContext.fetch(descriptor)
            // Sort: overdue first, then by nextDueDate
            templates = fetched.sorted { lhs, rhs in
                if lhs.isOverdue != rhs.isOverdue {
                    return lhs.isOverdue
                }
                return lhs.nextDueDate < rhs.nextDueDate
            }
        } catch {
            print("Error loading recurring templates: \(error)")
        }
    }

    func createTemplate(
        name: String,
        amount: Decimal,
        type: TransactionType = .expense,
        frequency: RecurringFrequency,
        startDate: Date = Date(),
        endDate: Date? = nil,
        notes: String? = nil,
        category: BudgetCategory? = nil,
        account: Account? = nil,
        modelContext: ModelContext
    ) {
        let template = RecurringTemplate(
            name: name,
            amount: amount,
            type: type,
            frequency: frequency,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            category: category,
            account: account
        )
        modelContext.insert(template)
        try? modelContext.save()
        loadTemplates(modelContext: modelContext)
    }

    func deleteTemplate(_ template: RecurringTemplate, modelContext: ModelContext) {
        modelContext.delete(template)
        try? modelContext.save()
        loadTemplates(modelContext: modelContext)
    }

    func pauseTemplate(_ template: RecurringTemplate, modelContext: ModelContext) {
        template.isActive = false
        template.updatedAt = Date()
        try? modelContext.save()
        loadTemplates(modelContext: modelContext)
    }

    func resumeTemplate(_ template: RecurringTemplate, modelContext: ModelContext) {
        template.isActive = true
        template.updatedAt = Date()
        try? modelContext.save()
        loadTemplates(modelContext: modelContext)
    }

    @MainActor
    func processOverdue(modelContext: ModelContext) {
        RecurringTransactionService.shared.generateDueTransactions(modelContext: modelContext)
        loadTemplates(modelContext: modelContext)
    }

    // MARK: - Create Template from Detection

    @MainActor
    func createTemplateFromDetection(
        _ result: RecurringBillDetector.DetectionResult,
        frequency: RecurringFrequency,
        amount: Decimal,
        isAutoPay: Bool = false,
        modelContext: ModelContext
    ) {
        let latestDate = result.matchingTransactions.last?.date ?? Date()
        let nextDueDate = RecurringTransactionService.shared.calculateNextDueDate(
            from: latestDate,
            frequency: frequency
        ) ?? latestDate

        let template = RecurringTemplate(
            name: result.vendor,
            amount: amount,
            type: .expense,
            frequency: frequency,
            startDate: result.matchingTransactions.first?.date ?? Date(),
            nextDueDate: nextDueDate,
            isActive: true,
            isVariableAmount: result.isVariableAmount,
            isAutoPay: isAutoPay,
            notes: result.suggestedNotes
        )

        modelContext.insert(template)

        // Retroactively link existing transactions
        for transaction in result.matchingTransactions {
            transaction.parentTemplate = template
            template.generatedTransactions.append(transaction)
        }

        try? modelContext.save()
        loadTemplates(modelContext: modelContext)
    }
}
