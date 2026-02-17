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
            "billType": "Internet",
            "suggestedCategory": "Utilities",
            "confidence": 0.92,
            "lineItems": null
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
            "confidence": 0.65,
            "lineItems": null
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

    func test_parsedBillData_decodesLineItems() throws {
        let json = """
        {
            "vendor": "Bord Gáis Energy",
            "totalAmount": "180.00",
            "billType": "Gas",
            "confidence": 0.9,
            "lineItems": [
                { "billType": "Gas", "amount": "100.00", "label": "Gas Supply" },
                { "billType": "Electric", "amount": "80.00", "label": "Electricity" }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)

        XCTAssertNotNil(parsed.lineItems)
        XCTAssertEqual(parsed.lineItems?.count, 2)
        XCTAssertEqual(parsed.lineItems?[0].billType, "Gas")
        XCTAssertEqual(parsed.lineItems?[0].amount, "100.00")
        XCTAssertEqual(parsed.lineItems?[0].label, "Gas Supply")
        XCTAssertEqual(parsed.lineItems?[1].billType, "Electric")
        XCTAssertEqual(parsed.lineItems?[1].amount, "80.00")
    }

    // MARK: - BillType (13 cases)

    func test_billType_allCases() {
        let cases = BillType.allCases
        XCTAssertEqual(cases.count, 13)
        XCTAssertTrue(cases.contains(.gas))
        XCTAssertTrue(cases.contains(.electric))
        XCTAssertTrue(cases.contains(.water))
        XCTAssertTrue(cases.contains(.internet))
        XCTAssertTrue(cases.contains(.tv))
        XCTAssertTrue(cases.contains(.mobile))
        XCTAssertTrue(cases.contains(.landline))
        XCTAssertTrue(cases.contains(.streaming))
        XCTAssertTrue(cases.contains(.software))
        XCTAssertTrue(cases.contains(.healthInsurance))
        XCTAssertTrue(cases.contains(.homeInsurance))
        XCTAssertTrue(cases.contains(.carInsurance))
        XCTAssertTrue(cases.contains(.other))
    }

    func test_billType_groups() {
        XCTAssertEqual(BillType.Group.allCases.count, 5)
        XCTAssertEqual(BillType.gas.group, .energy)
        XCTAssertEqual(BillType.electric.group, .energy)
        XCTAssertEqual(BillType.water.group, .energy)
        XCTAssertEqual(BillType.internet.group, .communications)
        XCTAssertEqual(BillType.tv.group, .communications)
        XCTAssertEqual(BillType.mobile.group, .communications)
        XCTAssertEqual(BillType.landline.group, .communications)
        XCTAssertEqual(BillType.streaming.group, .subscriptions)
        XCTAssertEqual(BillType.software.group, .subscriptions)
        XCTAssertEqual(BillType.healthInsurance.group, .insurance)
        XCTAssertEqual(BillType.homeInsurance.group, .insurance)
        XCTAssertEqual(BillType.carInsurance.group, .insurance)
        XCTAssertEqual(BillType.other.group, .other)
    }

    func test_billType_defaultCategoryType() {
        XCTAssertEqual(BillType.gas.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.electric.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.water.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.internet.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.tv.defaultCategoryType, .entertainment)
        XCTAssertEqual(BillType.mobile.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.landline.defaultCategoryType, .utilities)
        XCTAssertEqual(BillType.streaming.defaultCategoryType, .entertainment)
        XCTAssertEqual(BillType.software.defaultCategoryType, .other)
        XCTAssertEqual(BillType.healthInsurance.defaultCategoryType, .healthcare)
        XCTAssertEqual(BillType.homeInsurance.defaultCategoryType, .personal)
        XCTAssertEqual(BillType.carInsurance.defaultCategoryType, .personal)
        XCTAssertEqual(BillType.other.defaultCategoryType, .other)
    }

    // MARK: - BillType.infer(from:)

    func test_infer_esb_returnsElectric() {
        XCTAssertEqual(BillType.infer(from: "ESB Networks"), .electric)
    }

    func test_infer_electricIreland_returnsElectric() {
        XCTAssertEqual(BillType.infer(from: "Electric Ireland"), .electric)
    }

    func test_infer_bordGais_returnsGas() {
        XCTAssertEqual(BillType.infer(from: "Bord Gáis Energy"), .gas)
    }

    func test_infer_flogas_returnsGas() {
        XCTAssertEqual(BillType.infer(from: "Flogas Natural Gas"), .gas)
    }

    func test_infer_irishWater_returnsWater() {
        XCTAssertEqual(BillType.infer(from: "Irish Water"), .water)
    }

    func test_infer_virginMedia_returnsInternet() {
        XCTAssertEqual(BillType.infer(from: "Virgin Media Ireland"), .internet)
    }

    func test_infer_sky_returnsTV() {
        XCTAssertEqual(BillType.infer(from: "Sky Ireland"), .tv)
    }

    func test_infer_vodafone_returnsMobile() {
        XCTAssertEqual(BillType.infer(from: "Vodafone Ireland"), .mobile)
    }

    func test_infer_three_returnsMobile() {
        XCTAssertEqual(BillType.infer(from: "Three Ireland"), .mobile)
    }

    func test_infer_netflix_returnsStreaming() {
        XCTAssertEqual(BillType.infer(from: "Netflix"), .streaming)
    }

    func test_infer_spotify_returnsStreaming() {
        XCTAssertEqual(BillType.infer(from: "Spotify Premium"), .streaming)
    }

    func test_infer_microsoft365_returnsSoftware() {
        XCTAssertEqual(BillType.infer(from: "Microsoft 365"), .software)
    }

    func test_infer_laya_returnsHealthInsurance() {
        XCTAssertEqual(BillType.infer(from: "Laya Healthcare"), .healthInsurance)
    }

    func test_infer_vhi_returnsHealthInsurance() {
        XCTAssertEqual(BillType.infer(from: "VHI Healthcare"), .healthInsurance)
    }

    func test_infer_allianz_returnsHomeInsurance() {
        // Generic "allianz" maps to homeInsurance as default insurance
        XCTAssertEqual(BillType.infer(from: "Allianz Insurance"), .homeInsurance)
    }

    func test_infer_unknown_returnsOther() {
        XCTAssertEqual(BillType.infer(from: "Some Random Company"), .other)
    }

    func test_infer_nil_returnsOther() {
        XCTAssertEqual(BillType.infer(from: nil), .other)
    }

    // MARK: - BillType.inferAll(from:)

    func test_inferAll_multiService_returnsMultipleTypes() {
        // "Bord Gáis" should match gas
        let types = BillType.inferAll(from: "Bord Gáis Energy")
        XCTAssertTrue(types.contains(.gas))
    }

    func test_inferAll_unknown_returnsOther() {
        let types = BillType.inferAll(from: "Some Company")
        XCTAssertEqual(types, [.other])
    }

    func test_inferAll_nil_returnsOther() {
        let types = BillType.inferAll(from: nil)
        XCTAssertEqual(types, [.other])
    }

    // MARK: - Legacy Mappings

    func test_legacyMappings_gasElectric() {
        let mapped = BillType.fromLegacy("Gas & Electric")
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped, [.gas, .electric])
    }

    func test_legacyMappings_internetTv() {
        let mapped = BillType.fromLegacy("Internet & TV")
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped, [.internet, .tv])
    }

    func test_legacyMappings_phone() {
        let mapped = BillType.fromLegacy("Phone")
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped, [.mobile])
    }

    func test_legacyMappings_subscription() {
        let mapped = BillType.fromLegacy("Subscription")
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped, [.streaming])
    }

    func test_legacyMappings_insurance() {
        let mapped = BillType.fromLegacy("Insurance")
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped, [.homeInsurance])
    }

    func test_legacyMappings_unknown_returnsNil() {
        XCTAssertNil(BillType.fromLegacy("Gas"))
    }

    // MARK: - resolvedBillType

    func test_resolvedBillType_withNewType_usesExplicit() throws {
        let json = """
        {
            "vendor": "Some Company",
            "totalAmount": "50.00",
            "billType": "Mobile",
            "confidence": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedBillType, .mobile)
    }

    func test_resolvedBillType_withLegacyType_mapsToNew() throws {
        let json = """
        {
            "vendor": "Some Company",
            "totalAmount": "50.00",
            "billType": "Gas & Electric",
            "confidence": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        // Legacy "Gas & Electric" maps to [.gas, .electric], resolvedBillType returns first
        XCTAssertEqual(parsed.resolvedBillType, .gas)
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
        XCTAssertEqual(parsed.resolvedBillType, .streaming)
    }

    // MARK: - resolvedBillTypes (plural)

    func test_resolvedBillTypes_withLineItems_returnsAll() throws {
        let json = """
        {
            "vendor": "Bord Gáis",
            "totalAmount": "200.00",
            "billType": "Gas",
            "confidence": 0.9,
            "lineItems": [
                { "billType": "Gas", "amount": "120.00", "label": null },
                { "billType": "Electric", "amount": "80.00", "label": null }
            ]
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedBillTypes, [.gas, .electric])
    }

    func test_resolvedBillTypes_withoutLineItems_returnsSingleType() throws {
        let json = """
        {
            "vendor": "ESB",
            "totalAmount": "80.00",
            "billType": "Electric",
            "confidence": 0.9
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedBillData.self, from: data)
        XCTAssertEqual(parsed.resolvedBillTypes, [.electric])
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
        // ESB infers to electric -> defaultCategoryType is utilities
        XCTAssertEqual(parsed.resolvedCategoryType, .utilities)
    }
}
