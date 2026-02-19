import SwiftUI
import SwiftData

struct AddInvestmentTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let investment: Investment
    let viewModel: InvestmentViewModel

    @State private var transactionType: InvestmentTransactionType = .buy
    @State private var quantityText: String = ""
    @State private var priceText: String = ""
    @State private var feesText: String = "0"
    @State private var date: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Transaction — \(investment.symbol)")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Form {
                Section("Transaction") {
                    Picker("Type", selection: $transactionType) {
                        ForEach(InvestmentTransactionType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Quantity", text: $quantityText)
                    TextField("Price per Unit", text: $priceText)
                    TextField("Fees", text: $feesText)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes)
                }

                if let quantity = Decimal(string: quantityText),
                   let price = Decimal(string: priceText),
                   let fees = Decimal(string: feesText) {
                    Section("Summary") {
                        LabeledContent("Subtotal") {
                            Text((quantity * price).formatted(as: investment.currencyCode))
                        }
                        LabeledContent("Fees") {
                            Text(fees.formatted(as: investment.currencyCode))
                        }
                        LabeledContent("Total") {
                            Text(((quantity * price) + fees).formatted(as: investment.currencyCode))
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button(transactionType == .buy ? "Record Buy" : "Record Sell") {
                    guard let quantity = Decimal(string: quantityText),
                          let price = Decimal(string: priceText),
                          let fees = Decimal(string: feesText) else { return }

                    viewModel.addTransaction(
                        to: investment,
                        type: transactionType,
                        quantity: quantity,
                        pricePerUnit: price,
                        fees: fees,
                        date: date,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(Decimal(string: quantityText) == nil || Decimal(string: priceText) == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 480)
    }
}
