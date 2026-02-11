//
//  DashboardView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Overview of your finances")
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Period Selector
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                .padding(.horizontal)

                // Summary Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    SummaryCard(
                        title: "Total Income",
                        value: viewModel.totalIncome,
                        icon: "arrow.down.circle.fill",
                        color: .green
                    )
                    SummaryCard(
                        title: "Total Expenses",
                        value: viewModel.totalExpenses,
                        icon: "arrow.up.circle.fill",
                        color: .red
                    )
                    SummaryCard(
                        title: "Net Savings",
                        value: viewModel.netSavings,
                        icon: "banknote.fill",
                        color: .blue
                    )
                    SummaryCard(
                        title: "Budget Used",
                        value: viewModel.budgetUsedPercentage,
                        icon: "chart.pie.fill",
                        color: .orange,
                        isPercentage: true
                    )
                }
                .padding(.horizontal)

                // Charts Section
                HStack(spacing: 16) {
                    // Spending by Category
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Spending by Category")
                            .font(.headline)

                        if viewModel.categorySpending.isEmpty {
                            ContentUnavailableView(
                                "No Data",
                                systemImage: "chart.pie",
                                description: Text("Add transactions to see spending breakdown")
                            )
                            .frame(height: 200)
                        } else {
                            Chart(viewModel.categorySpending, id: \.id) { item in
                                SectorMark(
                                    angle: .value("Amount", item.amount),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Category", item.category))
                                .cornerRadius(4)
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                    // Monthly Trend
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monthly Trend")
                            .font(.headline)

                        if viewModel.monthlyTrend.isEmpty {
                            ContentUnavailableView(
                                "No Data",
                                systemImage: "chart.line.uptrend.xyaxis",
                                description: Text("Add transactions to see trends")
                            )
                            .frame(height: 200)
                        } else {
                            Chart(viewModel.monthlyTrend, id: \.id) { item in
                                LineMark(
                                    x: .value("Month", item.month),
                                    y: .value("Amount", item.amount)
                                )
                                .foregroundStyle(item.type == "Income" ? .green : .red)

                                PointMark(
                                    x: .value("Month", item.month),
                                    y: .value("Amount", item.amount)
                                )
                                .foregroundStyle(item.type == "Income" ? .green : .red)
                            }
                            .frame(height: 200)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Recent Transactions
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Transactions")
                            .font(.headline)
                        Spacer()
                        Button("View All") {
                            // Navigate to transactions
                        }
                        .buttonStyle(.link)
                    }

                    if viewModel.recentTransactions.isEmpty {
                        ContentUnavailableView(
                            "No Transactions",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Your recent transactions will appear here")
                        )
                        .frame(height: 150)
                    } else {
                        ForEach(viewModel.recentTransactions) { transaction in
                            TransactionRowView(transaction: transaction)
                        }
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadData(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedPeriod) { _, _ in
            viewModel.loadData(modelContext: modelContext)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    var isPercentage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if isPercentage {
                    Text("\(value, specifier: "%.1f")%")
                        .font(.title)
                        .fontWeight(.bold)
                } else {
                    Text(value, format: .currency(code: "EUR"))
                        .font(.title)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct TransactionRowView: View {
    let transaction: Transaction

    private var isExpense: Bool {
        transaction.type == .expense
    }

    private var categoryIcon: String {
        transaction.category?.type.icon ?? "dollarsign.circle.fill"
    }

    private var categoryName: String {
        transaction.category?.type.rawValue ?? "General"
    }

    var body: some View {
        HStack {
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(isExpense ? .red : .green)
                .frame(width: 40, height: 40)
                .background(
                    (isExpense ? Color.red : Color.green)
                        .opacity(0.1)
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.descriptionText)
                    .fontWeight(.medium)
                Text(categoryName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .fontWeight(.medium)
                    .foregroundColor(isExpense ? .red : .green)
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

enum TimePeriod: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"
}

#Preview {
    DashboardView()
}
