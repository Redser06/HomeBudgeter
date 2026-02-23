//
//  PayslipView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PayslipView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PayslipViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Payslips")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Track your income and deductions")
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button {
                    viewModel.showingFileImporter = true
                } label: {
                    Label("Upload Payslip", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.showingCreateSheet = true
                } label: {
                    Label("Add Payslip", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Overview Cards
            let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                PayslipOverviewCard(
                    title: "Total Gross YTD",
                    amount: Double(truncating: viewModel.totalGrossYTD as NSNumber),
                    subtitle: "Before deductions",
                    color: .primaryBlue
                )
                PayslipOverviewCard(
                    title: "Total Net YTD",
                    amount: Double(truncating: viewModel.totalNetYTD as NSNumber),
                    subtitle: "Take-home pay",
                    color: .budgetHealthy
                )
                PayslipOverviewCard(
                    title: "Average Net",
                    amount: Double(truncating: viewModel.averageNetPay as NSNumber),
                    subtitle: "Per payslip",
                    color: .budgetWarning
                )
                PayslipOverviewCard(
                    title: "Income Tax YTD",
                    amount: Double(truncating: viewModel.totalTaxYTD as NSNumber),
                    subtitle: "PAYE only",
                    color: .budgetDanger
                )
                PayslipOverviewCard(
                    title: "Total Tax Paid YTD",
                    amount: Double(truncating: viewModel.totalAllTaxYTD as NSNumber),
                    subtitle: "PAYE + PRSI + USC",
                    color: .budgetDanger.opacity(0.85)
                )
                PayslipPercentageCard(
                    title: "Effective Tax Rate",
                    percentage: viewModel.effectiveTaxRate,
                    subtitle: "All taxes / gross",
                    color: .orange
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

                Picker("Employer", selection: Binding(
                    get: { viewModel.filterEmployer ?? "" },
                    set: { viewModel.filterEmployer = $0.isEmpty ? nil : $0 }
                )) {
                    Text("All Employers").tag("")
                    ForEach(viewModel.availableEmployers, id: \.self) { employer in
                        Text(employer).tag(employer)
                    }
                }
                .frame(width: 200)

                Spacer()

                Text("\(viewModel.filteredPayslips.count) payslip\(viewModel.filteredPayslips.count == 1 ? "" : "s")")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Payslip List
            ScrollView {
                LazyVStack(spacing: 12) {
                    if viewModel.filteredPayslips.isEmpty {
                        ContentUnavailableView(
                            "No Payslips",
                            systemImage: "doc.text",
                            description: Text("Add your first payslip to start tracking your income")
                        )
                        .padding(.top, 60)
                    } else {
                        ForEach(viewModel.payslipsGroupedByMonth, id: \.month) { group in
                            Section {
                                ForEach(group.payslips) { payslip in
                                    PayslipRow(payslip: payslip) {
                                        viewModel.selectedPayslip = payslip
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
            viewModel.loadPayslips(modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingCreateSheet) {
            AddPayslipSheet(viewModel: viewModel, modelContext: modelContext)
        }
        .sheet(item: $viewModel.selectedPayslip) { payslip in
            PayslipDetailSheet(viewModel: viewModel, payslip: payslip, modelContext: modelContext)
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
                        await viewModel.importPayslipFile(from: url, modelContext: modelContext)
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

struct PayslipOverviewCard: View {
    let title: String
    let amount: Double
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(CurrencyFormatter.shared.format(amount))
                .font(.system(.title, design: .monospaced))
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

// MARK: - Percentage Card

struct PayslipPercentageCard: View {
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
                .font(.system(.title, design: .monospaced))
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

// MARK: - Payslip Row

struct PayslipRow: View {
    let payslip: Payslip
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.primaryBlue)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(payslip.formattedPayDate)
                        .font(.headline)

                    if let employer = payslip.employer, !employer.isEmpty {
                        Text(employer)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primaryBlue.opacity(0.15))
                            .foregroundColor(.primaryBlue)
                            .cornerRadius(4)
                    }

                    Spacer()
                }

                Text(payslip.payPeriodDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Amounts
            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.shared.format(Double(truncating: payslip.netPay as NSNumber)))
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.budgetHealthy)

                Text("Gross: \(CurrencyFormatter.shared.format(Double(truncating: payslip.grossPay as NSNumber)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

// MARK: - Add Payslip Sheet

struct AddPayslipSheet: View {
    var viewModel: PayslipViewModel
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var payDate = Date()
    @State private var payPeriodStart = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var payPeriodEnd = Date()
    @State private var grossPay: Double = 0
    @State private var netPay: Double = 0
    @State private var incomeTax: Double = 0
    @State private var socialInsurance: Double = 0
    @State private var hasUniversalCharge: Bool = false
    @State private var universalCharge: Double = 0
    @State private var pensionContribution: Double = 0
    @State private var employerPensionContribution: Double = 0
    @State private var otherDeductions: Double = 0
    @State private var healthInsurancePremium: Double = 0
    @State private var employer: String = ""
    @State private var notes: String = ""

    private var currencyCode: String {
        CurrencyFormatter.shared.locale.currencyCode
    }

    private var attachedDocument: Document? {
        viewModel.importedDocument
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("New Payslip")
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
                    Text("Parsing payslip with AI...")
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
                Section("Pay Details") {
                    DatePicker("Pay Date", selection: $payDate, displayedComponents: .date)
                    DatePicker("Period Start", selection: $payPeriodStart, displayedComponents: .date)
                    DatePicker("Period End", selection: $payPeriodEnd, displayedComponents: .date)
                    TextField("Employer (optional)", text: $employer)
                }

                Section("Earnings") {
                    HStack {
                        Text("Gross Pay")
                        Spacer()
                        TextField("Amount", value: $grossPay, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Net Pay")
                        Spacer()
                        TextField("Amount", value: $netPay, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section("Deductions") {
                    HStack {
                        Text("Income Tax")
                        Spacer()
                        TextField("Amount", value: $incomeTax, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Social Insurance")
                        Spacer()
                        TextField("Amount", value: $socialInsurance, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }

                    Toggle("Universal Charge", isOn: $hasUniversalCharge)

                    if hasUniversalCharge {
                        HStack {
                            Text("Universal Charge")
                            Spacer()
                            TextField("Amount", value: $universalCharge, format: .currency(code: currencyCode))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                        }
                    }

                    HStack {
                        Text("Health Insurance")
                        Spacer()
                        TextField("Amount", value: $healthInsurancePremium, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }

                    HStack {
                        Text("Other Deductions")
                        Spacer()
                        TextField("Amount", value: $otherDeductions, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section("Pension") {
                    HStack {
                        Text("Employee Contribution")
                        Spacer()
                        TextField("Amount", value: $pensionContribution, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                    HStack {
                        Text("Employer Contribution")
                        Spacer()
                        TextField("Amount", value: $employerPensionContribution, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                Section("Notes") {
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    viewModel.importedDocument = nil
                    viewModel.parsedData = nil
                    viewModel.parsingError = nil
                    dismiss()
                }
                    .buttonStyle(.bordered)

                Button("Add Payslip") {
                    viewModel.createPayslip(
                        payDate: payDate,
                        payPeriodStart: payPeriodStart,
                        payPeriodEnd: payPeriodEnd,
                        grossPay: Decimal(string: String(grossPay)) ?? 0,
                        netPay: Decimal(string: String(netPay)) ?? 0,
                        incomeTax: Decimal(string: String(incomeTax)) ?? 0,
                        socialInsurance: Decimal(string: String(socialInsurance)) ?? 0,
                        universalCharge: hasUniversalCharge ? Decimal(string: String(universalCharge)) ?? 0 : nil,
                        pensionContribution: Decimal(string: String(pensionContribution)) ?? 0,
                        employerPensionContribution: Decimal(string: String(employerPensionContribution)) ?? 0,
                        otherDeductions: Decimal(string: String(otherDeductions)) ?? 0,
                        healthInsurancePremium: Decimal(string: String(healthInsurancePremium)) ?? 0,
                        employer: employer.isEmpty ? nil : employer,
                        notes: notes.isEmpty ? nil : notes,
                        modelContext: modelContext
                    )
                    // Link uploaded document to the new payslip if present
                    if let doc = attachedDocument, let newPayslip = viewModel.payslips.first {
                        viewModel.linkDocumentToPayslip(newPayslip, document: doc, modelContext: modelContext)
                    }
                    viewModel.importedDocument = nil
                    viewModel.parsedData = nil
                    viewModel.parsingError = nil
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(grossPay <= 0 || netPay <= 0)
            }
        }
        .padding()
        .frame(width: 500, height: 750)
        .onAppear {
            if let parsed = viewModel.parsedData {
                if let date = ParsedPayslipData.toDate(parsed.payDate) {
                    payDate = date
                }
                if let date = ParsedPayslipData.toDate(parsed.payPeriodStart) {
                    payPeriodStart = date
                }
                if let date = ParsedPayslipData.toDate(parsed.payPeriodEnd) {
                    payPeriodEnd = date
                }

                grossPay = Double(truncating: ParsedPayslipData.toDecimal(parsed.grossPay) as NSNumber)
                netPay = Double(truncating: ParsedPayslipData.toDecimal(parsed.netPay) as NSNumber)
                incomeTax = Double(truncating: ParsedPayslipData.toDecimal(parsed.incomeTax) as NSNumber)
                socialInsurance = Double(truncating: ParsedPayslipData.toDecimal(parsed.socialInsurance) as NSNumber)

                if let usc = parsed.universalCharge, ParsedPayslipData.toDecimal(usc) > 0 {
                    hasUniversalCharge = true
                    universalCharge = Double(truncating: ParsedPayslipData.toDecimal(usc) as NSNumber)
                }

                pensionContribution = Double(truncating: ParsedPayslipData.toDecimal(parsed.pensionContribution) as NSNumber)
                employerPensionContribution = Double(truncating: ParsedPayslipData.toDecimal(parsed.employerPensionContribution) as NSNumber)
                otherDeductions = Double(truncating: ParsedPayslipData.toDecimal(parsed.otherDeductions) as NSNumber)
                healthInsurancePremium = Double(truncating: ParsedPayslipData.toDecimal(parsed.healthInsurancePremium) as NSNumber)

                if let emp = parsed.employer, !emp.isEmpty {
                    employer = emp
                }
            }
        }
    }
}

// MARK: - Payslip Detail / Edit Sheet

struct PayslipDetailSheet: View {
    var viewModel: PayslipViewModel
    let payslip: Payslip
    var modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing: Bool = false
    @State private var showingDeleteConfirmation = false

    // Editable fields
    @State private var payDate: Date
    @State private var payPeriodStart: Date
    @State private var payPeriodEnd: Date
    @State private var grossPay: Double
    @State private var netPay: Double
    @State private var incomeTax: Double
    @State private var socialInsurance: Double
    @State private var hasUniversalCharge: Bool
    @State private var universalCharge: Double
    @State private var pensionContribution: Double
    @State private var employerPensionContribution: Double
    @State private var otherDeductions: Double
    @State private var healthInsurancePremium: Double
    @State private var employer: String
    @State private var notes: String

    init(viewModel: PayslipViewModel, payslip: Payslip, modelContext: ModelContext) {
        self.viewModel = viewModel
        self.payslip = payslip
        self.modelContext = modelContext
        _payDate = State(initialValue: payslip.payDate)
        _payPeriodStart = State(initialValue: payslip.payPeriodStart)
        _payPeriodEnd = State(initialValue: payslip.payPeriodEnd)
        _grossPay = State(initialValue: Double(truncating: payslip.grossPay as NSNumber))
        _netPay = State(initialValue: Double(truncating: payslip.netPay as NSNumber))
        _incomeTax = State(initialValue: Double(truncating: payslip.incomeTax as NSNumber))
        _socialInsurance = State(initialValue: Double(truncating: payslip.socialInsurance as NSNumber))
        _hasUniversalCharge = State(initialValue: payslip.universalCharge != nil)
        _universalCharge = State(initialValue: Double(truncating: (payslip.universalCharge ?? 0) as NSNumber))
        _pensionContribution = State(initialValue: Double(truncating: payslip.pensionContribution as NSNumber))
        _employerPensionContribution = State(initialValue: Double(truncating: payslip.employerPensionContribution as NSNumber))
        _otherDeductions = State(initialValue: Double(truncating: payslip.otherDeductions as NSNumber))
        _healthInsurancePremium = State(initialValue: Double(truncating: payslip.healthInsurancePremium as NSNumber))
        _employer = State(initialValue: payslip.employer ?? "")
        _notes = State(initialValue: payslip.notes ?? "")
    }

    private var currencyCode: String {
        CurrencyFormatter.shared.locale.currencyCode
    }

    private var deductionPercentage: Double {
        guard Double(truncating: payslip.grossPay as NSNumber) > 0 else { return 0 }
        return Double(truncating: payslip.totalDeductions as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
    }

    private var taxPercentage: Double {
        guard Double(truncating: payslip.grossPay as NSNumber) > 0 else { return 0 }
        return Double(truncating: payslip.incomeTax as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
    }

    private var socialInsurancePercentage: Double {
        guard Double(truncating: payslip.grossPay as NSNumber) > 0 else { return 0 }
        return Double(truncating: payslip.socialInsurance as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
    }

    private var pensionPercentage: Double {
        guard Double(truncating: payslip.grossPay as NSNumber) > 0 else { return 0 }
        return Double(truncating: payslip.pensionContribution as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.primaryBlue)
                    .cornerRadius(12)

                VStack(alignment: .leading) {
                    Text(isEditing ? "Edit Payslip" : "Payslip Details")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(payslip.formattedPayDate)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if !isEditing {
                    Button {
                        isEditing = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if isEditing {
                editFormView
            } else {
                detailView
            }

            // Bottom buttons
            HStack {
                Button("Delete", role: .destructive) {
                    showingDeleteConfirmation = true
                }

                Spacer()

                if isEditing {
                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.bordered)

                    Button("Save") {
                        payslip.payDate = payDate
                        payslip.payPeriodStart = payPeriodStart
                        payslip.payPeriodEnd = payPeriodEnd
                        payslip.grossPay = Decimal(string: String(grossPay)) ?? 0
                        payslip.netPay = Decimal(string: String(netPay)) ?? 0
                        payslip.incomeTax = Decimal(string: String(incomeTax)) ?? 0
                        payslip.socialInsurance = Decimal(string: String(socialInsurance)) ?? 0
                        payslip.universalCharge = hasUniversalCharge ? Decimal(string: String(universalCharge)) ?? 0 : nil
                        payslip.pensionContribution = Decimal(string: String(pensionContribution)) ?? 0
                        payslip.employerPensionContribution = Decimal(string: String(employerPensionContribution)) ?? 0
                        payslip.otherDeductions = Decimal(string: String(otherDeductions)) ?? 0
                        payslip.healthInsurancePremium = Decimal(string: String(healthInsurancePremium)) ?? 0
                        payslip.employer = employer.isEmpty ? nil : employer
                        payslip.notes = notes.isEmpty ? nil : notes
                        viewModel.updatePayslip(payslip, modelContext: modelContext)
                        isEditing = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(grossPay <= 0 || netPay <= 0)
                } else {
                    Button("Close") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(width: 520, height: 650)
        .confirmationDialog("Delete Payslip?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deletePayslip(payslip, modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this payslip record.")
        }
    }

    // MARK: - Detail View

    private var detailView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Earnings section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Earnings")
                        .font(.headline)

                    HStack {
                        Text("Gross Pay")
                        Spacer()
                        Text(CurrencyFormatter.shared.format(Double(truncating: payslip.grossPay as NSNumber)))
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Net Pay")
                        Spacer()
                        Text(CurrencyFormatter.shared.format(Double(truncating: payslip.netPay as NSNumber)))
                            .fontWeight(.semibold)
                            .foregroundColor(.budgetHealthy)
                    }

                    if let employer = payslip.employer, !employer.isEmpty {
                        HStack {
                            Text("Employer")
                            Spacer()
                            Text(employer)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Pay Period")
                        Spacer()
                        Text(payslip.payPeriodDescription)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Deductions breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("Deductions")
                        .font(.headline)

                    Text("Total: \(CurrencyFormatter.shared.format(Double(truncating: payslip.totalDeductions as NSNumber))) (\(String(format: "%.1f", deductionPercentage))% of gross)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    DeductionBar(
                        label: "Income Tax",
                        amount: Double(truncating: payslip.incomeTax as NSNumber),
                        percentage: taxPercentage,
                        color: .budgetDanger
                    )
                    DeductionBar(
                        label: "Social Insurance",
                        amount: Double(truncating: payslip.socialInsurance as NSNumber),
                        percentage: socialInsurancePercentage,
                        color: .budgetWarning
                    )

                    if let uc = payslip.universalCharge {
                        let ucPercentage = Double(truncating: payslip.grossPay as NSNumber) > 0
                            ? Double(truncating: uc as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
                            : 0
                        DeductionBar(
                            label: "Universal Charge",
                            amount: Double(truncating: uc as NSNumber),
                            percentage: ucPercentage,
                            color: .orange
                        )
                    }

                    if payslip.pensionContribution > 0 {
                        DeductionBar(
                            label: "Pension (Employee)",
                            amount: Double(truncating: payslip.pensionContribution as NSNumber),
                            percentage: pensionPercentage,
                            color: .primaryBlue
                        )
                    }

                    if payslip.healthInsurancePremium > 0 {
                        let healthPercentage = Double(truncating: payslip.grossPay as NSNumber) > 0
                            ? Double(truncating: payslip.healthInsurancePremium as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
                            : 0
                        DeductionBar(
                            label: "Health Insurance",
                            amount: Double(truncating: payslip.healthInsurancePremium as NSNumber),
                            percentage: healthPercentage,
                            color: .pink
                        )
                    }

                    if payslip.otherDeductions > 0 {
                        let otherPercentage = Double(truncating: payslip.grossPay as NSNumber) > 0
                            ? Double(truncating: payslip.otherDeductions as NSNumber) / Double(truncating: payslip.grossPay as NSNumber) * 100
                            : 0
                        DeductionBar(
                            label: "Other Deductions",
                            amount: Double(truncating: payslip.otherDeductions as NSNumber),
                            percentage: otherPercentage,
                            color: .gray
                        )
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(12)

                // Pension section
                if payslip.totalPensionContribution > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pension Contributions")
                            .font(.headline)

                        HStack {
                            Text("Employee")
                            Spacer()
                            Text(CurrencyFormatter.shared.format(Double(truncating: payslip.pensionContribution as NSNumber)))
                        }
                        HStack {
                            Text("Employer")
                            Spacer()
                            Text(CurrencyFormatter.shared.format(Double(truncating: payslip.employerPensionContribution as NSNumber)))
                        }
                        Divider()
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(CurrencyFormatter.shared.format(Double(truncating: payslip.totalPensionContribution as NSNumber)))
                                .fontWeight(.semibold)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                }

                // Notes section
                if let payslipNotes = payslip.notes, !payslipNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(payslipNotes)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Edit Form View

    private var editFormView: some View {
        Form {
            Section("Pay Details") {
                DatePicker("Pay Date", selection: $payDate, displayedComponents: .date)
                DatePicker("Period Start", selection: $payPeriodStart, displayedComponents: .date)
                DatePicker("Period End", selection: $payPeriodEnd, displayedComponents: .date)
                TextField("Employer", text: $employer)
            }

            Section("Earnings") {
                HStack {
                    Text("Gross Pay")
                    Spacer()
                    TextField("Amount", value: $grossPay, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
                HStack {
                    Text("Net Pay")
                    Spacer()
                    TextField("Amount", value: $netPay, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
            }

            Section("Deductions") {
                HStack {
                    Text("Income Tax")
                    Spacer()
                    TextField("Amount", value: $incomeTax, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
                HStack {
                    Text("Social Insurance")
                    Spacer()
                    TextField("Amount", value: $socialInsurance, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }

                Toggle("Universal Charge", isOn: $hasUniversalCharge)

                if hasUniversalCharge {
                    HStack {
                        Text("Universal Charge")
                        Spacer()
                        TextField("Amount", value: $universalCharge, format: .currency(code: currencyCode))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 140)
                    }
                }

                HStack {
                    Text("Health Insurance")
                    Spacer()
                    TextField("Amount", value: $healthInsurancePremium, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }

                HStack {
                    Text("Other Deductions")
                    Spacer()
                    TextField("Amount", value: $otherDeductions, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
            }

            Section("Pension") {
                HStack {
                    Text("Employee Contribution")
                    Spacer()
                    TextField("Amount", value: $pensionContribution, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
                HStack {
                    Text("Employer Contribution")
                    Spacer()
                    TextField("Amount", value: $employerPensionContribution, format: .currency(code: currencyCode))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 140)
                }
            }

            Section("Notes") {
                TextField("Notes", text: $notes)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Deduction Bar

struct DeductionBar: View {
    let label: String
    let amount: Double
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(CurrencyFormatter.shared.format(amount))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("(\(String(format: "%.1f", percentage))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(percentage / 100, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview {
    PayslipView()
}
