//
//  SettingsView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var showingExportPanel = false
    @State private var showingImportPanel = false
    @State private var showingClearDataAlert = false
    @State private var showingResetConfirmation = false
    @State private var showingClearKeychainAlert = false
    @State private var exportMessage: String?
    @State private var importMessage: String?
    @State private var claudeApiKeyInput: String = ""
    @State private var geminiApiKeyInput: String = ""
    @State private var isEditingClaudeKey: Bool = false
    @State private var isEditingGeminiKey: Bool = false
    @State private var isTestingClaude: Bool = false
    @State private var isTestingGemini: Bool = false
    @State private var claudeTestResult: Bool?
    @State private var geminiTestResult: Bool?

    let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        @Bindable var vm = viewModel
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Customize your experience")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()

            Form {
                // Locale & Currency Section
                Section {
                    Picker("Region", selection: $vm.selectedLocale) {
                        ForEach(AppLocale.allCases) { locale in
                            HStack {
                                Text(locale.flag)
                                Text(locale.displayName)
                            }
                            .tag(locale)
                        }
                    }

                    LabeledContent("Currency") {
                        HStack {
                            Text(viewModel.selectedLocale.currencySymbol)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                            Text(viewModel.selectedLocale.currencyCode)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Show tax labels for selected locale
                    DisclosureGroup("Tax Labels") {
                        LabeledContent("Income Tax", value: viewModel.taxLabels.incomeTax)
                        LabeledContent("Social Insurance", value: viewModel.taxLabels.socialInsurance)
                        if let universalCharge = viewModel.taxLabels.universalCharge {
                            LabeledContent("Universal Charge", value: universalCharge)
                        }
                    }
                } header: {
                    Label("Locale & Currency", systemImage: "globe")
                }

                // Calendar Section
                Section {
                    Picker("Start of Week", selection: $vm.startOfWeek) {
                        ForEach(0..<7, id: \.self) { day in
                            Text(weekdays[day]).tag(day)
                        }
                    }

                    Picker("Budget Month Starts", selection: $vm.firstDayOfMonth) {
                        ForEach(1...28, id: \.self) { day in
                            Text("Day \(day)").tag(day)
                        }
                    }
                } header: {
                    Label("Calendar", systemImage: "calendar")
                }

                // Appearance Section
                Section {
                    Picker("Appearance", selection: $vm.darkModePreference) {
                        ForEach(SettingsViewModel.DarkModePreference.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Show cents in display", isOn: $vm.showCentsInDisplay)
                } header: {
                    Label("Appearance", systemImage: "paintbrush")
                }

                // Notifications Section
                Section {
                    Toggle("Enable Notifications", isOn: $vm.enableNotifications)

                    if viewModel.enableNotifications {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Budget Alert Threshold")
                                Spacer()
                                Text("\(Int(viewModel.budgetAlertThreshold))%")
                                    .foregroundColor(thresholdColor)
                                    .fontWeight(.medium)
                            }

                            Slider(
                                value: $vm.budgetAlertThreshold,
                                in: 50...100,
                                step: 5
                            )
                            .tint(thresholdColor)

                            Text("Get notified when spending exceeds this percentage of your budget")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Notifications", systemImage: "bell")
                }

                // Default Behavior Section
                Section {
                    Picker("Default Transaction Type", selection: $vm.defaultTransactionType) {
                        Text("Expense").tag(TransactionType.expense)
                        Text("Income").tag(TransactionType.income)
                    }
                } header: {
                    Label("Defaults", systemImage: "slider.horizontal.3")
                }

                // Security Section
                Section {
                    Toggle("Encrypt Documents", isOn: $vm.encryptDocuments)

                    Text("When enabled, uploaded documents are encrypted using AES-256-GCM before being stored on disk. The encryption key is stored securely in the macOS Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(role: .destructive) {
                        showingClearKeychainAlert = true
                    } label: {
                        Label("Clear Encryption Key", systemImage: "key.slash")
                    }
                } header: {
                    Label("Security", systemImage: "lock.shield")
                }

                // AI & Parsing Section
                Section {
                    Picker("Preferred Provider", selection: $vm.preferredAIProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }

                    Toggle("Auto-parse imported payslips", isOn: $vm.autoParsePayslips)
                    Toggle("Auto-parse imported bills", isOn: $vm.autoParseBills)

                    Text("When enabled, uploaded PDF documents are automatically parsed using AI to pre-fill forms.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

                    // Claude API Key
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Claude API Key")
                            if viewModel.isClaudeKeyConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.budgetHealthy)
                                    .font(.caption)
                            }
                        }
                        Text("From console.anthropic.com")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if isEditingClaudeKey {
                            HStack {
                                SecureField("sk-ant-...", text: $claudeApiKeyInput)
                                Button("Save") {
                                    if !claudeApiKeyInput.isEmpty {
                                        viewModel.saveAPIKey(claudeApiKeyInput, for: .claude)
                                    }
                                    claudeApiKeyInput = ""
                                    isEditingClaudeKey = false
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                Button("Cancel") {
                                    claudeApiKeyInput = ""
                                    isEditingClaudeKey = false
                                }
                                .controlSize(.small)
                            }
                        } else if viewModel.isClaudeKeyConfigured {
                            HStack {
                                Text("sk-ant-****configured****")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Update") {
                                    claudeApiKeyInput = ""
                                    isEditingClaudeKey = true
                                }
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    viewModel.clearAPIKey(for: .claude)
                                    claudeTestResult = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .controlSize(.small)
                            }
                        } else {
                            HStack {
                                Text("Not configured")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Add Key") {
                                    claudeApiKeyInput = ""
                                    isEditingClaudeKey = true
                                }
                                .controlSize(.small)
                            }
                        }
                    }

                    HStack {
                        Button {
                            Task {
                                isTestingClaude = true
                                claudeTestResult = nil
                                claudeTestResult = await PayslipParsingService.shared.testConnection(provider: .claude)
                                isTestingClaude = false
                            }
                        } label: {
                            if isTestingClaude {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Test Claude", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(!viewModel.isClaudeKeyConfigured || isTestingClaude)

                        if let result = claudeTestResult {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .budgetHealthy : .budgetDanger)
                        }
                    }

                    Divider()

                    // Gemini API Key
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("Gemini API Key")
                            if viewModel.isGeminiKeyConfigured {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.budgetHealthy)
                                    .font(.caption)
                            }
                        }
                        Text("From aistudio.google.com")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        if isEditingGeminiKey {
                            HStack {
                                SecureField("AI...", text: $geminiApiKeyInput)
                                Button("Save") {
                                    if !geminiApiKeyInput.isEmpty {
                                        viewModel.saveAPIKey(geminiApiKeyInput, for: .gemini)
                                    }
                                    geminiApiKeyInput = ""
                                    isEditingGeminiKey = false
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                Button("Cancel") {
                                    geminiApiKeyInput = ""
                                    isEditingGeminiKey = false
                                }
                                .controlSize(.small)
                            }
                        } else if viewModel.isGeminiKeyConfigured {
                            HStack {
                                Text("****configured****")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Update") {
                                    geminiApiKeyInput = ""
                                    isEditingGeminiKey = true
                                }
                                .controlSize(.small)
                                Button(role: .destructive) {
                                    viewModel.clearAPIKey(for: .gemini)
                                    geminiTestResult = nil
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .controlSize(.small)
                            }
                        } else {
                            HStack {
                                Text("Not configured")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Add Key") {
                                    geminiApiKeyInput = ""
                                    isEditingGeminiKey = true
                                }
                                .controlSize(.small)
                            }
                        }
                    }

                    HStack {
                        Button {
                            Task {
                                isTestingGemini = true
                                geminiTestResult = nil
                                geminiTestResult = await PayslipParsingService.shared.testConnection(provider: .gemini)
                                isTestingGemini = false
                            }
                        } label: {
                            if isTestingGemini {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Test Gemini", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(!viewModel.isGeminiKeyConfigured || isTestingGemini)

                        if let result = geminiTestResult {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .budgetHealthy : .budgetDanger)
                        }
                    }
                } header: {
                    Label("AI & Parsing", systemImage: "cpu")
                }

                // Data Management Section
                Section {
                    Button {
                        showingExportPanel = true
                    } label: {
                        HStack {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingImportPanel = true
                    } label: {
                        HStack {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        showingClearDataAlert = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } header: {
                    Label("Data Management", systemImage: "externaldrive")
                }

                // About Section
                Section {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: buildNumber)

                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        HStack {
                            Label("Privacy Policy", systemImage: "hand.raised")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Label("Terms of Service", systemImage: "doc.text")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        sendFeedback()
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingResetConfirmation = true
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                } header: {
                    Label("About", systemImage: "info.circle")
                } footer: {
                    VStack(spacing: 4) {
                        Text("Home Budgeter")
                            .fontWeight(.medium)
                        Text("Made with care in Ireland")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 500)
        .fileExporter(
            isPresented: $showingExportPanel,
            document: ExportDocument(),
            contentType: .json,
            defaultFilename: "HomeBudgeter_Export_\(Date().ISO8601Format())"
        ) { result in
            switch result {
            case .success(let url):
                exportMessage = "Data exported to \(url.lastPathComponent)"
            case .failure(let error):
                exportMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importData(from: url)
                }
            case .failure(let error):
                importMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .alert("Clear All Data?", isPresented: $showingClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All Data", role: .destructive) {
                clearAllData()
            }
        } message: {
            Text("This will permanently delete all your transactions, budgets, and documents. This action cannot be undone.")
        }
        .alert("Reset Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .alert("Export Complete", isPresented: .init(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("OK") { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
        .alert("Clear Encryption Key?", isPresented: $showingClearKeychainAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Key", role: .destructive) {
                viewModel.clearEncryptionKey()
            }
        } message: {
            Text("This will permanently delete the encryption key from the Keychain. Any previously encrypted documents will become unreadable. This cannot be undone.")
        }
        .alert("Import Complete", isPresented: .init(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private var thresholdColor: Color {
        if viewModel.budgetAlertThreshold >= 90 {
            return .budgetDanger
        } else if viewModel.budgetAlertThreshold >= 75 {
            return .budgetWarning
        }
        return .budgetHealthy
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private func sendFeedback() {
        let email = "feedback@homebudgeter.app"
        let subject = "Home Budgeter Feedback - v\(appVersion)"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            NSWorkspace.shared.open(url)
        }
    }

    private func importData(from url: URL) {
        // Placeholder for import functionality
        importMessage = "Import functionality coming soon! Selected: \(url.lastPathComponent)"
    }

    private func clearAllData() {
        // Placeholder for clear data functionality
        print("Clearing all data...")
    }
}

// MARK: - Export Document
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    init() {}

    init(configuration: ReadConfiguration) throws {}

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let exportData = ExportData(
            exportDate: Date(),
            locale: CurrencyFormatter.shared.locale.rawValue,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(exportData)
        return FileWrapper(regularFileWithContents: data)
    }
}


#Preview {
    SettingsView()
}
