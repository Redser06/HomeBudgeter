//
//  CurrencyFormatterTests.swift
//  HomeBudgeterTests
//

import XCTest
@testable import Home_Budgeter

final class CurrencyFormatterTests: XCTestCase {

    // Use a fresh formatter instance-like test object for each test
    // We work with CurrencyFormatter.shared but reset locale before each test

    override func setUp() {
        super.setUp()
        // Reset to Ireland (default) before every test
        CurrencyFormatter.shared.setLocale(.ireland)
    }

    override func tearDown() {
        CurrencyFormatter.shared.setLocale(.ireland)
        super.tearDown()
    }

    // MARK: - Locale Property

    func test_locale_defaultIsIreland() {
        XCTAssertEqual(CurrencyFormatter.shared.locale, .ireland)
    }

    func test_setLocale_toUK_updatesLocale() {
        CurrencyFormatter.shared.setLocale(.uk)
        XCTAssertEqual(CurrencyFormatter.shared.locale, .uk)
    }

    func test_setLocale_toUSA_updatesLocale() {
        CurrencyFormatter.shared.setLocale(.usa)
        XCTAssertEqual(CurrencyFormatter.shared.locale, .usa)
    }

    func test_setLocale_toEU_updatesLocale() {
        CurrencyFormatter.shared.setLocale(.eu)
        XCTAssertEqual(CurrencyFormatter.shared.locale, .eu)
    }

    // MARK: - currencySymbol Property

    func test_currencySymbol_ireland_isEuro() {
        CurrencyFormatter.shared.setLocale(.ireland)
        XCTAssertEqual(CurrencyFormatter.shared.currencySymbol, "€")
    }

    func test_currencySymbol_uk_isPound() {
        CurrencyFormatter.shared.setLocale(.uk)
        XCTAssertEqual(CurrencyFormatter.shared.currencySymbol, "£")
    }

    func test_currencySymbol_usa_isDollar() {
        CurrencyFormatter.shared.setLocale(.usa)
        XCTAssertEqual(CurrencyFormatter.shared.currencySymbol, "$")
    }

    func test_currencySymbol_eu_isEuro() {
        CurrencyFormatter.shared.setLocale(.eu)
        XCTAssertEqual(CurrencyFormatter.shared.currencySymbol, "€")
    }

    // MARK: - currencyCode Property

    func test_currencyCode_ireland_isEUR() {
        CurrencyFormatter.shared.setLocale(.ireland)
        XCTAssertEqual(CurrencyFormatter.shared.currencyCode, "EUR")
    }

    func test_currencyCode_uk_isGBP() {
        CurrencyFormatter.shared.setLocale(.uk)
        XCTAssertEqual(CurrencyFormatter.shared.currencyCode, "GBP")
    }

    func test_currencyCode_usa_isUSD() {
        CurrencyFormatter.shared.setLocale(.usa)
        XCTAssertEqual(CurrencyFormatter.shared.currencyCode, "USD")
    }

    func test_currencyCode_eu_isEUR() {
        CurrencyFormatter.shared.setLocale(.eu)
        XCTAssertEqual(CurrencyFormatter.shared.currencyCode, "EUR")
    }

    // MARK: - format(Decimal) - Ireland

    func test_format_decimal_ireland_containsEuroSymbol() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(100))
        XCTAssertTrue(result.contains("€"), "Expected € in '\(result)'")
    }

    func test_format_decimal_ireland_zero_formatsCorrectly() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(0))
        XCTAssertTrue(result.contains("0"), "Expected 0 in '\(result)'")
    }

    func test_format_decimal_ireland_largeNumber_isNonEmpty() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(1_234_567.89))
        XCTAssertFalse(result.isEmpty)
    }

    func test_format_decimal_ireland_negativeAmount_isNonEmpty() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(-500))
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("500"))
    }

    // MARK: - format(Decimal) - UK

    func test_format_decimal_uk_containsPoundSymbol() {
        CurrencyFormatter.shared.setLocale(.uk)
        let result = CurrencyFormatter.shared.format(Decimal(100))
        XCTAssertTrue(result.contains("£"), "Expected £ in '\(result)'")
    }

    func test_format_decimal_uk_negativeAmount_containsMinus() {
        CurrencyFormatter.shared.setLocale(.uk)
        let result = CurrencyFormatter.shared.format(Decimal(-250))
        XCTAssertTrue(result.contains("250"))
    }

    // MARK: - format(Decimal) - USA

    func test_format_decimal_usa_containsDollarSymbol() {
        CurrencyFormatter.shared.setLocale(.usa)
        let result = CurrencyFormatter.shared.format(Decimal(100))
        XCTAssertTrue(result.contains("$"), "Expected $ in '\(result)'")
    }

    func test_format_decimal_usa_largeNumber_formatsCorrectly() {
        CurrencyFormatter.shared.setLocale(.usa)
        let result = CurrencyFormatter.shared.format(Decimal(99999.99))
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - format(Decimal) - EU

    func test_format_decimal_eu_containsEuroSymbol() {
        CurrencyFormatter.shared.setLocale(.eu)
        let result = CurrencyFormatter.shared.format(Decimal(100))
        XCTAssertTrue(result.contains("€"), "Expected € in '\(result)'")
    }

    // MARK: - format(Double) Tests

    func test_format_double_ireland_matches_decimal_format() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let doubleResult = CurrencyFormatter.shared.format(100.0)
        let decimalResult = CurrencyFormatter.shared.format(Decimal(100))
        XCTAssertEqual(doubleResult, decimalResult)
    }

    func test_format_double_zero() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(0.0)
        XCTAssertFalse(result.isEmpty)
    }

    func test_format_double_negative() {
        CurrencyFormatter.shared.setLocale(.uk)
        let result = CurrencyFormatter.shared.format(-99.99)
        XCTAssertTrue(result.contains("99"))
    }

    // MARK: - formatCompact Tests

    func test_formatCompact_below1000_usesFullFormat() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(500))
        XCTAssertTrue(result.contains("€"))
    }

    func test_formatCompact_exactly1000_usesKSuffix() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(1000))
        XCTAssertTrue(result.contains("K"), "Expected K in '\(result)'")
    }

    func test_formatCompact_1500_showsCorrectValue() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(1500))
        XCTAssertTrue(result.contains("1.5K"), "Expected 1.5K in '\(result)'")
    }

    func test_formatCompact_1Million_usesMSuffix() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(1_000_000))
        XCTAssertTrue(result.contains("M"), "Expected M in '\(result)'")
    }

    func test_formatCompact_2_5Million_showsCorrectValue() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(2_500_000))
        XCTAssertTrue(result.contains("2.5M"), "Expected 2.5M in '\(result)'")
    }

    func test_formatCompact_uk_1000_containsK() {
        CurrencyFormatter.shared.setLocale(.uk)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(5000))
        XCTAssertTrue(result.contains("K"))
    }

    func test_formatCompact_usa_1000_containsK() {
        CurrencyFormatter.shared.setLocale(.usa)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(3500))
        XCTAssertTrue(result.contains("K"))
    }

    func test_formatCompact_negative1500_containsSign() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(Decimal(-1500))
        XCTAssertTrue(result.contains("1.5K"))
    }

    func test_formatCompact_double_below1000_usesFullFormat() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatCompact(500.0)
        XCTAssertTrue(result.contains("€"))
    }

    // MARK: - parse Tests - Ireland

    func test_parse_ireland_plainNumber_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parse("123.45")
        XCTAssertEqual(result, Decimal(string: "123.45"))
    }

    func test_parse_ireland_withEuroSymbol_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parse("€100.00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 100)
    }

    func test_parse_ireland_withThousandsSeparator_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parse("1,234.56")
        XCTAssertNotNil(result)
    }

    func test_parse_ireland_invalidString_returnsNil() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parse("not_a_number")
        XCTAssertNil(result)
    }

    func test_parse_ireland_emptyString_returnsNil() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parse("")
        XCTAssertNil(result)
    }

    // MARK: - parse Tests - EU

    func test_parse_eu_withCommaDecimal_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.eu)
        // EU uses comma as decimal separator
        let result = CurrencyFormatter.shared.parse("1.234,56")
        XCTAssertNotNil(result)
    }

    func test_parse_eu_withEuroSymbol_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.eu)
        let result = CurrencyFormatter.shared.parse("€100")
        XCTAssertNotNil(result)
    }

    // MARK: - parse Tests - UK

    func test_parse_uk_withPoundSymbol_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.uk)
        let result = CurrencyFormatter.shared.parse("£500.00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 500)
    }

    // MARK: - parse Tests - USA

    func test_parse_usa_withDollarSymbol_returnsDecimal() {
        CurrencyFormatter.shared.setLocale(.usa)
        let result = CurrencyFormatter.shared.parse("$1234.56")
        XCTAssertNotNil(result)
    }

    // MARK: - parseDouble Tests

    func test_parseDouble_validString_returnsDouble() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parseDouble("€250.00")
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 250.0, accuracy: 0.01)
    }

    func test_parseDouble_invalidString_returnsNil() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.parseDouble("abc")
        XCTAssertNil(result)
    }

    // MARK: - formatWithSign Tests

    func test_formatWithSign_positiveAmount_withForceSign_addsPlusPrefix() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatWithSign(100.0, forceSign: true)
        XCTAssertTrue(result.hasPrefix("+"))
    }

    func test_formatWithSign_positiveAmount_withoutForceSign_noPlusPrefix() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatWithSign(100.0, forceSign: false)
        XCTAssertFalse(result.hasPrefix("+"))
    }

    func test_formatWithSign_negativeAmount_addsMinus() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatWithSign(-100.0)
        XCTAssertTrue(result.hasPrefix("-"))
    }

    func test_formatWithSign_zeroAmount_noSign() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.formatWithSign(0.0, forceSign: false)
        XCTAssertFalse(result.hasPrefix("+"))
        XCTAssertFalse(result.hasPrefix("-"))
    }

    // MARK: - Edge Cases

    func test_format_verySmallDecimal_isNonEmpty() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(string: "0.01")!)
        XCTAssertFalse(result.isEmpty)
    }

    func test_format_veryLargeAmount_isNonEmpty() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let result = CurrencyFormatter.shared.format(Decimal(9_999_999_999.99))
        XCTAssertFalse(result.isEmpty)
    }

    func test_switchLocale_formatsCorrectSymbol() {
        CurrencyFormatter.shared.setLocale(.ireland)
        let irishFormat = CurrencyFormatter.shared.format(Decimal(100))

        CurrencyFormatter.shared.setLocale(.uk)
        let ukFormat = CurrencyFormatter.shared.format(Decimal(100))

        XCTAssertTrue(irishFormat.contains("€"))
        XCTAssertTrue(ukFormat.contains("£"))
        XCTAssertNotEqual(irishFormat, ukFormat)
    }
}
