//
//  BillParsingTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
@testable import Home_Budgeter

final class BillParsingTests: XCTestCase {

    // MARK: - ParsedBillData.toDecimal

    func test_toDecimal_withValidString_returnsCorrectDecimal() {
        let result = ParsedBillData.toDecimal("89.99")
        XCTAssertEqual(result, Decimal(string: "89.99"))
    }

    func test_toDecimal_withNil_returnsZero() {
        let result = ParsedBillData.toDecimal(nil)
        XCTAssertEqual(result, 0)
    }

    func test_toDecimal_withInvalidString_returnsZero() {
        let result = ParsedBillData.toDecimal("not a number")
        XCTAssertEqual(result, 0)
    }

    func test_toDecimal_withEmptyString_returnsZero() {
        let result = ParsedBillData.toDecimal("")
        XCTAssertEqual(result, 0)
    }

    // MARK: - ParsedBillData.toDate

    func test_toDate_withValidISO8601_returnsDate() {
        let result = ParsedBillData.toDate("2025-03-15")
        XCTAssertNotNil(result)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: result!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 15)
    }

    func test_toDate_withNil_returnsNil() {
        XCTAssertNil(ParsedBillData.toDate(nil))
    }

    func test_toDate_withInvalidString_returnsNil() {
        XCTAssertNil(ParsedBillData.toDate("not-a-date"))
    }

    func test_toDate_withEmptyString_returnsNil() {
        XCTAssertNil(ParsedBillData.toDate(""))
    }

    // MARK: - JSON Decoding

    func test_parsedBillData_decodesAllFields() throws {
        let json = """
        {
            "vendor": "Virgin Media Ireland",
            "billDate": "2025-03-01",
            "dueDate": "2025-03-15",
            "billingPeriodStart": "2025-02-01",
            "billingPeriodEnd": "2025-02-28",
            "totalAmount": "65.99",
            "subtotalAmount": "53.65",
            "taxAmount": "12.34",
            "accountNumber": "VM-12345678",
            "billType": "Internet & TV",
            "suggestedCategory": "Utilities",
            "confidence": 0.92
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)

        XCTAssertEqual(parsed.vendor, "Virgin Media Ireland")
        XCTAssertEqual(parsed.totalAmount, "65.99")
        XCTAssertEqual(parsed.taxAmount, "12.34")
        XCTAssertEqual(parsed.accountNumber, "VM-12345678")
        XCTAssertEqual(parsed.confidence, 0.92)
        XCTAssertEqual(ParsedBillData.toDecimal(parsed.totalAmount), Decimal(string: "65.99"))
        XCTAssertEqual(ParsedBillData.toDecimal(parsed.subtotalAmount), Decimal(string: "53.65"))
    }

    func test_parsedBillData_decodesWithNullFields() throws {
        let json = """
        {
            "vendor": "ESB",
            "billDate": null,
            "dueDate": null,
            "billingPeriodStart": null,
            "billingPeriodEnd": null,
            "totalAmount": "120.00",
            "subtotalAmount": null,
            "taxAmount": null,
            "accountNumber": null,
            "billType": null,
            "suggestedCategory": null,
            "confidence": 0.65
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)

        XCTAssertEqual(parsed.vendor, "ESB")
        XCTAssertNil(parsed.billDate)
        XCTAssertNil(parsed.dueDate)
        XCTAssertNil(parsed.taxAmount)
        XCTAssertNil(parsed.accountNumber)
        XCTAssertEqual(parsed.totalAmount, "120.00")
        XCTAssertEqual(ParsedBillData.toDecimal(parsed.subtotalAmount), 0)
    }

    // MARK: - BillType

    func test_billType_allCases() {
        let cases = BillType.allCases
        XCTAssertEqual(cases.count, 6)
        XCTAssertTrue(cases.contains(.internetTv))
        XCTAssertTrue(cases.contains(.gasElectric))
        XCTAssertTrue(cases.contains(.phone))
        XCTAssertTrue(cases.contains(.subscription))
        XCTAssertTrue(cases.contains(.insurance))
        XCTAssertTrue(cases.contains(.other))
    }

    func test_billType_defaultCategoryType() {
        XCTAssertEqual(BillType.internetTv.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.gasElectric.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.phone.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.subscription.defaultCategoryType, .entertainment)
        XCTAssertEqual(BillType.insurance.defaultCategoryType, .personal)
        XCTAssertEqual(BillType.other.defaultCategoryType, .other)
    }

    // MARK: - BillType.infer(from:)

    func test_infer_esb_returnsGasElectric() {
        XCTAssertEqual(BillType.infer(from: "ESB Networks"), .gasElectric)
    }

    func test_infer_bordGais_returnsGasElectric() {
        XCTAssertEqual(BillType.infer(from: "Bord Gáis Energy"), .gasElectric)
    }

    func test_infer_virginMedia_returnsInternetTv() {
        XCTAssertEqual(BillType.infer(from: "Virgin Media Ireland"), .internetTv)
    }

    func test_infer_sky_returnsInternetTv() {
        XCTAssertEqual(BillType.infer(from: "Sky Ireland"), .internetTv)
    }

    func test_infer_vodafone_returnsPhone() {
        XCTAssertEqual(BillType.infer(from: "Vodafone Ireland"), .phone)
    }

    func test_infer_three_returnsPhone() {
        XCTAssertEqual(BillType.infer(from: "Three Ireland"), .phone)
    }

    func test_infer_netflix_returnsSubscription() {
        XCTAssertEqual(BillType.infer(from: "Netflix"), .subscription)
    }

    func test_infer_spotify_returnsSubscription() {
        XCTAssertEqual(BillType.infer(from: "Spotify Premium"), .subscription)
    }

    func test_infer_aviva_returnsInsurance() {
        XCTAssertEqual(BillType.infer(from: "Aviva Insurance"), .insurance)
    }

    func test_infer_unknown_returnsOther() {
        XCTAssertEqual(BillType.infer(from: "Some Random Company"), .other)
    }

    func test_infer_nil_returnsOther() {
        XCTAssertEqual(BillType.infer(from: nil), .other)
    }

    // MARK: - resolvedBillType

    func test_resolvedBillType_withExplicitType_usesExplicit() throws {
        let json = """
        {
            "vendor": "Some Company",
            "totalAmount": "50.00",
            "billType": "Phone",
            "confidence": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedBillType, .phone)
    }

    func test_resolvedBillType_withNullType_infersFromVendor() throws {
        let json = """
        {
            "vendor": "Netflix",
            "totalAmount": "12.99",
            "billType": null,
            "confidence": 0.8
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedBillType, .subscription)
    }

    // MARK: - resolvedCategoryType

    func test_resolvedCategoryType_withExplicitCategory_usesExplicit() throws {
        let json = """
        {
            "vendor": "Test",
            "totalAmount": "50.00",
            "suggestedCategory": "Entertainment",
            "confidence": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedCategoryType, .entertainment)
    }

    func test_resolvedCategoryType_withNullCategory_fallsToBillType() throws {
        let json = """
        {
            "vendor": "ESB",
            "totalAmount": "80.00",
            "suggestedCategory": null,
            "billType": null,
            "confidence": 0.7
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        // ESB infers to gasElectric -> defaultCategoryType is utilities
        XCTAssertEqual(parsed.resolvedCategoryType, .utilities)
    }
}
