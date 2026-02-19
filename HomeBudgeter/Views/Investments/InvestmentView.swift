import SwiftUI
import SwiftData
import Charts

struct InvestmentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = InvestmentViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Investments")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Portfolio overview")
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    if !viewModel.householdMembers.isEmpty {
                        MemberFilterPicker(
                            selectedMember: $viewModel.selectedMember,
                            members: viewModel.householdMembers
                        )
                    }

                    Button {
                        viewModel.showingAddInvestment = true
                    } label: {
                        Label("Add Investment", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                // Summary Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    StatCard(
                        title: "Portfolio Value",
                        value: viewModel.totalPortfolioValue.formatted(as: "EUR"),
                        icon: "chart.line.uptrend.xyaxis",
                        accentColor: .blue
                    )
                    StatCard(
                        title: "Cost Basis",
                        value: viewModel.totalCostBasis.formatted(as: "EUR"),
                        icon: "banknote",
                        accentColor: .secondary
                    )
                    StatCard(
                        title: "Total Gain/Loss",
                        value: viewModel.totalGainLoss.formatted(as: "EUR"),
                        icon: viewModel.totalGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right",
                        accentColor: viewModel.totalGainLoss >= 0 ? .budgetHealthy : .budgetDanger
                    )
                    StatCard(
                        title: "Return",
                        value: String(format: "%.1f%%", viewModel.totalGainLossPercentage),
                        icon: "percent",
                        accentColor: viewModel.totalGainLossPercentage >= 0 ? .budgetHealthy : .budgetDanger
                    )
                }
                .padding(.horizontal)

                // Allocation Chart + Holdings
                HStack(alignment: .top, spacing: 16) {
                    // Allocation donut chart
                    if !viewModel.allocationData.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Allocation")
                                .font(.headline)

                            Chart(viewModel.allocationData) { entry in
                                SectorMark(
                                    angle: .value("Value", entry.value),
                                    innerRadius: .ratio(0.6),
                                    angularInset: 1.5
                                )
                                .foregroundStyle(by: .value("Symbol", entry.name))
                            }
                            .frame(height: 250)

                            ForEach(viewModel.allocationData) { entry in
                                HStack {
                                    Text(entry.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text(String(format: "%.1f%%", entry.percentage))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        .frame(maxWidth: 320)
                    }

                    // Holdings list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Holdings")
                            .font(.headline)

                        if viewModel.filteredInvestments.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                Text("No investments yet")
                                    .foregroundColor(.secondary)
                                Text("Add your first investment to start tracking your portfolio.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.filteredInvestments, id: \.id) { investment in
                                Button {
                                    viewModel.selectedInvestment = investment
                                } label: {
                                    HoldingRow(investment: investment)
                                }
                                .buttonStyle(.plain)

                                if investment.id != viewModel.filteredInvestments.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            viewModel.loadData(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingAddInvestment) {
            AddInvestmentSheet(viewModel: viewModel)
        }
        .sheet(item: $viewModel.selectedInvestment) { investment in
            InvestmentDetailView(investment: investment, viewModel: viewModel)
        }
    }
}

// MARK: - Holding Row

private struct HoldingRow: View {
    let investment: Investment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: investment.assetType.icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.blue.opacity(0.1)))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(investment.symbol)
                        .fontWeight(.semibold)
                    Text(investment.assetType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                }
                Text(investment.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(investment.currentValue.formatted(as: investment.currencyCode))
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: investment.totalGainLoss >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text(String(format: "%+.1f%%", investment.gainLossPercentage))
                        .font(.caption)
                }
                .foregroundColor(investment.totalGainLoss >= 0 ? .budgetHealthy : .budgetDanger)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
