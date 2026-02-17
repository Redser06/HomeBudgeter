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

    var priceIncreaseTemplates: [RecurringTemplate] {
        templates.filter { $0.isActive && $0.hasPriceIncrease }
    }

    var cancellationSuggestions: [CancellationSuggestion] {
        analyseSubscriptionValue()
    }

    struct CancellationSuggestion: Identifiable {
        let id: UUID
        let template: RecurringTemplate
        let reason: String
        let score: Int // 0-100, lower = more likely should cancel
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

    // MARK: - Price Tracking

    func updatePriceHistory(for template: RecurringTemplate, modelContext: ModelContext) {
        // Record the current amount
        template.recordPrice(template.amount)
        template.updatedAt = Date()
        try? modelContext.save()
    }

    func refreshPriceHistories(modelContext: ModelContext) {
        for template in templates where template.isActive {
            // Build price history from generated transactions if empty
            if template.priceHistory.isEmpty {
                let sorted = template.generatedTransactions.sorted { $0.date < $1.date }
                for transaction in sorted {
                    template.recordPrice(transaction.amount, date: transaction.date)
                }
            }
        }
        try? modelContext.save()
    }

    // MARK: - Cancellation Analysis

    private func analyseSubscriptionValue() -> [CancellationSuggestion] {
        let totalMonthly = monthlyCost
        guard totalMonthly > 0 else { return [] }

        var suggestions: [CancellationSuggestion] = []

        for template in templates where template.isActive {
            var score = 100 // Start at 100, subtract for risk factors
            var reasons: [String] = []

            // Factor 1: Cost as percentage of total recurring spend
            let costShare = Double(truncating: (template.monthlyEquivalentAmount / totalMonthly) as NSNumber) * 100
            if costShare > 25 {
                score -= 20
                reasons.append("High cost (\(String(format: "%.0f%%", costShare)) of recurring spend)")
            } else if costShare > 15 {
                score -= 10
            }

            // Factor 2: Price has been increasing
            if template.hasPriceIncrease {
                score -= 15
                if let pct = template.priceIncreasePercentage {
                    reasons.append("Price up \(String(format: "%.0f%%", pct)) since tracking started")
                }
            }

            // Factor 3: Stale / possibly unused (no transactions recently)
            let recentTransactions = template.generatedTransactions.filter {
                $0.date > Calendar.current.date(byAdding: .month, value: -3, to: Date())!
            }
            if recentTransactions.isEmpty && template.generatedTransactions.count > 0 {
                score -= 25
                reasons.append("No transactions in the last 3 months")
            }

            // Factor 4: Variable amount templates with high variance
            if template.isVariableAmount {
                score -= 5
            }

            // Only suggest if score drops below 70
            if score < 70 && !reasons.isEmpty {
                suggestions.append(CancellationSuggestion(
                    id: template.id,
                    template: template,
                    reason: reasons.joined(separator: ". "),
                    score: max(score, 0)
                ))
            }
        }

        return suggestions.sorted { $0.score < $1.score }
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
