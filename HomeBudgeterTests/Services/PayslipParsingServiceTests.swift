//
//  PayslipParsingServiceTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
@testable import Home_Budgeter

final class PayslipParsingServiceTests: XCTestCase {

    var sut: PayslipParsingService!

    override func setUp() {
        super.setUp()
        sut = PayslipParsingService.shared
    }

    // MARK: - ParsedPayslipData.toDecimal

    func test_toDecimal_withValidString_returnsCorrectDecimal() {
        let result = ParsedPayslipData.toDecimal("4583.33")
        XCTAssertEqual(result, Decimal(string: "4583.33"))
    }

    func test_toDecimal_withNil_returnsZero() {
        let result = ParsedPayslipData.toDecimal(nil)
        XCTAssertEqual(result, 0)
    }

    func test_toDecimal_withInvalidString_returnsZero() {
        let result = ParsedPayslipData.toDecimal("not a number")
        XCTAssertEqual(result, 0)
    }

    func test_toDecimal_withEmptyString_returnsZero() {
        let result = ParsedPayslipData.toDecimal("")
        XCTAssertEqual(result, 0)
    }

    func test_toDecimal_withWholeNumber_returnsDecimal() {
        let result = ParsedPayslipData.toDecimal("1000")
        XCTAssertEqual(result, Decimal(string: "1000"))
    }

    // MARK: - ParsedPayslipData.toDate

    func test_toDate_withValidISO8601_returnsDate() {
        let result = ParsedPayslipData.toDate("2025-01-31")
        XCTAssertNotNil(result)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: result!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 31)
    }

    func test_toDate_withNil_returnsNil() {
        XCTAssertNil(ParsedPayslipData.toDate(nil))
    }

    func test_toDate_withInvalidString_returnsNil() {
        XCTAssertNil(ParsedPayslipData.toDate("not-a-date"))
    }

    func test_toDate_withEmptyString_returnsNil() {
        XCTAssertNil(ParsedPayslipData.toDate(""))
    }

    // MARK: - JSON Decoding

    func test_parsedPayslipData_decodesAllFields() throws {
        let json = """
        {
            "payDate": "2025-01-31",
            "payPeriodStart": "2025-01-01",
            "payPeriodEnd": "2025-01-31",
            "grossPay": "4583.33",
            "netPay": "3215.67",
            "incomeTax": "916.67",
            "socialInsurance": "183.33",
            "universalCharge": "137.50",
            "pensionContribution": "100.00",
            "employerPensionContribution": "50.00",
            "otherDeductions": "0.00",
            "employer": "Acme Ltd",
            "confidence": 0.95
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedPayslipData.self, from: data)

        XCTAssertEqual(parsed.grossPay, "4583.33")
        XCTAssertEqual(parsed.netPay, "3215.67")
        XCTAssertEqual(parsed.employer, "Acme Ltd")
        XCTAssertEqual(parsed.confidence, 0.95)
        XCTAssertEqual(ParsedPayslipData.toDecimal(parsed.grossPay), Decimal(string: "4583.33"))
        XCTAssertEqual(ParsedPayslipData.toDecimal(parsed.incomeTax), Decimal(string: "916.67"))
    }

    func test_parsedPayslipData_decodesWithNullFields() throws {
        let json = """
        {
            "payDate": null,
            "payPeriodStart": null,
            "payPeriodEnd": null,
            "grossPay": "1000.00",
            "netPay": "800.00",
            "incomeTax": "150.00",
            "socialInsurance": "40.00",
            "universalCharge": null,
            "pensionContribution": null,
            "employerPensionContribution": null,
            "otherDeductions": null,
            "employer": null,
            "confidence": 0.6
        }
        """
        let data = json.data(using: .utf8)!
        let parsed = try JSONDecoder().decode(ParsedPayslipData.self, from: data)

        XCTAssertNil(parsed.universalCharge)
        XCTAssertNil(parsed.employer)
        XCTAssertNil(parsed.payDate)
        XCTAssertEqual(parsed.grossPay, "1000.00")
        XCTAssertEqual(ParsedPayslipData.toDecimal(parsed.pensionContribution), 0)
    }

    // MARK: - PDF Extraction Error Cases

    func test_extractText_withNonexistentFile_throwsFileNotFound() {
        XCTAssertThrowsError(try sut.extractText(fromDocumentAt: "/nonexistent/file.pdf")) { error in
            guard let parsingError = error as? ParsingError else {
                XCTFail("Expected ParsingError, got \(type(of: error))")
                return
            }
            if case .fileNotFound = parsingError {
                // Expected
            } else {
                XCTFail("Expected .fileNotFound, got \(parsingError)")
            }
        }
    }

    // MARK: - AIProvider

    func test_aiProvider_allCases() {
        let cases = AIProvider.allCases
        XCTAssertEqual(cases.count, 2)
        XCTAssertTrue(cases.contains(.claude))
        XCTAssertTrue(cases.contains(.gemini))
    }

    func test_aiProvider_rawValues() {
        XCTAssertEqual(AIProvider.claude.rawValue, "Claude")
        XCTAssertEqual(AIProvider.gemini.rawValue, "Gemini")
    }

    // MARK: - Provider Preference

    func test_preferredProvider_defaultsToClaude() {
        UserDefaults.standard.removeObject(forKey: "preferredAIProvider")
        XCTAssertEqual(sut.preferredProvider, .claude)
    }

    func test_preferredProvider_readsFromUserDefaults() {
        UserDefaults.standard.set("Gemini", forKey: "preferredAIProvider")
        XCTAssertEqual(sut.preferredProvider, .gemini)
        // Clean up
        UserDefaults.standard.removeObject(forKey: "preferredAIProvider")
    }
}
