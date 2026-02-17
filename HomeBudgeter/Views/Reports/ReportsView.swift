//
//  ReportsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ReportsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Date range pickers for custom period
                if viewModel.selectedPeriod == .custom {
                    customDateRangeSection
                }

                // Section 1: Income vs Expenses
                incomeVsExpenseSection

                // Section 2: Spending by Category
                categoryBreakdownSection

                // Section 3: Budget Utilisation
                budgetUtilisationSection

                // Section 4: Net Worth Over Time
                netWorthSection

                // Section 5: Month-over-Month Comparison
                momComparisonSection

                // Section 6: Unusual Spending
                anomalySection

                // Section 7: Top Expenses
                topExpensesSection
            }
            .padding(.vertical)
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.updateDateRange()
            viewModel.loadAllReports(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.updateDateRange()
            viewModel.loadAllReports(modelContext: modelContext)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reports")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Analyse your financial data")
                    .foregroundColor(.secondary)
            }
            Spacer()

            Menu {
                Button {
                    exportReportPDF()
                } label: {
                    Label("Export PDF", systemImage: "doc.richtext")
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 80)

            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(ReportPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 350)
        }
        .padding(.horizontal)
    }

    // MARK: - Custom Date Range

    private var customDateRangeSection: some View {
        HStack(spacing: 16) {
            DatePicker("From", selection: $viewModel.startDate, displayedComponents: .date)
            DatePicker("To", selection: $viewModel.endDate, displayedComponents: .date)
            Button("Apply") {
                viewModel.loadAllReports(modelContext: modelContext)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Section 1: Income vs Expenses

    private var incomeVsExpenseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Income vs Expenses")
                .font(.headline)

            if viewModel.incomeVsExpenseData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Add transactions to see income vs expense comparison")
                )
                .frame(height: 200)
            } else {
                Chart {
                    ForEach(viewModel.incomeVsExpenseData) { item in
                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.income)
                        )
                        .foregroundStyle(Color.budgetHealthy)
                        .position(by: .value("Type", "Income"))

                        BarMark(
                            x: .value("Month", item.month),
                            y: .value("Amount", item.expenses)
                        )
                        .foregroundStyle(Color.budgetDanger)
                        .position(by: .value("Type", "Expenses"))
                    }
                }
                .chartForegroundStyleScale([
                    "Income": Color.budgetHealthy,
                    "Expenses": Color.budgetDanger
                ])
                .chartLegend(position: .top)
                .frame(height: 250)

                // Summary cards
                incomeExpenseSummary
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var incomeExpenseSummary: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            summaryStatView(
                title: "Total Income",
                value: CurrencyFormatter.shared.format(viewModel.totalIncome),
                color: .budgetHealthy
            )
            summaryStatView(
                title: "Total Expenses",
                value: CurrencyFormatter.shared.format(viewModel.totalExpenses),
                color: .budgetDanger
            )
            summaryStatView(
                title: "Net",
                value: CurrencyFormatter.shared.format(viewModel.netAmount),
                color: viewModel.netAmount >= 0 ? .budgetHealthy : .budgetDanger
            )
            summaryStatView(
                title: "Savings Rate",
                value: String(format: "%.1f%%", viewModel.savingsRate),
                color: viewModel.savingsRate >= 0 ? .primaryBlue : .budgetDanger
            )
        }
    }

    private func summaryStatView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }

    // MARK: - Section 2: Spending by Category

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending by Category")
                .font(.headline)

            if viewModel.categoryBreakdown.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.pie",
                    description: Text("Add expense transactions to see category breakdown")
                )
                .frame(height: 200)
            } else {
                HStack(spacing: 24) {
                    // Pie chart
                    Chart(viewModel.categoryBreakdown) { item in
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(item.color)
                        .cornerRadius(4)
                    }
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.categoryBreakdown) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 10, height: 10)

                                Text(item.category)
                                    .font(.caption)
                                    .lineLimit(1)

                                Spacer()

                                Text(CurrencyFormatter.shared.format(item.amount))
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Text(String(format: "%.0f%%", item.percentage))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(width: 35, alignment: .trailing)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Section 3: Budget Utilisation

    private var budgetUtilisationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget Utilisation")
                .font(.headline)

            if viewModel.budgetUtilisation.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "gauge.with.dots.needle.33percent",
                    description: Text("Set up budget categories to track utilisation")
                )
                .frame(height: 150)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.budgetUtilisation) { item in
                        budgetUtilisationRow(item: item)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func budgetUtilisationRow(item: BudgetUtilisationData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.category)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(CurrencyFormatter.shared.format(item.spent))
                    .font(.subheadline)
                +
                Text(" / ")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                +
                Text(CurrencyFormatter.shared.format(item.budgeted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", item.percentage))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(utilisationColor(for: item.percentage))
                    .frame(width: 45, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(utilisationColor(for: item.percentage))
                        .frame(width: min(geometry.size.width * CGFloat(min(item.percentage, 100) / 100), geometry.size.width), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func utilisationColor(for percentage: Double) -> Color {
        if percentage > 90 { return .budgetDanger }
        if percentage > 75 { return .budgetWarning }
        return .budgetHealthy
    }

    // MARK: - Section 4: Net Worth Over Time

    private var netWorthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Worth Over Time")
                .font(.headline)

            if viewModel.netWorthHistory.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Add accounts to track net worth over time")
                )
                .frame(height: 200)
            } else {
                Chart(viewModel.netWorthHistory) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.amount)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.primaryBlue.opacity(0.3), Color.primaryBlue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.amount)
                    )
                    .foregroundStyle(Color.primaryBlue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Net Worth", point.amount)
                    )
                    .foregroundStyle(Color.primaryBlue)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.shared.formatCompact(doubleValue))
                            }
                        }
                    }
                }
                .frame(height: 250)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Section 5: Top Expenses

    private var topExpensesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Expenses")
                .font(.headline)

            if viewModel.topExpenses.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "list.number",
                    description: Text("Add expense transactions to see your largest expenses")
                )
                .frame(height: 150)
            } else {
                VStack(spacing: 0) {
                    // Table header
                    HStack {
                        Text("#")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text("Description")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Category")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)

                        Text("Date")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Text("Amount")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                    Divider()

                    ForEach(Array(viewModel.topExpenses.enumerated()), id: \.element.id) { index, expense in
                        HStack {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .leading)

                            Text(expense.description)
                                .font(.subheadline)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(expense.category ?? "General")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)

                            Text(expense.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .trailing)

                            Text(CurrencyFormatter.shared.format(expense.amount))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.budgetDanger)
                                .frame(width: 100, alignment: .trailing)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)

                        if index < viewModel.topExpenses.count - 1 {
                            Divider()
                                .padding(.horizontal, 8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Section 5: Month-over-Month Comparison

    private var momComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Month-over-Month Changes")
                .font(.headline)

            if let current = viewModel.incomeVsExpenseData.last,
               current.previousIncome != nil {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    momCard(
                        title: "Income",
                        currentValue: current.income,
                        changePercent: current.incomeChange,
                        positiveIsGood: true
                    )
                    momCard(
                        title: "Expenses",
                        currentValue: current.expenses,
                        changePercent: current.expensesChange,
                        positiveIsGood: false
                    )
                    momCard(
                        title: "Net",
                        currentValue: current.net,
                        changePercent: current.netChange,
                        positiveIsGood: true
                    )
                }
            } else {
                ContentUnavailableView(
                    "Not Enough Data",
                    systemImage: "chart.line.flattrend.xyaxis",
                    description: Text("Need at least two months of data for comparison")
                )
                .frame(height: 120)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func momCard(title: String, currentValue: Double, changePercent: Double?, positiveIsGood: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(CurrencyFormatter.shared.format(currentValue))
                .font(.title3)
                .fontWeight(.semibold)

            if let change = changePercent {
                HStack(spacing: 4) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)

                    Text(String(format: "%+.1f%%", change))
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(momChangeColor(change: change, positiveIsGood: positiveIsGood))
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background {
            if let change = changePercent {
                momChangeColor(change: change, positiveIsGood: positiveIsGood).opacity(0.08)
            } else {
                Color.secondary.opacity(0.05)
            }
        }
        .cornerRadius(8)
    }

    private func momChangeColor(change: Double, positiveIsGood: Bool) -> Color {
        if abs(change) < 1.0 { return .secondary }
        let isPositiveChange = change >= 0
        let isGood = positiveIsGood ? isPositiveChange : !isPositiveChange
        return isGood ? .budgetHealthy : .budgetDanger
    }

    // MARK: - Section 6: Unusual Spending (Anomaly Detection)

    private var anomalySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.budgetWarning)
                Text("Unusual Spending")
                    .font(.headline)
                Spacer()
                if !viewModel.anomalies.isEmpty {
                    Text("\(viewModel.anomalies.count) flagged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.budgetWarning.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if viewModel.anomalies.isEmpty {
                ContentUnavailableView(
                    "No Anomalies Detected",
                    systemImage: "checkmark.shield",
                    description: Text("Your spending looks normal for this period")
                )
                .frame(height: 120)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.anomalies.prefix(5)) { anomaly in
                        anomalyRow(anomaly: anomaly)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Export

    private func exportReportPDF() {
        let rangeStart = viewModel.startDate
        let rangeEnd = viewModel.endDate
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> {
                $0.date >= rangeStart && $0.date <= rangeEnd
            },
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        guard let transactions = try? modelContext.fetch(descriptor), !transactions.isEmpty else { return }

        let periodLabel = viewModel.selectedPeriod.rawValue
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let rangeStr = "\(dateFormatter.string(from: viewModel.startDate)) – \(dateFormatter.string(from: viewModel.endDate))"

        let data = ExportService.shared.generateTransactionPDF(
            transactions: transactions,
            title: "Financial Report — \(periodLabel)",
            dateRange: rangeStr
        )
        let dateSuffix = DateFormatter.exportFileDateFormatter.string(from: Date())
        Task {
            _ = await ExportService.shared.saveWithPanel(
                data: data,
                suggestedName: "Report_\(periodLabel)_\(dateSuffix).pdf",
                fileType: .pdf
            )
        }
    }

    private func anomalyRow(anomaly: SpendingAnomaly) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.budgetWarning)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(anomaly.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(anomaly.category)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(anomaly.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.shared.format(anomaly.amount))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.budgetDanger)

                Text(String(format: "+%.0f%% vs avg", anomaly.overagePercentage))
                    .font(.caption2)
                    .foregroundColor(.budgetWarning)
            }
        }
        .padding(10)
        .background(Color.budgetWarning.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.budgetWarning.opacity(0.15), lineWidth: 1)
        )
    }
}

#Preview {
    ReportsView()
}
