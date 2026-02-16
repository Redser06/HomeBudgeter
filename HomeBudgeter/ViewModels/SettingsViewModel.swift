import Foundation
import SwiftUI

// MARK: - SettingsViewModel

/// View-model for app-wide user preferences.
///
/// Settings are persisted to `UserDefaults` via `didSet` observers.
/// Uses stored properties so `@Bindable` works correctly with the `@Observable` macro.
///
/// Locale changes are propagated immediately to `LocaleManager` (and therefore
/// to `CurrencyFormatter.shared`) so every currency display in the app updates
/// automatically.
@Observable
final class SettingsViewModel {

    // MARK: - Persisted Stored Properties
    // Each property reads its initial value from UserDefaults in init(),
    // and writes back in didSet. Stored properties play nicely with @Bindable.

    /// The user's selected locale / region.
    var selectedLocale: AppLocale {
        didSet {
            UserDefaults.standard.set(selectedLocale.rawValue, forKey: Keys.selectedLocale)
            // Sync the currency formatter with the new locale
            CurrencyFormatter.shared.setLocale(selectedLocale)
        }
    }

    /// First day of the week (0 = Sunday … 6 = Saturday). Default: 1 (Monday).
    var startOfWeek: Int {
        didSet { UserDefaults.standard.set(startOfWeek, forKey: Keys.startOfWeek) }
    }

    /// Threshold (50–100 %) at which a budget alert fires.
    var budgetAlertThreshold: Double {
        didSet { UserDefaults.standard.set(budgetAlertThreshold, forKey: Keys.budgetAlertThreshold) }
    }

    /// Whether the app should follow the system dark/light mode override.
    var darkMode: Bool {
        didSet { UserDefaults.standard.set(darkMode, forKey: Keys.darkMode) }
    }

    /// Whether budget-alert push notifications are enabled.
    var enableNotifications: Bool {
        didSet { UserDefaults.standard.set(enableNotifications, forKey: Keys.enableNotifications) }
    }

    /// Default transaction type for the add-transaction sheet.
    var defaultTransactionType: TransactionType {
        didSet { UserDefaults.standard.set(defaultTransactionType.rawValue, forKey: Keys.defaultTransactionType) }
    }

    /// Day of the month used as the budget "start" (1–28). Default: 1.
    var firstDayOfMonth: Int {
        didSet { UserDefaults.standard.set(firstDayOfMonth, forKey: Keys.firstDayOfMonth) }
    }

    /// Show pence / cents in currency displays.
    var showCentsInDisplay: Bool {
        didSet { UserDefaults.standard.set(showCentsInDisplay, forKey: Keys.showCentsInDisplay) }
    }

    /// Preferred colour scheme override.
    var darkModePreference: DarkModePreference {
        didSet { UserDefaults.standard.set(darkModePreference.rawValue, forKey: Keys.darkModePreference) }
    }

    /// Whether uploaded documents should be encrypted at rest.
    var encryptDocuments: Bool {
        didSet { UserDefaults.standard.set(encryptDocuments, forKey: Keys.encryptDocuments) }
    }

    /// The user's preferred AI provider for payslip parsing.
    var preferredAIProvider: AIProvider {
        didSet { UserDefaults.standard.set(preferredAIProvider.rawValue, forKey: Keys.preferredAIProvider) }
    }

    /// Whether payslip parsing should be attempted automatically on file import.
    var autoParsePayslips: Bool {
        didSet { UserDefaults.standard.set(autoParsePayslips, forKey: Keys.autoParsePayslips) }
    }

    /// Whether bill parsing should be attempted automatically on file import.
    var autoParseBills: Bool {
        didSet { UserDefaults.standard.set(autoParseBills, forKey: Keys.autoParseBills) }
    }

    // MARK: - Enumerations

    enum DarkModePreference: String, CaseIterable {
        case system = "System"
        case light  = "Light"
        case dark   = "Dark"

        /// The SwiftUI `ColorScheme` this preference maps to (nil = follow system).
        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    // MARK: - Computed Display Properties

    /// ISO 4217 currency code for the active locale (derived from locale).
    var currency: String { selectedLocale.currencyCode }

    /// Tax labels for the active locale.
    var taxLabels: TaxLabels { selectedLocale.taxLabels }

    /// Human-readable description of the active locale and its currency.
    var localeDescription: String {
        "\(selectedLocale.displayName) (\(selectedLocale.currencyCode))"
    }

    /// Example of how a typical amount looks in the active locale.
    var currencyExample: String { selectedLocale.exampleFormatted }

    /// Whether a Claude API key is configured in the Keychain.
    var isClaudeKeyConfigured: Bool {
        KeychainManager.shared.retrieve(key: .claudeApiKey) != nil
    }

    /// Whether a Gemini API key is configured in the Keychain.
    var isGeminiKeyConfigured: Bool {
        KeychainManager.shared.retrieve(key: .geminiApiKey) != nil
    }

    /// The week-day name for `startOfWeek`.
    var startOfWeekName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard startOfWeek < symbols.count else { return "Monday" }
        return symbols[startOfWeek]
    }

    /// Threshold formatted as a percentage string, e.g. "80%".
    var budgetAlertThresholdFormatted: String {
        "\(Int(budgetAlertThreshold))%"
    }

    // MARK: - Init

    init() {
        // Restore each setting from UserDefaults with sensible defaults.

        if let raw = UserDefaults.standard.string(forKey: Keys.selectedLocale),
           let locale = AppLocale(rawValue: raw) {
            self.selectedLocale = locale
        } else {
            self.selectedLocale = .ireland
        }

        let sow = UserDefaults.standard.integer(forKey: Keys.startOfWeek)
        self.startOfWeek = sow == 0 && UserDefaults.standard.object(forKey: Keys.startOfWeek) == nil ? 1 : sow

        let threshold = UserDefaults.standard.double(forKey: Keys.budgetAlertThreshold)
        self.budgetAlertThreshold = threshold == 0 ? 80 : threshold

        self.darkMode = UserDefaults.standard.bool(forKey: Keys.darkMode)

        // enableNotifications defaults to true when never set
        if UserDefaults.standard.object(forKey: Keys.enableNotifications) == nil {
            self.enableNotifications = true
        } else {
            self.enableNotifications = UserDefaults.standard.bool(forKey: Keys.enableNotifications)
        }

        if let typeRaw = UserDefaults.standard.string(forKey: Keys.defaultTransactionType),
           let type = TransactionType(rawValue: typeRaw) {
            self.defaultTransactionType = type
        } else {
            self.defaultTransactionType = .expense
        }

        let dom = UserDefaults.standard.integer(forKey: Keys.firstDayOfMonth)
        self.firstDayOfMonth = dom == 0 ? 1 : dom

        // showCentsInDisplay defaults to true when never set
        if UserDefaults.standard.object(forKey: Keys.showCentsInDisplay) == nil {
            self.showCentsInDisplay = true
        } else {
            self.showCentsInDisplay = UserDefaults.standard.bool(forKey: Keys.showCentsInDisplay)
        }

        if let modeRaw = UserDefaults.standard.string(forKey: Keys.darkModePreference),
           let mode = DarkModePreference(rawValue: modeRaw) {
            self.darkModePreference = mode
        } else {
            self.darkModePreference = .system
        }

        self.encryptDocuments = UserDefaults.standard.bool(forKey: Keys.encryptDocuments)

        if let providerRaw = UserDefaults.standard.string(forKey: Keys.preferredAIProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            self.preferredAIProvider = provider
        } else {
            self.preferredAIProvider = .claude
        }

        if UserDefaults.standard.object(forKey: Keys.autoParsePayslips) == nil {
            self.autoParsePayslips = true
        } else {
            self.autoParsePayslips = UserDefaults.standard.bool(forKey: Keys.autoParsePayslips)
        }

        if UserDefaults.standard.object(forKey: Keys.autoParseBills) == nil {
            self.autoParseBills = true
        } else {
            self.autoParseBills = UserDefaults.standard.bool(forKey: Keys.autoParseBills)
        }

        // Ensure CurrencyFormatter is aligned with the restored locale.
        CurrencyFormatter.shared.setLocale(selectedLocale)
    }

    // MARK: - Actions

    /// Resets all settings to their factory defaults.
    func resetToDefaults() {
        selectedLocale           = .ireland
        startOfWeek              = 1
        budgetAlertThreshold     = 80
        darkMode                 = false
        enableNotifications      = true
        defaultTransactionType   = .expense
        firstDayOfMonth          = 1
        showCentsInDisplay       = true
        darkModePreference       = .system
        encryptDocuments         = false
        preferredAIProvider      = .claude
        autoParsePayslips        = true
        autoParseBills           = true
    }

    /// Removes the encryption key from the Keychain.
    /// Existing encrypted documents will become unreadable.
    func clearEncryptionKey() {
        let keychain = KeychainManager.shared
        try? keychain.delete(key: .encryptionSalt)
    }

    /// Saves or updates an API key for the specified AI provider.
    func saveAPIKey(_ key: String, for provider: AIProvider) {
        let keychainKey: KeychainManager.KeychainKey = provider == .claude ? .claudeApiKey : .geminiApiKey
        if key.isEmpty {
            try? KeychainManager.shared.delete(key: keychainKey)
        } else {
            try? KeychainManager.shared.upsert(key: keychainKey, value: key)
        }
    }

    /// Removes the API key for the specified provider from the Keychain.
    func clearAPIKey(for provider: AIProvider) {
        let keychainKey: KeychainManager.KeychainKey = provider == .claude ? .claudeApiKey : .geminiApiKey
        try? KeychainManager.shared.delete(key: keychainKey)
    }

    /// Exports app data to a temporary JSON file and returns its URL.
    func exportData() async throws -> URL {
        let payload = ExportData(
            exportDate: Date(),
            locale: selectedLocale.rawValue,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting     = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        let url  = FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeBudgeter_Export_\(Date().ISO8601Format()).json")
        try data.write(to: url)
        return url
    }

    // MARK: - Private Constants

    private enum Keys {
        static let selectedLocale          = "selectedLocale"
        static let startOfWeek             = "startOfWeek"
        static let budgetAlertThreshold    = "budgetAlertThreshold"
        static let darkMode                = "darkMode"
        static let enableNotifications     = "enableNotifications"
        static let defaultTransactionType  = "defaultTransactionType"
        static let firstDayOfMonth         = "firstDayOfMonth"
        static let showCentsInDisplay      = "showCentsInDisplay"
        static let darkModePreference      = "darkModePreference"
        static let encryptDocuments        = "encryptDocuments"
        static let preferredAIProvider     = "preferredAIProvider"
        static let autoParsePayslips       = "autoParsePayslips"
        static let autoParseBills          = "autoParseBills"
    }
}

// MARK: - ExportData

struct ExportData: Codable {
    let exportDate: Date
    let locale: String
    let version: String
}
