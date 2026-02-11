//
//  AppLocaleTests.swift
//  HomeBudgeterTests
//

import XCTest
@testable import Home_Budgeter

final class AppLocaleTests: XCTestCase {

    // MARK: - Enum Coverage Tests

    func test_allCases_containsFourLocales() {
        XCTAssertEqual(AppLocale.allCases.count, 4)
    }

    func test_allCases_containsExpectedLocales() {
        XCTAssertTrue(AppLocale.allCases.contains(.ireland))
        XCTAssertTrue(AppLocale.allCases.contains(.uk))
        XCTAssertTrue(AppLocale.allCases.contains(.usa))
        XCTAssertTrue(AppLocale.allCases.contains(.eu))
    }

    // MARK: - Raw Values

    func test_rawValue_ireland() {
        XCTAssertEqual(AppLocale.ireland.rawValue, "ie")
    }

    func test_rawValue_uk() {
        XCTAssertEqual(AppLocale.uk.rawValue, "gb")
    }

    func test_rawValue_usa() {
        XCTAssertEqual(AppLocale.usa.rawValue, "us")
    }

    func test_rawValue_eu() {
        XCTAssertEqual(AppLocale.eu.rawValue, "eu")
    }

    // MARK: - Identifiable

    func test_id_matchesRawValue() {
        for locale in AppLocale.allCases {
            XCTAssertEqual(locale.id, locale.rawValue)
        }
    }

    // MARK: - Display Names

    func test_displayName_ireland() {
        XCTAssertEqual(AppLocale.ireland.displayName, "Ireland")
    }

    func test_displayName_uk() {
        XCTAssertEqual(AppLocale.uk.displayName, "United Kingdom")
    }

    func test_displayName_usa() {
        XCTAssertEqual(AppLocale.usa.displayName, "United States")
    }

    func test_displayName_eu() {
        XCTAssertEqual(AppLocale.eu.displayName, "European Union")
    }

    func test_allDisplayNames_areNonEmpty() {
        for locale in AppLocale.allCases {
            XCTAssertFalse(locale.displayName.isEmpty, "Display name for \(locale.rawValue) is empty")
        }
    }

    // MARK: - Currency Codes

    func test_currencyCode_ireland_isEUR() {
        XCTAssertEqual(AppLocale.ireland.currencyCode, "EUR")
    }

    func test_currencyCode_eu_isEUR() {
        XCTAssertEqual(AppLocale.eu.currencyCode, "EUR")
    }

    func test_currencyCode_uk_isGBP() {
        XCTAssertEqual(AppLocale.uk.currencyCode, "GBP")
    }

    func test_currencyCode_usa_isUSD() {
        XCTAssertEqual(AppLocale.usa.currencyCode, "USD")
    }

    func test_allCurrencyCodes_areNonEmpty() {
        for locale in AppLocale.allCases {
            XCTAssertFalse(locale.currencyCode.isEmpty, "Currency code for \(locale.rawValue) is empty")
        }
    }

    // MARK: - Currency Symbols

    func test_currencySymbol_ireland_isEuroSign() {
        XCTAssertEqual(AppLocale.ireland.currencySymbol, "€")
    }

    func test_currencySymbol_eu_isEuroSign() {
        XCTAssertEqual(AppLocale.eu.currencySymbol, "€")
    }

    func test_currencySymbol_uk_isPoundSign() {
        XCTAssertEqual(AppLocale.uk.currencySymbol, "£")
    }

    func test_currencySymbol_usa_isDollarSign() {
        XCTAssertEqual(AppLocale.usa.currencySymbol, "$")
    }

    func test_allCurrencySymbols_areNonEmpty() {
        for locale in AppLocale.allCases {
            XCTAssertFalse(locale.currencySymbol.isEmpty, "Currency symbol for \(locale.rawValue) is empty")
        }
    }

    // MARK: - Locale Identifiers

    func test_locale_ireland_isEnIE() {
        XCTAssertEqual(AppLocale.ireland.locale.identifier, "en_IE")
    }

    func test_locale_uk_isEnGB() {
        XCTAssertEqual(AppLocale.uk.locale.identifier, "en_GB")
    }

    func test_locale_usa_isEnUS() {
        XCTAssertEqual(AppLocale.usa.locale.identifier, "en_US")
    }

    func test_locale_eu_isDeDE() {
        XCTAssertEqual(AppLocale.eu.locale.identifier, "de_DE")
    }

    // MARK: - Tax Labels - Ireland (PAYE)

    func test_taxLabels_ireland_incomeTaxIsPAYE() {
        XCTAssertEqual(AppLocale.ireland.taxLabels.incomeTax, "PAYE")
    }

    func test_taxLabels_ireland_socialInsuranceIsPRSI() {
        XCTAssertEqual(AppLocale.ireland.taxLabels.socialInsurance, "PRSI")
    }

    func test_taxLabels_ireland_universalChargeIsUSC() {
        XCTAssertEqual(AppLocale.ireland.taxLabels.universalCharge, "USC")
    }

    func test_taxLabels_ireland_hasUniversalCharge() {
        XCTAssertNotNil(AppLocale.ireland.taxLabels.universalCharge)
    }

    // MARK: - Tax Labels - UK

    func test_taxLabels_uk_incomeTaxLabel() {
        XCTAssertEqual(AppLocale.uk.taxLabels.incomeTax, "Income Tax")
    }

    func test_taxLabels_uk_socialInsuranceIsNI() {
        XCTAssertEqual(AppLocale.uk.taxLabels.socialInsurance, "National Insurance")
    }

    func test_taxLabels_uk_noUniversalCharge() {
        XCTAssertNil(AppLocale.uk.taxLabels.universalCharge)
    }

    // MARK: - Tax Labels - USA

    func test_taxLabels_usa_incomeTaxIsFederal() {
        XCTAssertEqual(AppLocale.usa.taxLabels.incomeTax, "Federal Tax")
    }

    func test_taxLabels_usa_socialInsuranceIsSocialSecurity() {
        XCTAssertEqual(AppLocale.usa.taxLabels.socialInsurance, "Social Security")
    }

    func test_taxLabels_usa_universalChargeIsMedicare() {
        XCTAssertEqual(AppLocale.usa.taxLabels.universalCharge, "Medicare")
    }

    func test_taxLabels_usa_hasUniversalCharge() {
        XCTAssertNotNil(AppLocale.usa.taxLabels.universalCharge)
    }

    // MARK: - Tax Labels - EU

    func test_taxLabels_eu_incomeTaxLabel() {
        XCTAssertEqual(AppLocale.eu.taxLabels.incomeTax, "Income Tax")
    }

    func test_taxLabels_eu_socialInsuranceIsContributions() {
        XCTAssertEqual(AppLocale.eu.taxLabels.socialInsurance, "Social Contributions")
    }

    func test_taxLabels_eu_noUniversalCharge() {
        XCTAssertNil(AppLocale.eu.taxLabels.universalCharge)
    }

    // MARK: - Codable Tests

    func test_codable_roundTrip_ireland() throws {
        let original = AppLocale.ireland
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppLocale.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func test_codable_roundTrip_allLocales() throws {
        for locale in AppLocale.allCases {
            let encoded = try JSONEncoder().encode(locale)
            let decoded = try JSONDecoder().decode(AppLocale.self, from: encoded)
            XCTAssertEqual(decoded, locale)
        }
    }

    func test_init_fromRawValue_ireland() {
        let locale = AppLocale(rawValue: "ie")
        XCTAssertEqual(locale, .ireland)
    }

    func test_init_fromRawValue_invalidValue_returnsNil() {
        let locale = AppLocale(rawValue: "invalid_locale")
        XCTAssertNil(locale)
    }

    // MARK: - TaxLabels Tests

    func test_taxLabels_init_withAllFields() {
        let labels = TaxLabels(incomeTax: "Tax A", socialInsurance: "Insurance B", universalCharge: "Charge C")
        XCTAssertEqual(labels.incomeTax, "Tax A")
        XCTAssertEqual(labels.socialInsurance, "Insurance B")
        XCTAssertEqual(labels.universalCharge, "Charge C")
    }

    func test_taxLabels_init_withNilUniversalCharge() {
        let labels = TaxLabels(incomeTax: "Tax A", socialInsurance: "Insurance B", universalCharge: nil)
        XCTAssertNil(labels.universalCharge)
    }
}
