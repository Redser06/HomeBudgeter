//
//  SettingsViewModelTests.swift
//  HomeBudgeterTests
//

import XCTest
@testable import Home_Budgeter

final class SettingsViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear all settings keys before each test to ensure clean state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedLocale")
        defaults.removeObject(forKey: "startOfWeek")
        defaults.removeObject(forKey: "budgetAlertThreshold")
        defaults.removeObject(forKey: "darkMode")
        defaults.removeObject(forKey: "enableNotifications")
        defaults.removeObject(forKey: "defaultTransactionType")
        defaults.removeObject(forKey: "firstDayOfMonth")
        defaults.removeObject(forKey: "showCentsInDisplay")
        defaults.removeObject(forKey: "darkModePreference")
    }

    override func tearDown() {
        // Clean up after each test
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "selectedLocale")
        defaults.removeObject(forKey: "startOfWeek")
        defaults.removeObject(forKey: "budgetAlertThreshold")
        defaults.removeObject(forKey: "darkMode")
        defaults.removeObject(forKey: "enableNotifications")
        defaults.removeObject(forKey: "defaultTransactionType")
        defaults.removeObject(forKey: "firstDayOfMonth")
        defaults.removeObject(forKey: "showCentsInDisplay")
        defaults.removeObject(forKey: "darkModePreference")
        super.tearDown()
    }

    // MARK: - Default Values

    func test_init_defaultLocaleIsIreland() {
        let sut = SettingsViewModel()
        XCTAssertEqual(sut.selectedLocale, .ireland)
    }

    func test_init_defaultTransactionTypeIsExpense() {
        let sut = SettingsViewModel()
        XCTAssertEqual(sut.defaultTransactionType, .expense)
    }

    func test_init_defaultBudgetAlertThresholdIs80() {
        let sut = SettingsViewModel()
        XCTAssertEqual(sut.budgetAlertThreshold, 80.0, accuracy: 0.01)
    }

    func test_init_defaultFirstDayOfMonthIs1() {
        let sut = SettingsViewModel()
        XCTAssertEqual(sut.firstDayOfMonth, 1)
    }

    func test_init_defaultDarkModePreferenceIsSystem() {
        let sut = SettingsViewModel()
        XCTAssertEqual(sut.darkModePreference, .system)
    }

    func test_init_defaultShowCentsIsTrue() {
        let sut = SettingsViewModel()
        XCTAssertTrue(sut.showCentsInDisplay)
    }

    func test_init_defaultEnableNotificationsIsTrue() {
        let sut = SettingsViewModel()
        XCTAssertTrue(sut.enableNotifications)
    }

    func test_init_defaultDarkModeIsFalse() {
        let sut = SettingsViewModel()
        XCTAssertFalse(sut.darkMode)
    }

    // MARK: - Persistence Tests

    func test_selectedLocale_persistsToUserDefaults() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        let saved = UserDefaults.standard.string(forKey: "selectedLocale")
        XCTAssertEqual(saved, "gb")
    }

    func test_selectedLocale_persistsUSA() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .usa
        let saved = UserDefaults.standard.string(forKey: "selectedLocale")
        XCTAssertEqual(saved, "us")
    }

    func test_selectedLocale_persistsEU() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .eu
        let saved = UserDefaults.standard.string(forKey: "selectedLocale")
        XCTAssertEqual(saved, "eu")
    }

    func test_showCentsInDisplay_persistsTrue() {
        let sut = SettingsViewModel()
        sut.showCentsInDisplay = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "showCentsInDisplay"))
    }

    func test_showCentsInDisplay_persistsFalse() {
        let sut = SettingsViewModel()
        sut.showCentsInDisplay = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "showCentsInDisplay"))
    }

    func test_defaultTransactionType_persistsIncome() {
        let sut = SettingsViewModel()
        sut.defaultTransactionType = .income
        let saved = UserDefaults.standard.string(forKey: "defaultTransactionType")
        XCTAssertEqual(saved, "Income")
    }

    func test_enableNotifications_persistsFalse() {
        let sut = SettingsViewModel()
        sut.enableNotifications = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "enableNotifications"))
    }

    func test_budgetAlertThreshold_persistsCustomValue() {
        let sut = SettingsViewModel()
        sut.budgetAlertThreshold = 90.0
        XCTAssertEqual(UserDefaults.standard.double(forKey: "budgetAlertThreshold"), 90.0, accuracy: 0.01)
    }

    func test_firstDayOfMonth_persistsCustomValue() {
        let sut = SettingsViewModel()
        sut.firstDayOfMonth = 15
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "firstDayOfMonth"), 15)
    }

    func test_darkModePreference_persistsDark() {
        let sut = SettingsViewModel()
        sut.darkModePreference = .dark
        let saved = UserDefaults.standard.string(forKey: "darkModePreference")
        XCTAssertEqual(saved, "Dark")
    }

    func test_darkModePreference_persistsLight() {
        let sut = SettingsViewModel()
        sut.darkModePreference = .light
        let saved = UserDefaults.standard.string(forKey: "darkModePreference")
        XCTAssertEqual(saved, "Light")
    }

    // MARK: - taxLabels Computed Property

    func test_taxLabels_forIreland_returnsPAYE() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .ireland
        XCTAssertEqual(sut.taxLabels.incomeTax, "PAYE")
    }

    func test_taxLabels_forUK_returnsIncomeTax() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        XCTAssertEqual(sut.taxLabels.incomeTax, "Income Tax")
    }

    func test_taxLabels_forUSA_returnsFederalTax() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .usa
        XCTAssertEqual(sut.taxLabels.incomeTax, "Federal Tax")
    }

    func test_taxLabels_forEU_returnsIncomeTax() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .eu
        XCTAssertEqual(sut.taxLabels.incomeTax, "Income Tax")
    }

    // MARK: - currency Computed Property

    func test_currency_forIreland_returnsEUR() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .ireland
        XCTAssertEqual(sut.currency, "EUR")
    }

    func test_currency_forUK_returnsGBP() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        XCTAssertEqual(sut.currency, "GBP")
    }

    func test_currency_forUSA_returnsUSD() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .usa
        XCTAssertEqual(sut.currency, "USD")
    }

    // MARK: - localeDescription Tests

    func test_localeDescription_forIreland_containsIreland() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .ireland
        XCTAssertTrue(sut.localeDescription.contains("Ireland"))
    }

    func test_localeDescription_forIreland_containsEUR() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .ireland
        XCTAssertTrue(sut.localeDescription.contains("EUR"))
    }

    func test_localeDescription_forUK_containsGBP() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        XCTAssertTrue(sut.localeDescription.contains("GBP"))
    }

    // MARK: - budgetAlertThresholdFormatted Tests

    func test_budgetAlertThresholdFormatted_showsPercentSign() {
        let sut = SettingsViewModel()
        sut.budgetAlertThreshold = 80
        XCTAssertTrue(sut.budgetAlertThresholdFormatted.contains("%"))
    }

    func test_budgetAlertThresholdFormatted_showsCorrectValue() {
        let sut = SettingsViewModel()
        sut.budgetAlertThreshold = 75
        XCTAssertEqual(sut.budgetAlertThresholdFormatted, "75%")
    }

    // MARK: - resetToDefaults Tests

    func test_resetToDefaults_setsLocaleToIreland() {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        sut.resetToDefaults()
        XCTAssertEqual(sut.selectedLocale, .ireland)
    }

    func test_resetToDefaults_setsShowCentsToTrue() {
        let sut = SettingsViewModel()
        sut.showCentsInDisplay = false
        sut.resetToDefaults()
        XCTAssertTrue(sut.showCentsInDisplay)
    }

    func test_resetToDefaults_setsDefaultTransactionTypeToExpense() {
        let sut = SettingsViewModel()
        sut.defaultTransactionType = .income
        sut.resetToDefaults()
        XCTAssertEqual(sut.defaultTransactionType, .expense)
    }

    func test_resetToDefaults_enablesNotifications() {
        let sut = SettingsViewModel()
        sut.enableNotifications = false
        sut.resetToDefaults()
        XCTAssertTrue(sut.enableNotifications)
    }

    func test_resetToDefaults_setsBudgetAlertTo80() {
        let sut = SettingsViewModel()
        sut.budgetAlertThreshold = 95.0
        sut.resetToDefaults()
        XCTAssertEqual(sut.budgetAlertThreshold, 80.0, accuracy: 0.01)
    }

    func test_resetToDefaults_setsFirstDayTo1() {
        let sut = SettingsViewModel()
        sut.firstDayOfMonth = 15
        sut.resetToDefaults()
        XCTAssertEqual(sut.firstDayOfMonth, 1)
    }

    func test_resetToDefaults_setsDarkModePreferenceToSystem() {
        let sut = SettingsViewModel()
        sut.darkModePreference = .dark
        sut.resetToDefaults()
        XCTAssertEqual(sut.darkModePreference, .system)
    }

    func test_resetToDefaults_setsDarkModeToFalse() {
        let sut = SettingsViewModel()
        sut.darkMode = true
        sut.resetToDefaults()
        XCTAssertFalse(sut.darkMode)
    }

    // MARK: - DarkModePreference Enum

    func test_darkModePreference_allCasesCount() {
        XCTAssertEqual(SettingsViewModel.DarkModePreference.allCases.count, 3)
    }

    func test_darkModePreference_rawValues() {
        XCTAssertEqual(SettingsViewModel.DarkModePreference.system.rawValue, "System")
        XCTAssertEqual(SettingsViewModel.DarkModePreference.light.rawValue, "Light")
        XCTAssertEqual(SettingsViewModel.DarkModePreference.dark.rawValue, "Dark")
    }

    func test_darkModePreference_system_colorSchemeIsNil() {
        XCTAssertNil(SettingsViewModel.DarkModePreference.system.colorScheme)
    }

    func test_darkModePreference_light_colorSchemeIsLight() {
        XCTAssertEqual(SettingsViewModel.DarkModePreference.light.colorScheme, .light)
    }

    func test_darkModePreference_dark_colorSchemeIsDark() {
        XCTAssertEqual(SettingsViewModel.DarkModePreference.dark.colorScheme, .dark)
    }

    // MARK: - exportData Tests

    func test_exportData_producesValidURL() async throws {
        let sut = SettingsViewModel()
        let url = try await sut.exportData()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportData_producesJSONFile() async throws {
        let sut = SettingsViewModel()
        let url = try await sut.exportData()
        XCTAssertEqual(url.pathExtension, "json")
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportData_producesDecodableJSON() async throws {
        let sut = SettingsViewModel()
        let url = try await sut.exportData()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertFalse(decoded.locale.isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    func test_exportData_containsCurrentLocale() async throws {
        let sut = SettingsViewModel()
        sut.selectedLocale = .uk
        let url = try await sut.exportData()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ExportData.self, from: data)
        XCTAssertEqual(decoded.locale, "gb")
        try? FileManager.default.removeItem(at: url)
    }
}
