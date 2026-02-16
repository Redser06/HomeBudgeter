//
//  BillsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = BillsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bills")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Track your bills and expenses")
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button {
                    viewModel.showingFileImporter = true
                } label: {
                    Label("Upload Bill", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.showingCreateSheet = true
                } label: {
                    Label("Add Bill", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Overview Cards
            HStack(spacing: 16) {
                BillOverviewCard(
                    title: "Total YTD",
                    amount: Double(truncating: viewModel.totalSpentYTD as NSNumber),
                    subtitle: "All bills this year",
                    color: .primaryBlue
                )
                BillOverviewCard(
                    title: "This Month",
                    amount: Double(truncating: viewModel.totalThisMonth as NSNumber),
                    subtitle: "Current month bills",
                    color: .budgetWarning
                )
                BillOverviewCard(
                    title: "Monthly Average",
                    amount: Double(truncating: viewModel.averageMonthlyBill as NSNumber),
                    subtitle: "Average per month",
                    color: .budgetHealthy
                )
                BillOverviewCard(
                    title: "Total Bills",
                    amount: nil,
                    count: viewModel.billCount,
                    subtitle: "Bills recorded",
                    color: .neutralGray
                )
            }
            .padding(.horizontal)

            // Filters
            HStack(spacing: 16) {
                Picker("Year", selection: $viewModel.filterYear) {
                    if viewModel.availableYears.isEmpty {
                        Text(String(viewModel.filterYear)).tag(viewModel.filterYear)
                    } else {
                        ForEach(viewModel.availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }
                .frame(width: 120)

                Picker("Bill Type", selection: Binding(
                    get: { viewModel.filterBillType?.rawValue ?? "" },
                    set: { viewModel.filterBillType = $0.isEmpty ? nil : BillType(rawValue: $0) }
                )) {
                    Text("All Types").tag("")
                    ForEach(BillType.allCases) { billType in
                        Label(billType.rawValue, systemImage: billType.icon)
                            .tag(billType.rawValue)
                    }
                }
                .frame(width: 200)

                Spacer()

                Text("\(viewModel.filteredBills.count) bill\(viewModel.filteredBills.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Bills List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.filteredBills.isEmpty {
                        ContentUnavailableView(
                            "No Bills",
                            systemImage: "doc.plaintext",
                            description: Text("Add your first bill to start tracking expenses")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.billsGroupedByMonth, id: \.month) { group in
                            Section {
                                ForEach(group.bills) { bill in
                                    BillRow(bill: bill) {
                                        viewModel.selectedBill = bill
                                    }
                                }
                            } header: {
                                HStack {
                                    Text(group.month)
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 600)
        .onAppear {
            viewModel.loadBills(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            AddBillSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $viewModel.selectedBill) { bill in
            BillDetailSheet(viewModel: viewModel, bill: bill, modelContext: modelContext)
        }
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importBillFile(from: url, modelContext: modelContext)
                    }
                }
            case .failure(let error):
                viewModel.importError = error.localizedDescription
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        )) {
            Button("OK") { viewModel.importError = nil }
        } message: {
            Text(viewModel.importError ?? "An unknown error occurred")
        }
    }
}

// MARK: - Overview Card

struct BillOverviewCard: View {
    let title: String
    var amount: Double?
    var count: Int?
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let amount = amount {
                Text(CurrencyFormatter.shared.format(amount))
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else if let count = count {
                Text("\(count)")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }

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

// MARK: - Bill Row

struct BillRow: View {
    let bill: Transaction
    let onTap: () -> Void

    private var billType: BillType {
        guard let notes = bill.notes else { return .other }
        for type in BillType.allCases {
            if notes.contains("[\(type.rawValue)]") {
                return type
            }
        }
        return .other
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: billType.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(billType.color)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(bill.descriptionText)
                        .font(.headline)

                    Text(billType.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(billType.color.opacity(0.15))
                        .foregroundColor(billType.color)
                        .cornerRadius(4)

                    Spacer()
                }

                Text(bill.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.shared.format(Double(truncating: bill.amount as NSNumber)))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.budgetDanger)

                if let category = bill.category {
                    Text(category.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

// MARK: - Add Bill Sheet

struct AddBillSheet: View {
    var viewModel: BillsViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var vendor: String = ""
    @State private var billDate = Date()
    @State private var hasDueDate: Bool = false
    @State private var dueDate = Date()
    @State private var amount: Double = 0
    @State private var selectedBillType: BillType = .other
    @State private var selectedCategoryType: CategoryType = .utilities
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: RecurringFrequency = .monthly
    @State private var notes: String = ""

    private var currencyCode: String {
        CurrencyFormatter.shared.locale.currencyCode
    }

    private var attachedDocument: Document? {
        viewModel.importedDocument
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("New Bill")
                .font(.title2)
                .fontWeight(.bold)

            if let doc = attachedDocument {
                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .foregroundColor(.primaryBlue)
                    Text(doc.filename)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.budgetHealthy)
                }
                .padding(10)
                .background(Color.primaryBlue.opacity(0.08))
                .cornerRadius(8)
            }

            // Parsing status banners
            if viewModel.isParsing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Parsing bill with AI...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.primaryBlue.opacity(0.08))
                .cornerRadius(8)
            }

            if let error = viewModel.parsingError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.budgetWarning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI parsing failed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color.budgetWarning.opacity(0.08))
                .cornerRadius(8)
            }

            if viewModel.parsedData != nil && !viewModel.isParsing {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.budgetHealthy)
                    Text("Fields pre-filled from AI. Please review before saving.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let confidence = viewModel.parsedData?.confidence {
                        Text("\(Int(confidence * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                confidence >= 0.8 ? Color.budgetHealthy.opacity(0.15) :
                                confidence >= 0.5 ? Color.budgetWarning.opacity(0.15) :
                                Color.budgetDanger.opacity(0.15)
                            )
                            .cornerRadius(4)
                    }
                }
                .padding(10)
                .background(Color.budgetHealthy.opacity(0.08))
                .cornerRadius(8)
            }

            Form {
                Section("Bill Details") {
                    TextField("Vendor / Provider", text: $vendor)
                    DatePicker("Bill Date", selection: $billDate, displayedComponents: .date)
                    Toggle("Has Due Date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Amount") {
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        TextField("Amount", value: $amount, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section("Classification") {
                    Picker("Bill Type", selection: $selectedBillType) {
                        ForEach(BillType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Budget Category", selection: $selectedCategoryType) {
                        ForEach(CategoryType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section("Recurring") {
                    Toggle("Recurring Bill", isOn: $isRecurring)
                    if isRecurring {
                        Picker("Frequency", selection: $recurringFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                                Text(freq.rawValue).tag(freq)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    viewModel.resetImportState()
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Add Bill") {
                    viewModel.createBillTransaction(
                        amount: Decimal(string: String(format: "%.2f", amount)) ?? 0,
                        date: billDate,
                        vendor: vendor,
                        billType: selectedBillType,
                        categoryType: selectedCategoryType,
                        notes: notes.isEmpty ? nil : notes,
                        dueDate: hasDueDate ? dueDate : nil,
                        isRecurring: isRecurring,
                        recurringFrequency: isRecurring ? recurringFrequency : nil,
                        modelContext: modelContext
                    )
                    viewModel.resetImportState()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(amount <= 0 || vendor.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 700)
        .onAppear {
            if let parsed = viewModel.parsedData {
                if let v = parsed.vendor, !v.isEmpty {
                    vendor = v
                }
                if let date = ParsedBillData.toDate(parsed.billDate) {
                    billDate = date
                }
                if let date = ParsedBillData.toDate(parsed.dueDate) {
                    hasDueDate = true
                    dueDate = date
                }

                let totalAmount = ParsedBillData.toDecimal(parsed.totalAmount)
                if totalAmount > 0 {
                    amount = Double(truncating: totalAmount as NSNumber)
                }

                selectedBillType = parsed.resolvedBillType
                selectedCategoryType = parsed.resolvedCategoryType

                // Build auto-notes from parsed data
                var autoNotes: [String] = []
                if let acct = parsed.accountNumber, !acct.isEmpty {
                    autoNotes.append("Account: \(acct)")
                }
                if let periodStart = parsed.billingPeriodStart, let periodEnd = parsed.billingPeriodEnd {
                    autoNotes.append("Period: \(periodStart) to \(periodEnd)")
                }
                if let tax = parsed.taxAmount, ParsedBillData.toDecimal(tax) > 0 {
                    autoNotes.append("VAT: \(tax)")
                }
                if !autoNotes.isEmpty {
                    notes = autoNotes.joined(separator: " | ")
                }

                isRecurring = true
                recurringFrequency = .monthly
            }
        }
    }
}

// MARK: - Bill Detail Sheet

struct BillDetailSheet: View {
    var viewModel: BillsViewModel
    let bill: Transaction
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingDeleteConfirmation = false

    private var decodedParsedData: ParsedBillData? {
        guard let jsonString = bill.linkedDocument?.extractedData,
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedBillData.self, from: data)
    }

    private var billType: BillType {
        guard let notes = bill.notes else { return .other }
        for type in BillType.allCases {
            if notes.contains("[\(type.rawValue)]") {
                return type
            }
        }
        return .other
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: billType.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(billType.color)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text("Bill Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(bill.descriptionText)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            ScrollView {
                VStack(spacing: 16) {
                    // Bill info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bill Information")
                            .font(.headline)

                        HStack {
                            Text("Vendor")
                            Spacer()
                            Text(bill.descriptionText)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(bill.formattedDate)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Type")
                            Spacer()
                            Label(billType.rawValue, systemImage: billType.icon)
                                .font(.subheadline)
                                .foregroundColor(billType.color)
                        }
                        if let category = bill.category {
                            HStack {
                                Text("Budget Category")
                                Spacer()
                                Label(category.type.rawValue, systemImage: category.type.icon)
                                    .font(.subheadline)
                                    .foregroundColor(category.type.color)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                    // Amount
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.headline)

                        HStack {
                            Text("Total")
                            Spacer()
                            Text(CurrencyFormatter.shared.format(Double(truncating: bill.amount as NSNumber)))
                                .font(.system(.title2, design: .monospaced))
                                .fontWeight(.bold)
                                .foregroundColor(.budgetDanger)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)

                    // Parsed Details
                    if let parsedBillData = decodedParsedData {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Parsed Details")
                                    .font(.headline)
                                Spacer()
                                if let confidence = parsedBillData.confidence {
                                    Text("\(Int(confidence * 100))%")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            confidence >= 0.8 ? Color.budgetHealthy.opacity(0.15) :
                                            confidence >= 0.5 ? Color.budgetWarning.opacity(0.15) :
                                            Color.budgetDanger.opacity(0.15)
                                        )
                                        .foregroundColor(
                                            confidence >= 0.8 ? .budgetHealthy :
                                            confidence >= 0.5 ? .budgetWarning :
                                            .budgetDanger
                                        )
                                        .cornerRadius(4)
                                }
                            }

                            if let dueDate = parsedBillData.dueDate {
                                HStack {
                                    Text("Due Date")
                                    Spacer()
                                    Text(dueDate)
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let periodStart = parsedBillData.billingPeriodStart,
                               let periodEnd = parsedBillData.billingPeriodEnd {
                                HStack {
                                    Text("Billing Period")
                                    Spacer()
                                    Text("\(periodStart) to \(periodEnd)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let tax = parsedBillData.taxAmount, ParsedBillData.toDecimal(tax) > 0 {
                                HStack {
                                    Text("VAT / Tax")
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(Double(truncating: ParsedBillData.toDecimal(tax) as NSNumber)))
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let subtotal = parsedBillData.subtotalAmount, ParsedBillData.toDecimal(subtotal) > 0 {
                                HStack {
                                    Text("Subtotal")
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(Double(truncating: ParsedBillData.toDecimal(subtotal) as NSNumber)))
                                        .foregroundColor(.secondary)
                                }
                            }
                            if let account = parsedBillData.accountNumber, !account.isEmpty {
                                HStack {
                                    Text("Account Number")
                                    Spacer()
                                    Text(account)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    // Recurring info
                    if bill.isRecurring {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recurring")
                                .font(.headline)

                            HStack {
                                Text("Frequency")
                                Spacer()
                                Text(bill.recurringFrequency?.rawValue ?? "Monthly")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    // Document
                    if let doc = bill.linkedDocument {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attached Document")
                                .font(.headline)

                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.primaryBlue)
                                Text(doc.filename)
                                    .font(.subheadline)
                                Spacer()
                                Text(doc.formattedFileSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

                    // Notes
                    if let billNotes = bill.notes, !billNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(billNotes)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                }
            }

            // Bottom buttons
            HStack {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }

                Spacer()

                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(minWidth: 520, maxWidth: 520, minHeight: 550, maxHeight: 700)
        .confirmationDialog("Delete Bill?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteBill(bill, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this bill and its linked document.")
        }
    }
}

#Preview {
    BillsView()
}
