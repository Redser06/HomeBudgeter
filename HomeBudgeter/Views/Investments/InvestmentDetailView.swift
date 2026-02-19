import SwiftUI
import SwiftData
import Charts

struct InvestmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let investment: Investment
    let viewModel: InvestmentViewModel

    @State private var showingAddTransaction = false
    @State private var showingUpdatePrice = false
    @State private var newPrice: String = ""
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(investment.symbol)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(investment.assetType.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                    }
                    Text(investment.name)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button("Add Transaction") {
                    showingAddTransaction = true
                }
                .buttonStyle(.borderedProminent)

                Button("Update Price") {
                    newPrice = ""
                    showingUpdatePrice = true
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }

                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            ScrollView {
                VStack(spacing: 20) {
                    // Summary Cards
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        summaryItem("Shares", value: "\(investment.totalQuantity)")
                        summaryItem("Avg Cost", value: investment.averageCostBasis.formatted(as: investment.currencyCode))
                        summaryItem("Current Value", value: investment.currentValue.formatted(as: investment.currencyCode))
                        summaryItem("Gain/Loss", value: String(format: "%+.1f%%", investment.gainLossPercentage),
                                    color: investment.totalGainLoss >= 0 ? .budgetHealthy : .budgetDanger)
                    }
                    .padding(.horizontal)

                    // Price Chart
                    if investment.priceHistory.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Price History")
                                .font(.headline)

                            let sortedPrices = investment.priceHistory.sorted { $0.date < $1.date }
                            Chart(sortedPrices, id: \.date) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Price", Double(truncating: entry.price as NSNumber))
                                )
                                .interpolationMethod(.catmullRom)
                                AreaMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Price", Double(truncating: entry.price as NSNumber))
                                )
                                .foregroundStyle(.blue.opacity(0.1))
                            }
                            .frame(height: 200)
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        .padding(.horizontal)
                    }

                    // Transaction History
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transaction History")
                            .font(.headline)

                        if investment.sortedTransactions.isEmpty {
                            Text("No transactions recorded")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                        } else {
                            ForEach(investment.sortedTransactions, id: \.id) { tx in
                                HStack {
                                    Image(systemName: tx.transactionType == .buy ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundColor(tx.transactionType == .buy ? .budgetHealthy : .budgetDanger)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tx.transactionType.rawValue)
                                            .fontWeight(.medium)
                                        Text(tx.date.formatted(as: .medium))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(tx.quantity) @ \(tx.pricePerUnit.formatted(as: investment.currencyCode))")
                                            .font(.callout)
                                        Text("Total: \(tx.totalAmount.formatted(as: investment.currencyCode))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)

                                if tx.id != investment.sortedTransactions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showingAddTransaction) {
            AddInvestmentTransactionSheet(investment: investment, viewModel: viewModel)
        }
        .alert("Update Price", isPresented: $showingUpdatePrice) {
            TextField("Price", text: $newPrice)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let price = Decimal(string: newPrice) {
                    viewModel.updatePrice(for: investment, price: price, modelContext: modelContext)
                }
            }
        } message: {
            Text("Enter the current price for \(investment.symbol)")
        }
        .alert("Delete Investment?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deleteInvestment(investment, modelContext: modelContext)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \(investment.symbol) and all its transactions.")
        }
    }

    private func summaryItem(_ title: String, value: String, color: Color = .primary) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))
    }
}
