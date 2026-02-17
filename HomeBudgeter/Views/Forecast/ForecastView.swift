//
//  ForecastView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import Charts

struct ForecastView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ForecastViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                summaryCards
                atRiskSection
                categoryForecastSection
            }
            .padding(.vertical)
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadForecast(modelContext: modelContext)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Budget Forecast")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text("Prediction for \(viewModel.forecastMonthString)")
                        .foregroundColor(.secondary)

                    confidenceBadge
                }
            }
            Spacer()

            Button {
                viewModel.loadForecast(modelContext: modelContext)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var confidenceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 6, height: 6)
            Text(viewModel.confidence.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(confidenceColor.opacity(0.1))
        .cornerRadius(6)
    }

    private var confidenceColor: Color {
        switch viewModel.confidence {
        case .high: return .budgetHealthy
        case .medium: return .budgetWarning
        case .low: return .budgetDanger
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            forecastStatCard(
                title: "Predicted Income",
                value: CurrencyFormatter.shared.format(viewModel.predictedIncome),
                icon: "arrow.down.circle.fill",
                color: .budgetHealthy
            )
            forecastStatCard(
                title: "Predicted Expenses",
                value: CurrencyFormatter.shared.format(viewModel.predictedExpenses),
                icon: "arrow.up.circle.fill",
                color: .budgetDanger
            )
            forecastStatCard(
                title: "Predicted Net",
                value: CurrencyFormatter.shared.format(viewModel.predictedNet),
                icon: "equal.circle.fill",
                color: viewModel.predictedNet >= 0 ? .budgetHealthy : .budgetDanger
            )
            forecastStatCard(
                title: "Savings Rate",
                value: String(format: "%.1f%%", viewModel.predictedSavingsRate),
                icon: "percent",
                color: viewModel.predictedSavingsRate >= 0 ? .primaryBlue : .budgetDanger
            )
        }
        .padding(.horizontal)
    }

    private func forecastStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - At Risk Categories

    private var atRiskSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.budgetWarning)
                Text("At Risk of Overspending")
                    .font(.headline)
                Spacer()
                if !viewModel.atRiskCategories.isEmpty {
                    Text("~\(CurrencyFormatter.shared.format(viewModel.totalPredictedOverspend)) over budget")
                        .font(.caption)
                        .foregroundColor(.budgetDanger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.budgetDanger.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if viewModel.atRiskCategories.isEmpty {
                ContentUnavailableView(
                    "Looking Good",
                    systemImage: "checkmark.shield.fill",
                    description: Text("No categories are predicted to exceed their budget")
                )
                .frame(height: 100)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.atRiskCategories) { forecast in
                        atRiskRow(forecast: forecast)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func atRiskRow(forecast: CategoryForecast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: forecast.categoryType.icon)
                .foregroundColor(forecast.categoryType.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(forecast.categoryType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Avg: \(CurrencyFormatter.shared.format(forecast.averageSpend))/mo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.shared.format(forecast.predictedSpend))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.budgetDanger)

                Text("+\(CurrencyFormatter.shared.format(forecast.overspendAmount)) over")
                    .font(.caption)
                    .foregroundColor(.budgetDanger)
            }
        }
        .padding(10)
        .background(Color.budgetDanger.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.budgetDanger.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Category Forecast Detail

    private var categoryForecastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Forecast")
                .font(.headline)

            if viewModel.categoryForecasts.isEmpty {
                ContentUnavailableView(
                    "No Budget Categories",
                    systemImage: "chart.bar",
                    description: Text("Set up budget categories to see forecasts")
                )
                .frame(height: 150)
            } else {
                // Predicted vs Budget bar chart
                Chart(viewModel.categoryForecasts) { forecast in
                    BarMark(
                        x: .value("Category", forecast.categoryType.rawValue),
                        y: .value("Amount", Double(truncating: forecast.predictedSpend as NSNumber))
                    )
                    .foregroundStyle(forecast.isLikelyOverBudget ? Color.budgetDanger : Color.primaryBlue)
                    .position(by: .value("Type", "Predicted"))

                    BarMark(
                        x: .value("Category", forecast.categoryType.rawValue),
                        y: .value("Amount", Double(truncating: forecast.budgetAmount as NSNumber))
                    )
                    .foregroundStyle(Color.secondary.opacity(0.3))
                    .position(by: .value("Type", "Budget"))
                }
                .chartForegroundStyleScale([
                    "Predicted": Color.primaryBlue,
                    "Budget": Color.secondary.opacity(0.3)
                ])
                .chartLegend(position: .top)
                .frame(height: 250)

                // Detail rows
                VStack(spacing: 8) {
                    ForEach(viewModel.categoryForecasts) { forecast in
                        categoryForecastRow(forecast: forecast)
                    }
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func categoryForecastRow(forecast: CategoryForecast) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: forecast.categoryType.icon)
                    .foregroundColor(forecast.categoryType.color)
                    .frame(width: 20)

                Text(forecast.categoryType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                trendBadge(trend: forecast.trend)

                Spacer()

                Text(CurrencyFormatter.shared.format(forecast.predictedSpend))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(" / ")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(CurrencyFormatter.shared.format(forecast.budgetAmount))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(String(format: "%.0f%%", forecast.predictedUtilisation))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(utilisationColor(for: forecast.predictedUtilisation))
                    .frame(width: 45, alignment: .trailing)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(utilisationColor(for: forecast.predictedUtilisation))
                        .frame(
                            width: min(
                                geometry.size.width * CGFloat(min(forecast.predictedUtilisation, 120) / 100),
                                geometry.size.width
                            ),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    private func trendBadge(trend: SpendTrend) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trendIcon(trend))
                .font(.caption2)
            Text(trend.rawValue)
                .font(.caption2)
        }
        .foregroundColor(trendColor(trend))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(trendColor(trend).opacity(0.1))
        .cornerRadius(4)
    }

    private func trendIcon(_ trend: SpendTrend) -> String {
        switch trend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        case .insufficient: return "questionmark"
        }
    }

    private func trendColor(_ trend: SpendTrend) -> Color {
        switch trend {
        case .increasing: return .budgetDanger
        case .decreasing: return .budgetHealthy
        case .stable: return .secondary
        case .insufficient: return .secondary
        }
    }

    private func utilisationColor(for percentage: Double) -> Color {
        if percentage > 90 { return .budgetDanger }
        if percentage > 75 { return .budgetWarning }
        return .budgetHealthy
    }
}

#Preview {
    ForecastView()
}
