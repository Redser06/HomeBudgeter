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
    @State private var recurringViewModel = RecurringViewModel()

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
                    ForEach(viewModel.availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .frame(width: 120)

                // Grouped bill type filter
                Menu {
                    Button("All Types") {
                        viewModel.filterBillType = nil
                    }
                    Divider()
                    ForEach(BillType.Group.allCases) { group in
                        Section(group.rawValue) {
                            ForEach(group.types) { type in
                                Button {
                                    viewModel.filterBillType = type
                                } label: {
                                    Label(type.rawValue, systemImage: type.icon)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let selected = viewModel.filterBillType {
                            Image(systemName: selected.icon)
                            Text(selected.rawValue)
                        } else {
                            Text("All Types")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }

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
        .onChange(of: viewModel.showingCreateSheet) { _, isShowing in
            if !isShowing {
                viewModel.loadBills(modelContext: modelContext)
            }
        }
        .sheet(item: $viewModel.selectedBill) { bill in
            BillDetailSheet(viewModel: viewModel, bill: bill, modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedBill) { _, selected in
            if selected == nil {
                viewModel.loadBills(modelContext: modelContext)
            }
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
        .sheet(isPresented: $viewModel.showingRecurringSuggestion) {
            if let result = viewModel.detectedRecurring {
                RecurringSuggestionSheet(
                    result: result,
                    recurringViewModel: recurringViewModel,
                    modelContext: modelContext,
                    onDismiss: {
                        viewModel.detectedRecurring = nil
                    }
                )
            }
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

    private var billTypes: [BillType] {
        let types = BillsViewModel.extractBillTypes(from: bill.notes)
        return types.isEmpty ? [.other] : types
    }

    private var primaryType: BillType {
        billTypes.first ?? .other
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: primaryType.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(primaryType.color)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(bill.descriptionText)
                        .font(.headline)

                    ForEach(billTypes) { type in
                        Text(type.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(type.color.opacity(0.15))
                            .foregroundColor(type.color)
                            .cornerRadius(4)
                    }

                    if bill.notes?.contains("[Estimate]") == true {
                        Text("Est.")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.budgetWarning.opacity(0.15))
                            .foregroundColor(.budgetWarning)
                            .cornerRadius(4)
                    }

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

// MARK: - Line Item Row (for AddBillSheet)

struct LineItemEntry: Identifiable {
    let id = UUID()
    var billType: BillType = .other
    var amount: Double = 0
    var label: String = ""
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
    @State private var useLineItems: Bool = false
    @State private var lineItems: [LineItemEntry] = []

    private var currencyCode: String {
        CurrencyFormatter.shared.locale.currencyCode
    }

    private var attachedDocument: Document? {
        viewModel.importedDocument
    }

    private var lineItemsTotal: Decimal {
        lineItems.reduce(Decimal.zero) { total, item in
            total + (Decimal(string: String(format: "%.2f", item.amount)) ?? 0)
        }
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
                    Toggle("Multiple line items", isOn: $useLineItems)

                    if useLineItems {
                        ForEach($lineItems) { $item in
                            HStack(spacing: 8) {
                                Picker("", selection: $item.billType) {
                                    ForEach(BillType.Group.allCases) { group in
                                        Section(group.rawValue) {
                                            ForEach(group.types) { type in
                                                Label(type.rawValue, systemImage: type.icon)
                                                    .tag(type)
                                            }
                                        }
                                    }
                                }
                                .frame(width: 160)

                                TextField("Amount", value: $item.amount, format: .currency(code: currencyCode))
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)

                                TextField("Label", text: $item.label)
                                    .frame(width: 100)

                                Button {
                                    lineItems.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.budgetDanger)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Button {
                            lineItems.append(LineItemEntry())
                        } label: {
                            Label("Add Line Item", systemImage: "plus.circle")
                        }

                        HStack {
                            Text("Total")
                                .fontWeight(.medium)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(
                                Double(truncating: lineItemsTotal as NSNumber)
                            ))
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.bold)
                        }
                    } else {
                        HStack {
                            Text("Total Amount")
                            Spacer()
                            TextField("Amount", value: $amount, format: .currency(code: currencyCode))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                        }
                    }
                }

                Section("Classification") {
                    if !useLineItems {
                        Picker("Bill Type", selection: $selectedBillType) {
                            ForEach(BillType.Group.allCases) { group in
                                Section(group.rawValue) {
                                    ForEach(group.types) { type in
                                        Label(type.rawValue, systemImage: type.icon)
                                            .tag(type)
                                    }
                                }
                            }
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
                    let resolvedLineItems: [(billType: BillType, amount: Decimal, label: String?)] =
                        useLineItems ? lineItems.map { entry in
                            (
                                billType: entry.billType,
                                amount: Decimal(string: String(format: "%.2f", entry.amount)) ?? 0,
                                label: entry.label.isEmpty ? nil : entry.label
                            )
                        } : []

                    let finalAmount: Decimal = useLineItems
                        ? lineItemsTotal
                        : (Decimal(string: String(format: "%.2f", amount)) ?? 0)

                    viewModel.createBillTransaction(
                        amount: finalAmount,
                        date: billDate,
                        vendor: vendor,
                        billType: selectedBillType,
                        categoryType: selectedCategoryType,
                        notes: notes.isEmpty ? nil : notes,
                        dueDate: hasDueDate ? dueDate : nil,
                        isRecurring: isRecurring,
                        recurringFrequency: isRecurring ? recurringFrequency : nil,
                        lineItems: resolvedLineItems,
                        modelContext: modelContext
                    )
                    viewModel.resetImportState()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(vendor.isEmpty || (useLineItems ? lineItemsTotal <= 0 : amount <= 0))
            }
        }
        .padding()
        .frame(width: 560, height: 750)
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

                // Check for line items from AI
                if let parsedItems = parsed.lineItems, parsedItems.count > 1 {
                    useLineItems = true
                    lineItems = parsedItems.map { item in
                        var entry = LineItemEntry()
                        if let typeStr = item.billType,
                           let type = BillType.allCases.first(where: { $0.rawValue == typeStr }) {
                            entry.billType = type
                        }
                        if let amtStr = item.amount {
                            entry.amount = Double(amtStr) ?? 0
                        }
                        entry.label = item.label ?? ""
                        return entry
                    }
                } else {
                    let totalAmount = ParsedBillData.toDecimal(parsed.totalAmount)
                    if totalAmount > 0 {
                        amount = Double(truncating: totalAmount as NSNumber)
                    }
                    selectedBillType = parsed.resolvedBillType
                }

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

    private var billTypes: [BillType] {
        let types = BillsViewModel.extractBillTypes(from: bill.notes)
        return types.isEmpty ? [.other] : types
    }

    private var primaryType: BillType {
        billTypes.first ?? .other
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: primaryType.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(primaryType.color)
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
                            Text("Type\(billTypes.count > 1 ? "s" : "")")
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(billTypes) { type in
                                    Label(type.rawValue, systemImage: type.icon)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(type.color.opacity(0.15))
                                        .foregroundColor(type.color)
                                        .cornerRadius(4)
                                }
                            }
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

                    // Line Items
                    if let items = bill.billLineItems, !items.isEmpty, items.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Line Items")
                                .font(.headline)

                            ForEach(items) { item in
                                HStack {
                                    Label(item.billType.rawValue, systemImage: item.billType.icon)
                                        .font(.subheadline)
                                        .foregroundColor(item.billType.color)
                                    if let label = item.label, !label.isEmpty {
                                        Text(label)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(CurrencyFormatter.shared.format(
                                        Double(truncating: item.amount as NSNumber)
                                    ))
                                    .font(.system(.subheadline, design: .monospaced))
                                }
                            }
                        }
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(12)
                    }

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
