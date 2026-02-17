//
//  TaxInsightsViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@Observable
class TaxInsightsViewModel {
    var analysisResult: TaxAnalysisResult?
    var isLoading = false
    var errorMessage: String?

    // Chat
    var chatQuestion = ""
    var chatMessages: [ChatMessage] = []
    var isChatLoading = false

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: Role
        let text: String
        let timestamp = Date()

        enum Role {
            case user, assistant
        }
    }

    // Tax Year Summary
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    var availableYears: [Int] = []
    var yearSummary: TaxYearSummary?
    var isYearSummaryLoading = false

    // Computed
    var breakdown: TaxBreakdown? { analysisResult?.breakdown }
    var insights: [TaxInsight] { analysisResult?.insights ?? [] }
    var aiSummary: String? { analysisResult?.aiSummary }
    var hasApiKey: Bool { KeychainManager.shared.retrieve(key: .claudeApiKey) != nil }

    var highPriorityInsights: [TaxInsight] {
        insights.filter { $0.priority == .high }
    }

    var totalEstimatedSavings: Decimal {
        insights.compactMap(\.estimatedSaving).reduce(Decimal.zero, +)
    }

    @MainActor
    func loadAnalysis(modelContext: ModelContext, locale: AppLocale) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await TaxIntelligenceService.shared.analysePayslips(
                    modelContext: modelContext,
                    locale: locale
                )
                self.analysisResult = result
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    @MainActor
    func sendChatQuestion(modelContext: ModelContext, locale: AppLocale) {
        let question = chatQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        chatMessages.append(ChatMessage(role: .user, text: question))
        chatQuestion = ""
        isChatLoading = true

        Task {
            do {
                let response = try await TaxIntelligenceService.shared.askTaxQuestion(
                    question: question,
                    locale: locale,
                    modelContext: modelContext
                )
                self.chatMessages.append(ChatMessage(role: .assistant, text: response))
            } catch {
                self.chatMessages.append(ChatMessage(
                    role: .assistant,
                    text: "Sorry, I couldn't process that question: \(error.localizedDescription)"
                ))
            }
            self.isChatLoading = false
        }
    }

    // MARK: - Tax Year Summary

    @MainActor
    func loadYearSummary(modelContext: ModelContext, locale: AppLocale) {
        isYearSummaryLoading = true
        do {
            availableYears = try TaxYearSummaryService.shared.availableYears(modelContext: modelContext)
            if !availableYears.contains(selectedYear), let first = availableYears.first {
                selectedYear = first
            }
            yearSummary = try TaxYearSummaryService.shared.generateSummary(
                year: selectedYear,
                modelContext: modelContext,
                locale: locale
            )
        } catch {
            print("Tax year summary error: \(error)")
        }
        isYearSummaryLoading = false
    }
}
