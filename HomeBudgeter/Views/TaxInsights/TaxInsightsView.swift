//
//  TaxInsightsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import Charts

struct TaxInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TaxInsightsViewModel()
    @AppStorage("selectedLocale") private var selectedLocaleRaw: String = AppLocale.ireland.rawValue

    private var locale: AppLocale {
        AppLocale(rawValue: selectedLocaleRaw) ?? .ireland
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if viewModel.isLoading {
                    ProgressView("Analysing your tax data...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = viewModel.errorMessage {
                    errorSection(error)
                } else if viewModel.breakdown != nil {
                    disclaimerBanner
                    taxBreakdownSection
                    insightsSection
                    taxYearSummarySection
                    chatSection
                }
            }
            .padding(.vertical)
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadAnalysis(modelContext: modelContext, locale: locale)
            viewModel.loadYearSummary(modelContext: modelContext, locale: locale)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tax Insights")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text(locale.flag)
                    Text(locale.displayName)
                        .foregroundColor(.secondary)

                    if !viewModel.hasApiKey {
                        Text("Local analysis only")
                            .font(.caption)
                            .foregroundColor(.budgetWarning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.budgetWarning.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            Spacer()

            Button {
                viewModel.loadAnalysis(modelContext: modelContext, locale: locale)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    // MARK: - Disclaimer

    private var disclaimerBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.primaryBlue)

            Text("This is for informational purposes only and does not constitute financial or tax advice. Consult a qualified tax professional for personal guidance.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.primaryBlue.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primaryBlue.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Tax Breakdown

    private var taxBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Annual Tax Breakdown")
                .font(.headline)

            if let breakdown = viewModel.breakdown {
                HStack(spacing: 16) {
                    // Donut chart
                    taxDonutChart(breakdown: breakdown)
                        .frame(width: 200, height: 200)

                    // Detail rows
                    VStack(alignment: .leading, spacing: 10) {
                        taxRow(label: "Gross Income", amount: breakdown.grossAnnual, color: .budgetHealthy)
                        Divider()
                        taxRow(label: locale.taxLabels.incomeTax, amount: breakdown.incomeTax, color: .budgetDanger)
                        taxRow(label: locale.taxLabels.socialInsurance, amount: breakdown.socialInsurance, color: .budgetWarning)
                        if let ucLabel = locale.taxLabels.universalCharge {
                            taxRow(label: ucLabel, amount: breakdown.universalCharge, color: .orange)
                        }
                        taxRow(label: "Pension", amount: breakdown.pensionDeduction, color: .primaryBlue)
                        Divider()
                        taxRow(label: "Net Income", amount: breakdown.netAnnual, color: .budgetHealthy, bold: true)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Rate cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    rateCard(title: "Effective Tax Rate", rate: breakdown.effectiveRate, description: "All taxes as % of gross")
                    rateCard(title: "Marginal Rate", rate: breakdown.marginalRate, description: "Rate on next euro earned")
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func taxDonutChart(breakdown: TaxBreakdown) -> some View {
        let segments: [(String, Double, Color)] = [
            ("Net", Double(truncating: breakdown.netAnnual as NSNumber), Color.budgetHealthy),
            (locale.taxLabels.incomeTax, Double(truncating: breakdown.incomeTax as NSNumber), Color.budgetDanger),
            (locale.taxLabels.socialInsurance, Double(truncating: breakdown.socialInsurance as NSNumber), Color.budgetWarning),
            ("Pension", Double(truncating: breakdown.pensionDeduction as NSNumber), Color.primaryBlue)
        ].filter { $0.1 > 0 }

        return Chart(segments, id: \.0) { segment in
            SectorMark(
                angle: .value("Amount", segment.1),
                innerRadius: .ratio(0.55),
                angularInset: 1.5
            )
            .foregroundStyle(segment.2)
            .cornerRadius(3)
        }
    }

    private func taxRow(label: String, amount: Decimal, color: Color, bold: Bool = false) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)
                .fontWeight(bold ? .semibold : .regular)

            Spacer()

            Text(CurrencyFormatter.shared.format(amount))
                .font(.subheadline)
                .fontWeight(bold ? .bold : .medium)
                .foregroundColor(color)
        }
    }

    private func rateCard(title: String, rate: Double, description: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f%%", rate))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(rate > 40 ? .budgetDanger : .primary)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.budgetWarning)
                Text("Tax Optimisation Insights")
                    .font(.headline)
                Spacer()
                if viewModel.totalEstimatedSavings > 0 {
                    Text("~\(CurrencyFormatter.shared.format(viewModel.totalEstimatedSavings))/yr potential savings")
                        .font(.caption)
                        .foregroundColor(.budgetHealthy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.budgetHealthy.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if let summary = viewModel.aiSummary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Color.primaryBlue.opacity(0.04))
                    .cornerRadius(8)
            }

            if viewModel.insights.isEmpty {
                ContentUnavailableView(
                    "No Insights Available",
                    systemImage: "lightbulb.slash",
                    description: Text("Upload payslips to get personalised tax insights")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.insights) { insight in
                        insightCard(insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func insightCard(insight: TaxInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insightIcon(for: insight.category))
                .foregroundColor(insightColor(for: insight.category))
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    priorityBadge(insight.priority)
                }

                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let saving = insight.estimatedSaving, saving > 0 {
                    Text("Estimated saving: ~\(CurrencyFormatter.shared.format(saving))/year")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.budgetHealthy)
                }
            }
        }
        .padding(12)
        .background(insightColor(for: insight.category).opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(insightColor(for: insight.category).opacity(0.12), lineWidth: 1)
        )
    }

    private func insightIcon(for category: TaxInsight.InsightCategory) -> String {
        switch category {
        case .pension: return "building.columns.fill"
        case .credits: return "checkmark.seal.fill"
        case .reliefs: return "gift.fill"
        case .efficiency: return "gauge.with.dots.needle.67percent"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func insightColor(for category: TaxInsight.InsightCategory) -> Color {
        switch category {
        case .pension: return .primaryBlue
        case .credits: return .budgetHealthy
        case .reliefs: return .purple
        case .efficiency: return .budgetWarning
        case .warning: return .budgetDanger
        }
    }

    private func priorityBadge(_ priority: TaxInsight.InsightPriority) -> some View {
        Text(priorityText(priority))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(priorityColor(priority))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(priorityColor(priority).opacity(0.1))
            .cornerRadius(4)
    }

    private func priorityText(_ priority: TaxInsight.InsightPriority) -> String {
        switch priority {
        case .high: return "HIGH"
        case .medium: return "MED"
        case .low: return "LOW"
        }
    }

    private func priorityColor(_ priority: TaxInsight.InsightPriority) -> Color {
        switch priority {
        case .high: return .budgetDanger
        case .medium: return .budgetWarning
        case .low: return .secondary
        }
    }

    // MARK: - Tax Year Summary

    private var taxYearSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.primaryBlue)
                Text("Tax Year Summary")
                    .font(.headline)
                Spacer()

                if !viewModel.availableYears.isEmpty {
                    Picker("Year", selection: $viewModel.selectedYear) {
                        ForEach(viewModel.availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .frame(width: 100)
                    .onChange(of: viewModel.selectedYear) { _, _ in
                        viewModel.loadYearSummary(modelContext: modelContext, locale: locale)
                    }
                }

                Button {
                    exportYearSummaryPDF()
                } label: {
                    Label("Export for Accountant", systemImage: "doc.richtext")
                }
                .buttonStyle(.bordered)
            }

            if viewModel.isYearSummaryLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if let summary = viewModel.yearSummary {
                if summary.payslipCount == 0 {
                    ContentUnavailableView(
                        "No Payslips for \(summary.year)",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Upload payslips to generate a tax year summary")
                    )
                    .frame(height: 120)
                } else {
                    yearSummaryContent(summary: summary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func yearSummaryContent(summary: TaxYearSummary) -> some View {
        VStack(spacing: 16) {
            // Summary cards with YoY comparison
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                yearStatCard(
                    title: "Gross Income",
                    value: CurrencyFormatter.shared.format(summary.grossIncome),
                    change: summary.previousYear?.grossChange,
                    positiveIsGood: true
                )
                yearStatCard(
                    title: "Total Tax",
                    value: CurrencyFormatter.shared.format(summary.incomeTax + summary.socialInsurance + summary.universalCharge),
                    change: nil,
                    positiveIsGood: false
                )
                yearStatCard(
                    title: "Net Income",
                    value: CurrencyFormatter.shared.format(summary.netIncome),
                    change: summary.previousYear?.netChange,
                    positiveIsGood: true
                )
                yearStatCard(
                    title: "Effective Rate",
                    value: String(format: "%.1f%%", summary.effectiveRate),
                    change: summary.previousYear.map { $0.rateChange },
                    positiveIsGood: false
                )
            }

            // Deduction breakdown table
            VStack(alignment: .leading, spacing: 8) {
                Text("Deduction Breakdown")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                deductionRow(label: locale.taxLabels.incomeTax, amount: summary.incomeTax, color: .budgetDanger)
                deductionRow(label: locale.taxLabels.socialInsurance, amount: summary.socialInsurance, color: .budgetWarning)
                if let ucLabel = locale.taxLabels.universalCharge {
                    deductionRow(label: ucLabel, amount: summary.universalCharge, color: .orange)
                }
                deductionRow(label: "Pension (Employee)", amount: summary.pensionEmployee, color: .primaryBlue)
                deductionRow(label: "Pension (Employer)", amount: summary.pensionEmployer, color: .primaryBlue.opacity(0.6))
                if summary.otherDeductions > 0 {
                    deductionRow(label: "Other Deductions", amount: summary.otherDeductions, color: .secondary)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.04))
            .cornerRadius(8)

            // Monthly income chart
            if !summary.monthlyData.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Income (\(String(summary.year)))")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Chart(summary.monthlyData) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Gross", Double(truncating: item.gross as NSNumber))
                        )
                        .foregroundStyle(Color.budgetHealthy.opacity(0.7))

                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Net", Double(truncating: item.net as NSNumber))
                        )
                        .foregroundStyle(Color.primaryBlue)
                    }
                    .chartForegroundStyleScale([
                        "Gross": Color.budgetHealthy.opacity(0.7),
                        "Net": Color.primaryBlue
                    ])
                    .frame(height: 200)
                }
            }

            // Payslip count note
            Text("\(summary.payslipCount) payslip\(summary.payslipCount == 1 ? "" : "s") for \(summary.year)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func yearStatCard(title: String, value: String, change: Double?, positiveIsGood: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            if let change = change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.1f%%", change))
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(yoyColor(change: change, positiveIsGood: positiveIsGood))
            } else {
                Text(" ")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    private func deductionRow(label: String, amount: Decimal, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text(CurrencyFormatter.shared.format(amount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }

    private func yoyColor(change: Double, positiveIsGood: Bool) -> Color {
        if abs(change) < 1.0 { return .secondary }
        let isPositive = change >= 0
        let isGood = positiveIsGood ? isPositive : !isPositive
        return isGood ? .budgetHealthy : .budgetDanger
    }

    private func exportYearSummaryPDF() {
        guard let summary = viewModel.yearSummary, summary.payslipCount > 0 else { return }

        // Build a virtual "transaction-like" representation for the PDF
        // Instead, generate a custom summary text and use the PDF engine
        let title = "Tax Year Summary — \(summary.year)"
        let dateRange = "January 1 – December 31, \(summary.year)"

        // Create pseudo-transactions from monthly data for the PDF table
        var summaryTransactions: [Transaction] = []
        for monthData in summary.monthlyData {
            let t = Transaction(
                amount: monthData.gross,
                date: Calendar.current.date(from: DateComponents(year: summary.year, month: monthData.monthIndex, day: 15)) ?? Date(),
                descriptionText: "\(monthData.month) — Gross Pay",
                type: .income
            )
            summaryTransactions.append(t)
        }

        let data = ExportService.shared.generateTransactionPDF(
            transactions: summaryTransactions,
            title: title,
            dateRange: dateRange
        )

        Task {
            _ = await ExportService.shared.saveWithPanel(
                data: data,
                suggestedName: "TaxYearSummary_\(summary.year).pdf",
                fileType: .pdf
            )
        }
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.primaryBlue)
                Text("Ask About Your Tax")
                    .font(.headline)
            }

            if !viewModel.hasApiKey {
                HStack(spacing: 8) {
                    Image(systemName: "key.fill")
                        .foregroundColor(.secondary)
                    Text("Add a Claude API key in Settings to enable tax Q&A.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
            } else {
                // Chat messages
                if !viewModel.chatMessages.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(viewModel.chatMessages) { message in
                            chatBubble(message: message)
                        }
                    }
                }

                // Input
                HStack(spacing: 8) {
                    TextField("e.g. How can I reduce my tax bill?", text: $viewModel.chatQuestion)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            viewModel.sendChatQuestion(modelContext: modelContext, locale: locale)
                        }

                    Button {
                        viewModel.sendChatQuestion(modelContext: modelContext, locale: locale)
                    } label: {
                        if viewModel.isChatLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .disabled(viewModel.chatQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isChatLoading)
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func chatBubble(message: TaxInsightsViewModel.ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer() }

            Text(message.text)
                .font(.subheadline)
                .padding(10)
                .background(message.role == .user ? Color.primaryBlue.opacity(0.15) : Color.secondary.opacity(0.08))
                .cornerRadius(12)
                .frame(maxWidth: 500, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .assistant { Spacer() }
        }
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        ContentUnavailableView(
            "Analysis Failed",
            systemImage: "exclamationmark.triangle",
            description: Text(message)
        )
        .frame(minHeight: 200)
        .padding(.horizontal)
    }
}

#Preview {
    TaxInsightsView()
}
