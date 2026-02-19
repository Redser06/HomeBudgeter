//
//  TaxIntelligenceServiceTests.swift
//  HomeBudgeterTests
//

import XCTest
@testable import Home_Budgeter

final class TaxIntelligenceServiceTests: XCTestCase {

    let sut = TaxIntelligenceService.shared

    // MARK: - stripMarkdownCodeFences

    func test_stripMarkdownCodeFences_removesJsonFence() {
        let input = """
        ```json
        {"summary": "Test", "insights": []}
        ```
        """
        let result = sut.stripMarkdownCodeFences(input)
        XCTAssertEqual(result, #"{"summary": "Test", "insights": []}"#)
    }

    func test_stripMarkdownCodeFences_removesPlainFence() {
        let input = """
        ```
        {"summary": "Test"}
        ```
        """
        let result = sut.stripMarkdownCodeFences(input)
        XCTAssertEqual(result, #"{"summary": "Test"}"#)
    }

    func test_stripMarkdownCodeFences_passesPlainJSONThrough() {
        let input = #"{"summary": "Test", "insights": []}"#
        let result = sut.stripMarkdownCodeFences(input)
        XCTAssertEqual(result, input)
    }

    func test_stripMarkdownCodeFences_handlesWhitespace() {
        let input = "  \n```json\n{\"key\": \"value\"}\n```\n  "
        let result = sut.stripMarkdownCodeFences(input)
        XCTAssertEqual(result, #"{"key": "value"}"#)
    }

    // MARK: - parseAIResponse

    func test_parseAIResponse_validJSON_extractsSummary() {
        let json = """
        {"summary": "Your tax situation looks good.", "insights": []}
        """
        let result = sut.parseAIResponse(json)
        XCTAssertEqual(result.summary, "Your tax situation looks good.")
        XCTAssertTrue(result.insights.isEmpty)
    }

    func test_parseAIResponse_fencedJSON_extractsSummary() {
        let json = """
        ```json
        {"summary": "Fenced summary.", "insights": []}
        ```
        """
        let result = sut.parseAIResponse(json)
        XCTAssertEqual(result.summary, "Fenced summary.")
    }

    func test_parseAIResponse_withInsights_parsesAll() {
        let json = """
        {
          "summary": "Overview",
          "insights": [
            {
              "title": "Increase Pension",
              "description": "You should contribute more",
              "estimated_annual_saving": 1200.00,
              "category": "pension",
              "priority": "high"
            },
            {
              "title": "Tax Credits",
              "description": "Check your credits",
              "estimated_annual_saving": null,
              "category": "credits",
              "priority": "medium"
            }
          ]
        }
        """
        let result = sut.parseAIResponse(json)
        XCTAssertEqual(result.summary, "Overview")
        XCTAssertEqual(result.insights.count, 2)
        XCTAssertEqual(result.insights[0].title, "Increase Pension")
        XCTAssertEqual(result.insights[0].estimatedSaving, Decimal(string: "1200"))
        XCTAssertEqual(result.insights[0].category, .pension)
        XCTAssertEqual(result.insights[0].priority, .high)
        XCTAssertEqual(result.insights[1].title, "Tax Credits")
        XCTAssertNil(result.insights[1].estimatedSaving)
        XCTAssertEqual(result.insights[1].category, .credits)
        XCTAssertEqual(result.insights[1].priority, .medium)
    }

    func test_parseAIResponse_invalidJSON_doesNotShowRawJSON() {
        let malformed = #"{"summary": "broken json"#  // Missing closing brace
        let result = sut.parseAIResponse(malformed)
        // Should get a generic fallback, not the raw JSON
        XCTAssertEqual(result.summary, "AI analysis completed. See insights below for details.")
        XCTAssertTrue(result.insights.isEmpty)
    }

    func test_parseAIResponse_plainText_showsAsIs() {
        let text = "The API returned a plain text response with no JSON."
        let result = sut.parseAIResponse(text)
        XCTAssertEqual(result.summary, text)
        XCTAssertTrue(result.insights.isEmpty)
    }

    func test_parseAIResponse_fencedInvalidJSON_doesNotShowRaw() {
        let input = """
        ```json
        {"summary": "test", invalid json here
        ```
        """
        let result = sut.parseAIResponse(input)
        XCTAssertEqual(result.summary, "AI analysis completed. See insights below for details.")
    }

    func test_parseAIResponse_insightCategories_allParsed() {
        let json = """
        {
          "summary": "Test",
          "insights": [
            {"title": "A", "description": "a", "category": "pension", "priority": "high"},
            {"title": "B", "description": "b", "category": "credits", "priority": "medium"},
            {"title": "C", "description": "c", "category": "reliefs", "priority": "low"},
            {"title": "D", "description": "d", "category": "efficiency", "priority": "medium"}
          ]
        }
        """
        let result = sut.parseAIResponse(json)
        XCTAssertEqual(result.insights.count, 4)
        XCTAssertEqual(result.insights[0].category, .pension)
        XCTAssertEqual(result.insights[1].category, .credits)
        XCTAssertEqual(result.insights[2].category, .reliefs)
        XCTAssertEqual(result.insights[3].category, .efficiency)
        XCTAssertEqual(result.insights[2].priority, .low)
    }

    // MARK: - Year Formatting

    func test_yearAsString_doesNotContainComma() {
        let year = 2026
        let formatted = String(year)
        XCTAssertFalse(formatted.contains(","), "Year \(formatted) should not contain locale formatting")
        XCTAssertEqual(formatted, "2026")
    }

    func test_yearInterpolation_doesNotContainComma() {
        let year = 2026
        let text = "No Payslips for \(String(year))"
        XCTAssertTrue(text.hasSuffix("2026"), "Year should render as 2026, got: \(text)")
        XCTAssertFalse(text.contains("2,026"))
    }

    // MARK: - Marginal Rate

    func test_marginalRate_ireland_highIncome() {
        let rate = sut.estimatedMarginalRate(grossAnnual: Decimal(string: "60000")!, locale: .ireland)
        XCTAssertEqual(rate, 52.0)
    }

    func test_marginalRate_ireland_lowIncome() {
        let rate = sut.estimatedMarginalRate(grossAnnual: Decimal(string: "35000")!, locale: .ireland)
        XCTAssertEqual(rate, 28.5)
    }
}
