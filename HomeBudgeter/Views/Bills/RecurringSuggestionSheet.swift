//
//  RecurringSuggestionSheet.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData

struct RecurringSuggestionSheet: View {
    let result: RecurringBillDetector.DetectionResult
    var recurringViewModel: RecurringViewModel
    var modelContext: ModelContext
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrequency: RecurringFrequency
    @State private var amount: Double
    @State private var isAutoPay: Bool

    init(
        result: RecurringBillDetector.DetectionResult,
        recurringViewModel: RecurringViewModel,
        modelContext: ModelContext,
        onDismiss: @escaping () -> Void
    ) {
        self.result = result
        self.recurringViewModel = recurringViewModel
        self.modelContext = modelContext
        self.onDismiss = onDismiss
        self._selectedFrequency = State(initialValue: result.suggestedFrequency)
        self._amount = State(initialValue: Double(truncating: result.suggestedAmount as NSNumber))
        self._isAutoPay = State(initialValue: !result.hasBillTags)
    }

    private var currencyCode: String {
        CurrencyFormatter.shared.locale.currencyCode
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.primaryBlue)
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recurring Bill Detected")
                        .font(.headline)
                    Text("We noticed multiple bills from \(result.vendor)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            // Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bills found")
                    Spacer()
                    Text("\(result.matchingTransactions.count)")
                        .foregroundColor(.secondary)
                }

                if result.isVariableAmount {
                    HStack {
                        Text("Average amount")
                        Spacer()
                        Text(CurrencyFormatter.shared.format(Double(truncating: result.averageAmount as NSNumber)))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.budgetWarning)
                        Text("Amounts vary between bills. Generated transactions will be marked as estimates.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if !result.billTypes.isEmpty {
                    HStack {
                        Text("Type")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(result.billTypes) { type in
                                Text(type.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(type.color.opacity(0.15))
                                    .foregroundColor(type.color)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(12)

            // Editable fields
            Form {
                Picker("Frequency", selection: $selectedFrequency) {
                    ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                        Text(freq.rawValue).tag(freq)
                    }
                }

                HStack {
                    Text("Amount")
                    Spacer()
                    TextField("Amount", value: $amount, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }

                Toggle("Auto-pay", isOn: $isAutoPay)
            }
            .formStyle(.grouped)
            .frame(height: 160)

            // Buttons
            HStack {
                Button("Not Now") {
                    onDismiss()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Create Recurring") {
                    let decimalAmount = Decimal(string: String(format: "%.2f", amount)) ?? result.suggestedAmount
                    recurringViewModel.createTemplateFromDetection(
                        result,
                        frequency: selectedFrequency,
                        amount: decimalAmount,
                        isAutoPay: isAutoPay,
                        modelContext: modelContext
                    )
                    onDismiss()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount <= 0)
            }
        }
        .padding()
        .frame(width: 460, height: 520)
    }
}
