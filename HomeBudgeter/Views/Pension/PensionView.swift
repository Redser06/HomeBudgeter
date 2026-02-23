//
//  PensionView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import Charts

struct PensionView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PensionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pension")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Track your retirement savings and contributions")
                        .foregroundColor(.secondary)
                }
                Spacer()

                if viewModel.pensionData != nil {
                    Button {
                        viewModel.showingFileImporter = true
                    } label: {
                        Label("Upload Statement", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.showingEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        viewModel.showingSetupSheet = true
                    } label: {
                        Label("Set Up Pension", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            if viewModel.pensionData != nil {
                PensionDashboardContent(viewModel: viewModel)
            } else {
                PensionEmptyState(viewModel: viewModel)
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadPensionData(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingSetupSheet) {
            PensionSetupSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingEditSheet) {
            PensionEditSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingStatementReview) {
            PensionStatementReviewSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importStatementFile(from: url, modelContext: modelContext)
                    }
                }
            case .failure(let error):
                viewModel.importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: .init(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        )) {
            Button("OK") { viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "")
        }
    }
}

// MARK: - Empty State

struct PensionEmptyState: View {
    var viewModel: PensionViewModel

    var body: some View {
        VStack {
            Spacer()
            ContentUnavailableView(
                "No Pension Data",
                systemImage: "building.columns",
                description: Text("Set up your pension to start tracking your retirement savings, contributions, and investment returns.")
            )

            Button {
                viewModel.showingSetupSheet = true
            } label: {
                Label("Set Up Pension", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Dashboard Content

struct PensionDashboardContent: View {
    @Bindable var viewModel: PensionViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Overview Cards
                PensionOverviewCards(viewModel: viewModel)

                // Progress to Goal
                PensionProgressSection(viewModel: viewModel)

                // Contribution Breakdown + History side-by-side
                HStack(alignment: .top, spacing: 16) {
                    PensionContributionBreakdown(viewModel: viewModel)
                    PensionContributionChart(viewModel: viewModel)
                }

                // Projection Section
                PensionProjectionSection(viewModel: viewModel)

                // Details Section
                PensionDetailsSection(viewModel: viewModel)
            }
            .padding()
        }
    }
}

// MARK: - Overview Cards

struct PensionOverviewCards: View {
    var viewModel: PensionViewModel

    var body: some View {
        HStack(spacing: 16) {
            PensionStatCard(
                title: "Current Value",
                amount: Double(truncating: viewModel.currentValue as NSNumber),
                subtitle: "Pension pot",
                color: .primaryBlue,
                isLarge: true
            )
            PensionStatCard(
                title: "Total Contributions",
                amount: Double(truncating: viewModel.totalContributions as NSNumber),
                subtitle: "Employee + Employer",
                color: .budgetHealthy
            )
            PensionStatCard(
                title: "Investment Returns",
                amount: Double(truncating: viewModel.investmentReturns as NSNumber),
                subtitle: "Growth earned",
                color: .orange
            )
            PensionPercentageCard(
                title: "Return %",
                percentage: viewModel.returnPercentage,
                subtitle: "On contributions",
                color: viewModel.returnPercentage >= 0 ? .budgetHealthy : .budgetDanger
            )
        }
    }
}

struct PensionStatCard: View {
    let title: String
    let amount: Double
    let subtitle: String
    let color: Color
    var isLarge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(CurrencyFormatter.shared.format(amount))
                .font(.system(isLarge ? .title : .title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PensionPercentageCard: View {
    let title: String
    let percentage: Double
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(String(format: "%.1f%%", percentage))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Progress to Goal

struct PensionProgressSection: View {
    var viewModel: PensionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress to Retirement Goal")
                .font(.headline)

            if let progress = viewModel.progressToGoal,
               let goal = viewModel.pensionData?.retirementGoal {
                VStack(spacing: 12) {
                    HStack {
                        Text(CurrencyFormatter.shared.format(Double(truncating: viewModel.currentValue as NSNumber)))
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text(String(format: "%.1f%%", min(progress, 100)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(progressColor(for: progress))

                        Spacer()

                        Text(CurrencyFormatter.shared.format(Double(truncating: goal as NSNumber)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 16)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [.primaryBlue, progressColor(for: progress)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: min(geometry.size.width * CGFloat(min(progress, 100) / 100), geometry.size.width),
                                    height: 16
                                )
                                .animation(.easeInOut(duration: 0.8), value: progress)
                        }
                    }
                    .frame(height: 16)

                    let remaining = goal - viewModel.currentValue
                    if remaining > 0 {
                        Text("\(CurrencyFormatter.shared.format(Double(truncating: remaining as NSNumber))) remaining to reach your goal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Congratulations! You have reached your retirement goal.")
                            .font(.caption)
                            .foregroundColor(.budgetHealthy)
                            .fontWeight(.medium)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "flag")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No retirement goal set")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Edit your pension details to set a retirement goal and track your progress.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func progressColor(for progress: Double) -> Color {
        if progress >= 90 {
            return .budgetHealthy
        } else if progress >= 50 {
            return .budgetWarning
        }
        return .primaryBlue
    }
}

// MARK: - Contribution Breakdown

struct PensionContributionBreakdown: View {
    var viewModel: PensionViewModel

    private var employeeDouble: Double {
        Double(truncating: viewModel.employeeContributions as NSNumber)
    }

    private var employerDouble: Double {
        Double(truncating: viewModel.employerContributions as NSNumber)
    }

    private var totalDouble: Double {
        employeeDouble + employerDouble
    }

    private var employeePercentage: Double {
        guard totalDouble > 0 else { return 0 }
        return (employeeDouble / totalDouble) * 100
    }

    private var employerPercentage: Double {
        guard totalDouble > 0 else { return 0 }
        return (employerDouble / totalDouble) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribution Breakdown")
                .font(.headline)

            if totalDouble > 0 {
                // Horizontal stacked bar
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primaryBlue)
                            .frame(width: geometry.size.width * CGFloat(employeePercentage / 100))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.budgetHealthy)
                            .frame(width: geometry.size.width * CGFloat(employerPercentage / 100))
                    }
                }
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Legend
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color.primaryBlue)
                            .frame(width: 10, height: 10)
                        Text("Employee")
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.shared.format(employeeDouble))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(format: "(%.0f%%)", employeePercentage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Circle()
                            .fill(Color.budgetHealthy)
                            .frame(width: 10, height: 10)
                        Text("Employer")
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.shared.format(employerDouble))
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(String(format: "(%.0f%%)", employerPercentage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(CurrencyFormatter.shared.format(totalDouble))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            } else {
                Text("No contributions recorded yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Contribution History Chart

struct PensionContributionChart: View {
    var viewModel: PensionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contribution History")
                .font(.headline)

            if viewModel.contributionHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("No contribution history available.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Contributions from payslips will appear here.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            } else {
                Chart {
                    ForEach(viewModel.contributionHistory) { data in
                        BarMark(
                            x: .value("Month", data.date, unit: .month),
                            y: .value("Amount", data.employeeAmount)
                        )
                        .foregroundStyle(Color.primaryBlue)
                        .position(by: .value("Type", "Employee"))

                        BarMark(
                            x: .value("Month", data.date, unit: .month),
                            y: .value("Amount", data.employerAmount)
                        )
                        .foregroundStyle(Color.budgetHealthy)
                        .position(by: .value("Type", "Employer"))
                    }
                }
                .chartForegroundStyleScale([
                    "Employee": Color.primaryBlue,
                    "Employer": Color.budgetHealthy
                ])
                .chartLegend(position: .bottom)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(CurrencyFormatter.shared.formatCompact(doubleValue))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Projection Section

struct PensionProjectionSection: View {
    @Bindable var viewModel: PensionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Retirement Projection Calculator")
                .font(.headline)

            PensionProjectionInputs(viewModel: viewModel)

            if !viewModel.projectionScenarios.isEmpty {
                PensionProjectionChart(viewModel: viewModel)
                PensionProjectionSummary(viewModel: viewModel)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Projection Inputs

struct PensionProjectionInputs: View {
    @Bindable var viewModel: PensionViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                HStack {
                    Text("Current Age")
                        .font(.subheadline)
                    Stepper("\(viewModel.projectionCurrentAge)", value: $viewModel.projectionCurrentAge, in: 18...80)
                        .frame(width: 140)
                }

                HStack {
                    Text("Retirement Age")
                        .font(.subheadline)
                    Stepper("\(viewModel.projectionRetirementAge)", value: $viewModel.projectionRetirementAge, in: 50...80)
                        .frame(width: 140)
                }

                HStack {
                    Text("Extra Monthly")
                        .font(.subheadline)
                    TextField("Amount", value: $viewModel.projectionAdditionalContribution, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                }
            }

            HStack(spacing: 16) {
                Text("Scenarios:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(PensionGrowthBand.allCases) { band in
                    Toggle(isOn: Binding(
                        get: { viewModel.selectedScenarioBands.contains(band) },
                        set: { isOn in
                            if isOn {
                                viewModel.selectedScenarioBands.insert(band)
                            } else {
                                viewModel.selectedScenarioBands.remove(band)
                            }
                        }
                    )) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(band.color)
                                .frame(width: 8, height: 8)
                            Text(band.displayDescription)
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                }

                if viewModel.selectedScenarioBands.contains(.custom) {
                    HStack(spacing: 4) {
                        TextField("Rate", value: $viewModel.projectionCustomGrowthRate, format: .number.precision(.fractionLength(1)))
                            .frame(width: 50)
                            .multilineTextAlignment(.trailing)
                        Text("%")
                            .font(.caption)
                    }
                }

                Spacer()

                Button("Calculate") {
                    viewModel.calculateProjections()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Projection Chart

struct PensionProjectionChart: View {
    var viewModel: PensionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(viewModel.projectionScenarios) { scenario in
                    ForEach(scenario.yearProjections) { projection in
                        LineMark(
                            x: .value("Age", projection.age),
                            y: .value("Value", projection.endValue)
                        )
                        .foregroundStyle(by: .value("Scenario", scenario.band.displayDescription))
                    }
                }

                if let goal = viewModel.pensionData?.retirementGoal {
                    RuleMark(y: .value("Goal", Double(truncating: goal as NSNumber)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.gray)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                }
            }
            .chartForegroundStyleScale(
                domain: viewModel.projectionScenarios.map { $0.band.displayDescription },
                range: viewModel.projectionScenarios.map { $0.band.color }
            )
            .chartLegend(position: .bottom)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text(CurrencyFormatter.shared.formatCompact(doubleValue))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let age = value.as(Int.self) {
                            Text("\(age)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 250)
        }
    }
}

// MARK: - Projection Summary

struct PensionProjectionSummary: View {
    var viewModel: PensionViewModel

    var body: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.projectionScenarios) { scenario in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(scenario.band.color)
                            .frame(width: 10, height: 10)
                        Text(scenario.band.displayDescription)
                            .font(.caption)
                            .fontWeight(.medium)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Final Value")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(CurrencyFormatter.shared.format(scenario.finalValue))
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(scenario.band.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Contributions")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(scenario.totalContributions))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Growth")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(scenario.totalGrowth))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }

                    if let goal = viewModel.pensionData?.retirementGoal {
                        let goalDouble = Double(truncating: goal as NSNumber)
                        let diff = scenario.finalValue - goalDouble
                        Divider()
                        HStack {
                            Text(diff >= 0 ? "Surplus" : "Shortfall")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(abs(diff)))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(diff >= 0 ? .budgetHealthy : .budgetDanger)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(scenario.band.color.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Details Section

struct PensionDetailsSection: View {
    var viewModel: PensionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pension Details")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PensionDetailItem(
                    label: "Provider",
                    value: viewModel.pensionData?.provider ?? "Not specified"
                )
                PensionDetailItem(
                    label: "Target Retirement Age",
                    value: viewModel.pensionData?.targetRetirementAge.map { "\($0)" } ?? "Not set"
                )
                PensionDetailItem(
                    label: "Last Updated",
                    value: viewModel.pensionData?.lastUpdated.formatted(date: .abbreviated, time: .shortened) ?? "-"
                )
            }

            if let notes = viewModel.pensionData?.notes, !notes.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(notes)
                        .font(.subheadline)
                }
            }

            if let documents = viewModel.pensionData?.sourceDocuments, !documents.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Linked Documents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(documents, id: \.id) { document in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.primaryBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.filename)
                                    .font(.subheadline)
                                Text(document.formattedUploadDate)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(document.formattedFileSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct PensionDetailItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Setup Sheet

struct PensionSetupSheet: View {
    var viewModel: PensionViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentValue: Double = 0
    @State private var provider: String = ""
    @State private var hasRetirementGoal: Bool = false
    @State private var retirementGoal: Double = 0
    @State private var hasTargetAge: Bool = false
    @State private var targetRetirementAge: Int = 65
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Up Pension")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                Section("Pension Value") {
                    HStack {
                        Text("Current Value")
                        Spacer()
                        TextField("Amount", value: $currentValue, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }
                }

                Section("Provider") {
                    TextField("Pension Provider (optional)", text: $provider)
                }

                Section("Retirement Goal") {
                    Toggle("Set retirement goal", isOn: $hasRetirementGoal)

                    if hasRetirementGoal {
                        HStack {
                            Text("Goal Amount")
                            Spacer()
                            TextField("Amount", value: $retirementGoal, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                        }
                    }

                    Toggle("Set target retirement age", isOn: $hasTargetAge)

                    if hasTargetAge {
                        Stepper("Retirement Age: \(targetRetirementAge)", value: $targetRetirementAge, in: 50...80)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Create Pension") {
                    viewModel.createPensionData(
                        currentValue: Decimal(currentValue),
                        provider: provider.isEmpty ? nil : provider,
                        retirementGoal: hasRetirementGoal ? Decimal(retirementGoal) : nil,
                        targetRetirementAge: hasTargetAge ? targetRetirementAge : nil,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 480, height: 560)
    }
}

// MARK: - Edit Sheet

struct PensionEditSheet: View {
    var viewModel: PensionViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentValue: Double
    @State private var investmentReturns: Double
    @State private var provider: String
    @State private var hasRetirementGoal: Bool
    @State private var retirementGoal: Double
    @State private var hasTargetAge: Bool
    @State private var targetRetirementAge: Int
    @State private var notes: String

    init(viewModel: PensionViewModel, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.modelContext = modelContext

        let pension = viewModel.pensionData
        _currentValue = State(initialValue: Double(truncating: (pension?.currentValue ?? 0) as NSNumber))
        _investmentReturns = State(initialValue: Double(truncating: (pension?.totalInvestmentReturns ?? 0) as NSNumber))
        _provider = State(initialValue: pension?.provider ?? "")
        _hasRetirementGoal = State(initialValue: pension?.retirementGoal != nil)
        _retirementGoal = State(initialValue: Double(truncating: (pension?.retirementGoal ?? 0) as NSNumber))
        _hasTargetAge = State(initialValue: pension?.targetRetirementAge != nil)
        _targetRetirementAge = State(initialValue: pension?.targetRetirementAge ?? 65)
        _notes = State(initialValue: pension?.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.primaryBlue)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Edit Pension")
                        .font(.title2)
                        .fontWeight(.bold)
                    if let progress = viewModel.progressToGoal {
                        Text(String(format: "%.1f%% of retirement goal", min(progress, 100)))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Update your pension details")
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            Form {
                Section("Pension Value") {
                    HStack {
                        Text("Current Value")
                        Spacer()
                        TextField("Amount", value: $currentValue, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }

                    HStack {
                        Text("Investment Returns")
                        Spacer()
                        TextField("Amount", value: $investmentReturns, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 150)
                    }
                }

                Section("Provider") {
                    TextField("Pension Provider", text: $provider)
                }

                Section("Retirement Goal") {
                    Toggle("Set retirement goal", isOn: $hasRetirementGoal)

                    if hasRetirementGoal {
                        HStack {
                            Text("Goal Amount")
                            Spacer()
                            TextField("Amount", value: $retirementGoal, format: .currency(code: CurrencyFormatter.shared.currencyCode))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 150)
                        }
                    }

                    Toggle("Set target retirement age", isOn: $hasTargetAge)

                    if hasTargetAge {
                        Stepper("Retirement Age: \(targetRetirementAge)", value: $targetRetirementAge, in: 50...80)
                    }
                }

                Section("Contributions") {
                    LabeledContent("Employee Contributions",
                        value: CurrencyFormatter.shared.format(Double(truncating: viewModel.employeeContributions as NSNumber)))
                    LabeledContent("Employer Contributions",
                        value: CurrencyFormatter.shared.format(Double(truncating: viewModel.employerContributions as NSNumber)))
                    LabeledContent("Total Contributions",
                        value: CurrencyFormatter.shared.format(Double(truncating: viewModel.totalContributions as NSNumber)))
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                Button("Save Changes") {
                    viewModel.updatePensionData(
                        currentValue: Decimal(currentValue),
                        investmentReturns: Decimal(investmentReturns),
                        provider: provider.isEmpty ? nil : provider,
                        retirementGoal: hasRetirementGoal ? Decimal(retirementGoal) : nil,
                        targetRetirementAge: hasTargetAge ? targetRetirementAge : nil,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 480, height: 640)
    }
}

// MARK: - Statement Review Sheet

struct PensionStatementReviewSheet: View {
    var viewModel: PensionViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.primaryBlue)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Review Statement Data")
                        .font(.title2)
                        .fontWeight(.bold)
                    if let doc = viewModel.importedDocument {
                        Text(doc.filename)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            if viewModel.isParsing {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Parsing pension statement...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.parsingError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.budgetDanger)
                    Text("Parsing Failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = viewModel.parsedStatementData {
                Form {
                    Section("Extracted Values") {
                        LabeledContent("Current Value",
                            value: data.currentValue.map { CurrencyFormatter.shared.format(Double(truncating: (Decimal(string: $0) ?? 0) as NSNumber)) } ?? "Not found")
                        LabeledContent("Employee Contributions",
                            value: data.totalEmployeeContributions.map { CurrencyFormatter.shared.format(Double(truncating: (Decimal(string: $0) ?? 0) as NSNumber)) } ?? "Not found")
                        LabeledContent("Employer Contributions",
                            value: data.totalEmployerContributions.map { CurrencyFormatter.shared.format(Double(truncating: (Decimal(string: $0) ?? 0) as NSNumber)) } ?? "Not found")
                        LabeledContent("Investment Returns",
                            value: data.totalInvestmentReturns.map { CurrencyFormatter.shared.format(Double(truncating: (Decimal(string: $0) ?? 0) as NSNumber)) } ?? "Not found")
                    }

                    Section("Details") {
                        LabeledContent("Provider", value: data.provider ?? "Not found")
                        LabeledContent("Statement Date", value: data.statementDate ?? "Not found")
                        if let confidence = data.confidence {
                            LabeledContent("Confidence", value: String(format: "%.0f%%", confidence * 100))
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.questionmark")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No parsed data available")
                        .font(.headline)
                    Text("The statement could not be automatically parsed. You can update your pension details manually.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)

                if viewModel.parsedStatementData != nil {
                    Button("Apply to Pension") {
                        viewModel.applyParsedStatement(modelContext: modelContext)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 500, height: 520)
    }
}

#Preview {
    PensionView()
}
