//
//  TaxIntelligenceService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

// MARK: - Tax Intelligence Data

struct TaxBreakdown {
    let grossAnnual: Decimal
    let incomeTax: Decimal
    let socialInsurance: Decimal
    let universalCharge: Decimal
    let pensionDeduction: Decimal
    let netAnnual: Decimal
    let effectiveRate: Double
    let marginalRate: Double
}

struct TaxInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let estimatedSaving: Decimal?
    let category: InsightCategory
    let priority: InsightPriority

    enum InsightCategory: String {
        case pension = "Pension"
        case credits = "Tax Credits"
        case reliefs = "Tax Reliefs"
        case efficiency = "Efficiency"
        case warning = "Warning"
    }

    enum InsightPriority: Int, Comparable {
        case high = 0
        case medium = 1
        case low = 2

        static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

struct TaxAnalysisResult {
    let breakdown: TaxBreakdown
    let insights: [TaxInsight]
    let locale: AppLocale
    let analysisDate: Date
    let aiSummary: String?
}

// MARK: - TaxIntelligenceService

class TaxIntelligenceService {
    static let shared = TaxIntelligenceService()
    private let keychain = KeychainManager.shared
    private let session = URLSession.shared

    private init() {}

    // MARK: - Public API

    @MainActor
    func analysePayslips(modelContext: ModelContext, locale: AppLocale) async throws -> TaxAnalysisResult {
        // Fetch all payslips
        let descriptor = FetchDescriptor<Payslip>(
            sortBy: [SortDescriptor(\.payDate, order: .reverse)]
        )
        let payslips = try modelContext.fetch(descriptor)

        guard !payslips.isEmpty else {
            return TaxAnalysisResult(
                breakdown: emptyBreakdown(),
                insights: [TaxInsight(
                    title: "No Payslip Data",
                    description: "Upload payslips to get tax analysis and optimisation suggestions.",
                    estimatedSaving: nil,
                    category: .warning,
                    priority: .high
                )],
                locale: locale,
                analysisDate: Date(),
                aiSummary: nil
            )
        }

        // Calculate breakdown from payslip data
        let breakdown = calculateBreakdown(from: payslips)

        // Generate local insights (no API needed)
        var insights = generateLocalInsights(breakdown: breakdown, payslips: payslips, locale: locale)

        // Try to get AI-powered insights if API key is available
        var aiSummary: String? = nil
        if keychain.retrieve(key: .claudeApiKey) != nil {
            do {
                let aiResult = try await fetchAIInsights(breakdown: breakdown, payslips: payslips, locale: locale)
                aiSummary = aiResult.summary
                insights.append(contentsOf: aiResult.insights)
            } catch {
                print("AI tax analysis failed (falling back to local): \(error)")
            }
        }

        // Sort by priority
        insights.sort { $0.priority < $1.priority }

        return TaxAnalysisResult(
            breakdown: breakdown,
            insights: insights,
            locale: locale,
            analysisDate: Date(),
            aiSummary: aiSummary
        )
    }

    @MainActor
    func askTaxQuestion(question: String, locale: AppLocale, modelContext: ModelContext) async throws -> String {
        guard let apiKey = keychain.retrieve(key: .claudeApiKey) else {
            throw ParsingError.noApiKeyConfigured
        }

        // Fetch recent payslips for context
        let descriptor = FetchDescriptor<Payslip>(
            sortBy: [SortDescriptor(\.payDate, order: .reverse)]
        )
        let payslips = try modelContext.fetch(descriptor)
        let breakdown = calculateBreakdown(from: payslips)

        let prompt = buildQuestionPrompt(
            question: question,
            breakdown: breakdown,
            locale: locale
        )

        return try await callClaude(prompt: prompt, apiKey: apiKey)
    }

    // MARK: - Breakdown Calculation

    private func calculateBreakdown(from payslips: [Payslip]) -> TaxBreakdown {
        guard !payslips.isEmpty else { return emptyBreakdown() }

        // Use last 12 months of payslips or all if fewer
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let recentPayslips = payslips.filter { $0.payDate >= oneYearAgo }
        let data = recentPayslips.isEmpty ? payslips : recentPayslips

        let totalGross = data.reduce(Decimal.zero) { $0 + $1.grossPay }
        let totalTax = data.reduce(Decimal.zero) { $0 + $1.incomeTax }
        let totalSI = data.reduce(Decimal.zero) { $0 + $1.socialInsurance }
        let totalUC = data.reduce(Decimal.zero) { $0 + ($1.universalCharge ?? 0) }
        let totalPension = data.reduce(Decimal.zero) { $0 + $1.pensionContribution }
        let totalNet = data.reduce(Decimal.zero) { $0 + $1.netPay }

        // Annualise if less than 12 months of data
        let monthsCovered = max(Set(data.map { calendar.dateComponents([.year, .month], from: $0.payDate) }).count, 1)
        let annualisationFactor = Decimal(12) / Decimal(monthsCovered)

        let grossAnnual = totalGross * annualisationFactor
        let taxAnnual = totalTax * annualisationFactor
        let siAnnual = totalSI * annualisationFactor
        let ucAnnual = totalUC * annualisationFactor
        let pensionAnnual = totalPension * annualisationFactor
        let netAnnual = totalNet * annualisationFactor

        let effectiveRate = grossAnnual > 0
            ? Double(truncating: ((taxAnnual + siAnnual + ucAnnual) / grossAnnual) as NSNumber) * 100
            : 0

        // Estimate marginal rate based on locale (simplified)
        let marginalRate = estimatedMarginalRate(grossAnnual: grossAnnual, locale: .ireland)

        return TaxBreakdown(
            grossAnnual: grossAnnual,
            incomeTax: taxAnnual,
            socialInsurance: siAnnual,
            universalCharge: ucAnnual,
            pensionDeduction: pensionAnnual,
            netAnnual: netAnnual,
            effectiveRate: effectiveRate,
            marginalRate: marginalRate
        )
    }

    func estimatedMarginalRate(grossAnnual: Decimal, locale: AppLocale) -> Double {
        let gross = Double(truncating: grossAnnual as NSNumber)
        switch locale {
        case .ireland:
            // 2024/2025 Irish bands: 20% up to €42,000, 40% above
            // PRSI 4%, USC varies (0.5% / 2% / 4% / 8%)
            if gross > 42_000 { return 52.0 } // 40% + 4% PRSI + 8% USC
            return 28.5 // 20% + 4% PRSI + 4.5% USC avg
        case .uk:
            if gross > 125_140 { return 45.0 + 2.0 } // Additional + NI
            if gross > 50_270 { return 40.0 + 2.0 }
            return 20.0 + 12.0
        case .usa:
            if gross > 191_950 { return 32.0 + 6.2 + 1.45 }
            if gross > 89_075 { return 22.0 + 6.2 + 1.45 }
            return 12.0 + 6.2 + 1.45
        case .eu:
            return 42.0 // Generic EU estimate
        }
    }

    // MARK: - Local Insights

    private func generateLocalInsights(breakdown: TaxBreakdown, payslips: [Payslip], locale: AppLocale) -> [TaxInsight] {
        var insights: [TaxInsight] = []

        // Pension contribution analysis
        let pensionRate = breakdown.grossAnnual > 0
            ? Double(truncating: (breakdown.pensionDeduction / breakdown.grossAnnual) as NSNumber) * 100
            : 0

        if pensionRate < 10 && breakdown.grossAnnual > 0 {
            let potentialSaving = calculatePensionTaxSaving(
                currentContribution: breakdown.pensionDeduction,
                grossAnnual: breakdown.grossAnnual,
                marginalRate: breakdown.marginalRate
            )

            insights.append(TaxInsight(
                title: "Increase Pension Contributions",
                description: "You're contributing \(String(format: "%.1f%%", pensionRate)) of gross pay to your pension. " +
                    "Increasing to the age-related limit could save significantly on tax as pension contributions " +
                    "are deducted before tax at your marginal rate of \(String(format: "%.0f%%", breakdown.marginalRate)).",
                estimatedSaving: potentialSaving,
                category: .pension,
                priority: .high
            ))
        }

        // Effective rate analysis
        if breakdown.effectiveRate > 35 {
            insights.append(TaxInsight(
                title: "High Effective Tax Rate",
                description: "Your effective tax rate is \(String(format: "%.1f%%", breakdown.effectiveRate)). " +
                    "This is above average and may indicate opportunities for tax-efficient planning.",
                estimatedSaving: nil,
                category: .efficiency,
                priority: .medium
            ))
        }

        // Employer pension analysis
        let latestPayslip = payslips.first
        if let latest = latestPayslip, latest.employerPensionContribution == 0 {
            insights.append(TaxInsight(
                title: "No Employer Pension Match",
                description: "Your latest payslip shows no employer pension contribution. " +
                    "If your employer offers matching, you may be leaving free money on the table.",
                estimatedSaving: nil,
                category: .pension,
                priority: .medium
            ))
        }

        // Consistency check
        if payslips.count >= 2 {
            let amounts = payslips.prefix(6).map { $0.incomeTax }
            let first = amounts.first ?? 0
            let hasVariation = amounts.contains { abs($0 - first) > first * Decimal(string: "0.1")! }
            if hasVariation {
                insights.append(TaxInsight(
                    title: "Tax Deduction Variation Detected",
                    description: "Your tax deductions have varied by more than 10% across recent payslips. " +
                        "This could indicate emergency tax, a tax credit change, or a payroll adjustment.",
                    estimatedSaving: nil,
                    category: .warning,
                    priority: .high
                ))
            }
        }

        return insights
    }

    private func calculatePensionTaxSaving(currentContribution: Decimal, grossAnnual: Decimal, marginalRate: Double) -> Decimal {
        // Simplified: assume increasing contribution by 5% of gross
        let additionalContribution = grossAnnual * Decimal(string: "0.05")!
        let taxSaving = additionalContribution * Decimal(marginalRate / 100)
        return taxSaving
    }

    // MARK: - AI Insights

    struct AIInsightResult {
        let summary: String
        let insights: [TaxInsight]
    }

    private func fetchAIInsights(breakdown: TaxBreakdown, payslips: [Payslip], locale: AppLocale) async throws -> AIInsightResult {
        guard let apiKey = keychain.retrieve(key: .claudeApiKey) else {
            throw ParsingError.noApiKeyConfigured
        }

        let prompt = buildAnalysisPrompt(breakdown: breakdown, payslips: payslips, locale: locale)
        let response = try await callClaude(prompt: prompt, apiKey: apiKey)

        return parseAIResponse(response)
    }

    private func buildAnalysisPrompt(breakdown: TaxBreakdown, payslips: [Payslip], locale: AppLocale) -> String {
        let latestPayslip = payslips.first
        let taxLabels = locale.taxLabels

        return """
        You are a tax advisor assistant for \(locale.displayName). Analyse this tax situation and provide actionable insights.

        IMPORTANT: This is informational only, not financial advice. Include this disclaimer.

        Annual figures (estimated from payslips):
        - Gross income: \(CurrencyFormatter.shared.format(breakdown.grossAnnual))
        - \(taxLabels.incomeTax): \(CurrencyFormatter.shared.format(breakdown.incomeTax))
        - \(taxLabels.socialInsurance): \(CurrencyFormatter.shared.format(breakdown.socialInsurance))
        \(taxLabels.universalCharge.map { "- \($0): \(CurrencyFormatter.shared.format(breakdown.universalCharge))" } ?? "")
        - Pension contribution: \(CurrencyFormatter.shared.format(breakdown.pensionDeduction))
        - Net income: \(CurrencyFormatter.shared.format(breakdown.netAnnual))
        - Effective tax rate: \(String(format: "%.1f%%", breakdown.effectiveRate))
        - Marginal rate: \(String(format: "%.0f%%", breakdown.marginalRate))
        \(latestPayslip.map { "- Employer pension: \(CurrencyFormatter.shared.format($0.employerPensionContribution))/month" } ?? "")

        Provide your response as JSON with this structure:
        {
          "summary": "2-3 sentence overview of the tax situation",
          "insights": [
            {
              "title": "Short title",
              "description": "Detailed actionable description",
              "estimated_annual_saving": 500.00 or null,
              "category": "pension|credits|reliefs|efficiency",
              "priority": "high|medium|low"
            }
          ]
        }

        Focus on \(locale.displayName)-specific tax rules, credits, and reliefs. Max 5 insights.
        """
    }

    private func buildQuestionPrompt(question: String, breakdown: TaxBreakdown, locale: AppLocale) -> String {
        let taxLabels = locale.taxLabels

        return """
        You are a helpful tax information assistant for \(locale.displayName).

        Context — the user's annual tax situation:
        - Gross: \(CurrencyFormatter.shared.format(breakdown.grossAnnual))
        - \(taxLabels.incomeTax): \(CurrencyFormatter.shared.format(breakdown.incomeTax))
        - \(taxLabels.socialInsurance): \(CurrencyFormatter.shared.format(breakdown.socialInsurance))
        - Effective rate: \(String(format: "%.1f%%", breakdown.effectiveRate))
        - Marginal rate: \(String(format: "%.0f%%", breakdown.marginalRate))

        IMPORTANT: You are not a qualified tax advisor. Always include a disclaimer that this is informational only and the user should consult a qualified tax professional.

        User question: \(question)

        Answer clearly and concisely, referencing \(locale.displayName) tax rules where relevant.
        """
    }

    func parseAIResponse(_ response: String) -> AIInsightResult {
        // Strip markdown code fences (```json ... ```) that LLMs commonly wrap responses in
        let cleaned = stripMarkdownCodeFences(response)

        guard let jsonData = cleaned.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            // If JSON parsing still fails, don't show raw JSON — provide a generic fallback
            let looksLikeJSON = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
            let fallbackSummary = looksLikeJSON
                ? "AI analysis completed. See insights below for details."
                : response
            return AIInsightResult(summary: fallbackSummary, insights: [])
        }

        let summary = json["summary"] as? String ?? "AI analysis completed. See insights below for details."

        var insights: [TaxInsight] = []
        if let insightsArray = json["insights"] as? [[String: Any]] {
            for item in insightsArray {
                let title = item["title"] as? String ?? "Tax Insight"
                let desc = item["description"] as? String ?? ""
                let saving: Decimal? = (item["estimated_annual_saving"] as? Double).flatMap { Decimal(string: String($0)) }
                let categoryRaw = item["category"] as? String ?? "efficiency"
                let priorityRaw = item["priority"] as? String ?? "medium"

                let category: TaxInsight.InsightCategory
                switch categoryRaw {
                case "pension": category = .pension
                case "credits": category = .credits
                case "reliefs": category = .reliefs
                default: category = .efficiency
                }

                let priority: TaxInsight.InsightPriority
                switch priorityRaw {
                case "high": priority = .high
                case "low": priority = .low
                default: priority = .medium
                }

                insights.append(TaxInsight(
                    title: title,
                    description: desc,
                    estimatedSaving: saving,
                    category: category,
                    priority: priority
                ))
            }
        }

        return AIInsightResult(summary: summary, insights: insights)
    }

    // MARK: - Claude API

    private func callClaude(prompt: String, apiKey: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParsingError.apiRequestFailed("No HTTP response received")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ParsingError.apiRequestFailed("Claude API returned status \(httpResponse.statusCode): \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String
        else {
            throw ParsingError.invalidResponse("Could not extract text from Claude response")
        }

        return text
    }

    // MARK: - Helpers

    func stripMarkdownCodeFences(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove opening fence like ```json or ```
        if result.hasPrefix("```") {
            if let newlineIndex = result.firstIndex(of: "\n") {
                result = String(result[result.index(after: newlineIndex)...])
            }
        }
        // Remove closing fence
        if result.hasSuffix("```") {
            result = String(result.dropLast(3))
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func emptyBreakdown() -> TaxBreakdown {
        TaxBreakdown(
            grossAnnual: 0, incomeTax: 0, socialInsurance: 0,
            universalCharge: 0, pensionDeduction: 0, netAnnual: 0,
            effectiveRate: 0, marginalRate: 0
        )
    }
}
