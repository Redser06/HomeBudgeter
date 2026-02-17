//
//  PayslipParsingService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import PDFKit
import SwiftUI

// MARK: - AIProvider

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case claude = "Claude"
    case gemini = "Gemini"

    var id: String { rawValue }
}

// MARK: - ParsedPayslipData

/// Intermediate struct holding AI-parsed values before user confirmation.
/// All monetary values are String for safe Decimal(string:) conversion.
struct ParsedPayslipData: Codable {
    let payDate: String?
    let payPeriodStart: String?
    let payPeriodEnd: String?
    let grossPay: String?
    let netPay: String?
    let incomeTax: String?
    let socialInsurance: String?
    let universalCharge: String?
    let pensionContribution: String?
    let employerPensionContribution: String?
    let otherDeductions: String?
    let employer: String?
    let confidence: Double?

    static func toDecimal(_ value: String?) -> Decimal {
        guard let v = value else { return 0 }
        return Decimal(string: v) ?? 0
    }

    static func toDate(_ value: String?) -> Date? {
        guard let v = value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: v)
    }
}

// MARK: - ParsingError

enum ParsingError: LocalizedError {
    case noApiKeyConfigured
    case pdfExtractionFailed
    case noTextExtracted
    case apiRequestFailed(String)
    case invalidResponse(String)
    case fileNotFound
    case unsupportedFileType
    case encryptedFileDecryptionFailed

    var errorDescription: String? {
        switch self {
        case .noApiKeyConfigured:
            return "No AI API key is configured. Add one in Settings > AI & Parsing."
        case .pdfExtractionFailed:
            return "Could not extract text from the PDF file."
        case .noTextExtracted:
            return "The PDF appears to contain no readable text."
        case .apiRequestFailed(let detail):
            return "AI request failed: \(detail)"
        case .invalidResponse(let detail):
            return "Could not parse AI response: \(detail)"
        case .fileNotFound:
            return "The document file could not be found on disk."
        case .unsupportedFileType:
            return "Only PDF files can be parsed."
        case .encryptedFileDecryptionFailed:
            return "Could not decrypt the document for parsing."
        }
    }
}

// MARK: - BillType

enum BillType: String, Codable, CaseIterable, Identifiable {
    // Energy
    case gas = "Gas"
    case electric = "Electric"
    case water = "Water"
    // Communications
    case internet = "Internet"
    case tv = "TV"
    case mobile = "Mobile"
    case landline = "Landline"
    // Subscriptions
    case streaming = "Streaming"
    case software = "Software"
    // Insurance
    case healthInsurance = "Health Insurance"
    case homeInsurance = "Home Insurance"
    case carInsurance = "Car Insurance"
    // Other
    case other = "Other"

    var id: String { rawValue }

    // MARK: - Group

    enum Group: String, CaseIterable, Identifiable {
        case energy = "Energy"
        case communications = "Communications"
        case subscriptions = "Subscriptions"
        case insurance = "Insurance"
        case other = "Other"

        var id: String { rawValue }

        var types: [BillType] {
            switch self {
            case .energy: return [.gas, .electric, .water]
            case .communications: return [.internet, .tv, .mobile, .landline]
            case .subscriptions: return [.streaming, .software]
            case .insurance: return [.healthInsurance, .homeInsurance, .carInsurance]
            case .other: return [.other]
            }
        }
    }

    var group: Group {
        switch self {
        case .gas, .electric, .water: return .energy
        case .internet, .tv, .mobile, .landline: return .communications
        case .streaming, .software: return .subscriptions
        case .healthInsurance, .homeInsurance, .carInsurance: return .insurance
        case .other: return .other
        }
    }

    var icon: String {
        switch self {
        case .gas: return "flame.fill"
        case .electric: return "bolt.fill"
        case .water: return "drop.fill"
        case .internet: return "wifi"
        case .tv: return "tv.fill"
        case .mobile: return "iphone"
        case .landline: return "phone.fill"
        case .streaming: return "play.tv.fill"
        case .software: return "app.fill"
        case .healthInsurance: return "heart.fill"
        case .homeInsurance: return "house.fill"
        case .carInsurance: return "car.fill"
        case .other: return "doc.plaintext.fill"
        }
    }

    var color: Color {
        switch self {
        case .gas: return Color(red: 245/255, green: 158/255, blue: 11/255)        // Amber
        case .electric: return Color(red: 234/255, green: 179/255, blue: 8/255)    // Yellow
        case .water: return Color(red: 6/255, green: 182/255, blue: 212/255)       // Teal
        case .internet: return Color(red: 59/255, green: 130/255, blue: 246/255)   // Blue
        case .tv: return Color(red: 99/255, green: 102/255, blue: 241/255)         // Indigo
        case .mobile: return Color(red: 156/255, green: 39/255, blue: 176/255)     // Purple
        case .landline: return Color(red: 124/255, green: 58/255, blue: 237/255)   // Violet
        case .streaming: return Color(red: 236/255, green: 72/255, blue: 153/255)  // Pink
        case .software: return Color(red: 0/255, green: 188/255, blue: 212/255)    // Cyan
        case .healthInsurance: return Color(red: 239/255, green: 68/255, blue: 68/255)  // Red
        case .homeInsurance: return Color(red: 76/255, green: 175/255, blue: 80/255)    // Green
        case .carInsurance: return Color(red: 34/255, green: 197/255, blue: 94/255)     // Emerald
        case .other: return Color(red: 107/255, green: 114/255, blue: 128/255)          // Gray
        }
    }

    var defaultCategoryType: CategoryType {
        switch self {
        case .gas, .electric, .water: return .utilities
        case .internet, .landline: return .utilities
        case .tv: return .entertainment
        case .mobile: return .utilities
        case .streaming: return .entertainment
        case .software: return .other
        case .healthInsurance: return .healthcare
        case .homeInsurance, .carInsurance: return .personal
        case .other: return .other
        }
    }

    // MARK: - Legacy Mappings

    /// Maps old 6-case BillType raw values to new granular types for migration.
    static let legacyMappings: [String: [BillType]] = [
        "Internet & TV": [.internet, .tv],
        "Gas & Electric": [.gas, .electric],
        "Phone": [.mobile],
        "Subscription": [.streaming],
        "Insurance": [.homeInsurance],
    ]

    /// All legacy raw values that should be recognized in notes tags.
    static let legacyRawValues: Set<String> = Set(legacyMappings.keys)

    /// Returns the new BillType(s) for a legacy raw value, or nil if not legacy.
    static func fromLegacy(_ rawValue: String) -> [BillType]? {
        legacyMappings[rawValue]
    }

    // MARK: - Inference

    static func infer(from vendor: String?) -> BillType {
        guard let vendor = vendor?.lowercased() else { return .other }

        // Gas
        let gasKeywords = ["bord gais", "bord gáis", "flogas", "gas networks",
                           "calor gas", "gas"]
        // Electric
        let electricKeywords = ["esb", "electric ireland", "energia",
                                "sse airtricity", "airtricity", "panda power",
                                "prepaypower", "electricity", "electric"]
        // Water
        let waterKeywords = ["irish water", "uisce éireann", "water charges"]
        // Internet
        let internetKeywords = ["virgin media", "eir broadband", "vodafone broadband",
                                "pure telecom", "digiweb", "imagine", "broadband",
                                "fibre", "internet"]
        // TV
        let tvKeywords = ["sky", "now tv", "saorview"]
        // Mobile
        let mobileKeywords = ["vodafone", "three", "eir mobile", "tesco mobile",
                              "48", "gomo", "lycamobile", "an post mobile", "mobile"]
        // Landline
        let landlineKeywords = ["eir", "landline"]
        // Streaming
        let streamingKeywords = ["netflix", "spotify", "disney", "amazon prime",
                                 "apple tv", "youtube premium", "hbo", "paramount",
                                 "dazn", "crunchyroll"]
        // Software
        let softwareKeywords = ["microsoft 365", "adobe", "dropbox", "google workspace",
                                "notion", "github", "1password", "software"]
        // Health Insurance
        let healthInsuranceKeywords = ["laya", "vhi", "irish life health",
                                       "glo health", "health insurance"]
        // Home Insurance
        let homeInsuranceKeywords = ["allianz home", "axa home", "aviva home",
                                     "zurich home", "home insurance"]
        // Car Insurance
        let carInsuranceKeywords = ["allianz car", "axa car", "aviva car",
                                    "zurich car", "car insurance", "motor insurance",
                                    "liberty insurance"]
        // Generic insurance fallback
        let insuranceKeywords = ["allianz", "axa", "aviva", "zurich", "insurance"]

        if electricKeywords.contains(where: { vendor.contains($0) }) { return .electric }
        if gasKeywords.contains(where: { vendor.contains($0) }) { return .gas }
        if waterKeywords.contains(where: { vendor.contains($0) }) { return .water }
        if internetKeywords.contains(where: { vendor.contains($0) }) { return .internet }
        if tvKeywords.contains(where: { vendor.contains($0) }) { return .tv }
        if mobileKeywords.contains(where: { vendor.contains($0) }) { return .mobile }
        if landlineKeywords.contains(where: { vendor.contains($0) }) { return .landline }
        if streamingKeywords.contains(where: { vendor.contains($0) }) { return .streaming }
        if softwareKeywords.contains(where: { vendor.contains($0) }) { return .software }
        if healthInsuranceKeywords.contains(where: { vendor.contains($0) }) { return .healthInsurance }
        if homeInsuranceKeywords.contains(where: { vendor.contains($0) }) { return .homeInsurance }
        if carInsuranceKeywords.contains(where: { vendor.contains($0) }) { return .carInsurance }
        if insuranceKeywords.contains(where: { vendor.contains($0) }) { return .homeInsurance }

        return .other
    }

    /// Infer all applicable bill types for a multi-service vendor (e.g., "Bord Gáis" may be gas + electric).
    static func inferAll(from vendor: String?) -> [BillType] {
        guard let vendor = vendor?.lowercased() else { return [.other] }

        var types: [BillType] = []

        let mappings: [(keywords: [String], type: BillType)] = [
            (["esb", "electric ireland", "energia", "sse airtricity", "airtricity",
              "panda power", "prepaypower", "electricity", "electric"], .electric),
            (["bord gais", "bord gáis", "flogas", "gas networks", "calor gas", "gas"], .gas),
            (["irish water", "uisce éireann", "water charges"], .water),
            (["virgin media", "eir broadband", "vodafone broadband", "pure telecom",
              "digiweb", "imagine", "broadband", "fibre", "internet"], .internet),
            (["sky", "now tv", "saorview"], .tv),
            (["vodafone", "three", "eir mobile", "tesco mobile", "48",
              "gomo", "lycamobile", "an post mobile", "mobile"], .mobile),
            (["eir landline", "landline"], .landline),
            (["netflix", "spotify", "disney", "amazon prime", "apple tv",
              "youtube premium", "hbo", "paramount", "dazn", "crunchyroll"], .streaming),
            (["microsoft 365", "adobe", "dropbox", "google workspace",
              "notion", "github", "1password", "software"], .software),
            (["laya", "vhi", "irish life health", "glo health", "health insurance"], .healthInsurance),
            (["allianz home", "axa home", "aviva home", "zurich home", "home insurance"], .homeInsurance),
            (["allianz car", "axa car", "aviva car", "zurich car",
              "car insurance", "motor insurance", "liberty insurance"], .carInsurance),
        ]

        for (keywords, type) in mappings {
            if keywords.contains(where: { vendor.contains($0) }) {
                types.append(type)
            }
        }

        return types.isEmpty ? [.other] : types
    }
}

// MARK: - ParsedBillLineItem

/// A single line item from AI-parsed bill data.
struct ParsedBillLineItem: Codable {
    let billType: String?
    let amount: String?
    let label: String?
}

// MARK: - ParsedBillData

/// Intermediate struct holding AI-parsed bill values before user confirmation.
/// All monetary values are String for safe Decimal(string:) conversion.
struct ParsedBillData: Codable {
    let vendor: String?
    let billDate: String?
    let dueDate: String?
    let billingPeriodStart: String?
    let billingPeriodEnd: String?
    let totalAmount: String?
    let subtotalAmount: String?
    let taxAmount: String?
    let accountNumber: String?
    let billType: String?
    let suggestedCategory: String?
    let confidence: Double?
    let lineItems: [ParsedBillLineItem]?

    static func toDecimal(_ value: String?) -> Decimal {
        guard let v = value else { return 0 }
        return Decimal(string: v) ?? 0
    }

    static func toDate(_ value: String?) -> Date? {
        guard let v = value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: v)
    }

    var resolvedBillType: BillType {
        if let typeString = billType,
           let type = BillType.allCases.first(where: { $0.rawValue == typeString }) {
            return type
        }
        // Check legacy mappings
        if let typeString = billType,
           let legacyTypes = BillType.fromLegacy(typeString) {
            return legacyTypes.first ?? .other
        }
        return BillType.infer(from: vendor)
    }

    /// Returns all resolved bill types — from line items if present, otherwise single type.
    var resolvedBillTypes: [BillType] {
        if let items = lineItems, !items.isEmpty {
            return items.compactMap { item in
                guard let typeString = item.billType else { return nil }
                return BillType.allCases.first(where: { $0.rawValue == typeString })
                    ?? BillType.fromLegacy(typeString)?.first
            }
        }
        return [resolvedBillType]
    }

    var resolvedCategoryType: CategoryType {
        if let catString = suggestedCategory,
           let cat = CategoryType.allCases.first(where: { $0.rawValue == catString }) {
            return cat
        }
        return resolvedBillType.defaultCategoryType
    }
}

// MARK: - PayslipParsingService

final class PayslipParsingService {
    static let shared = PayslipParsingService()

    private let keychain = KeychainManager.shared
    private let encryption = FileEncryptionService.shared
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - PDF Text Extraction

    func extractText(fromDocumentAt path: String) throws -> String {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ParsingError.fileNotFound
        }

        let pdfData: Data
        if path.hasSuffix(".encrypted") {
            let url = URL(fileURLWithPath: path)
            do {
                let encrypted = try Data(contentsOf: url)
                pdfData = try encryption.decrypt(data: encrypted)
            } catch {
                throw ParsingError.encryptedFileDecryptionFailed
            }
        } else {
            let url = URL(fileURLWithPath: path)
            guard let data = try? Data(contentsOf: url) else {
                throw ParsingError.pdfExtractionFailed
            }
            pdfData = data
        }

        guard let pdfDocument = PDFDocument(data: pdfData) else {
            throw ParsingError.pdfExtractionFailed
        }

        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ParsingError.noTextExtracted
        }

        return trimmed
    }

    // MARK: - Payslip Prompt

    private func buildPayslipPrompt(for extractedText: String) -> String {
        """
        You are a payslip data extraction assistant. Parse the following payslip text \
        and extract the structured financial data.

        This is an Irish payroll system. Use these mappings:
        - "PAYE" or "Income Tax" or "Tax" -> incomeTax
        - "PRSI" or "Employee PRSI" or "Social Insurance" -> socialInsurance
        - "USC" or "Universal Social Charge" -> universalCharge
        - "Pension" or "Employee Pension" or "AVC" -> pensionContribution
        - "Employer Pension" or "ER Pension" -> employerPensionContribution
        - "Gross Pay" or "Gross" or "Total Earnings" -> grossPay
        - "Net Pay" or "Net" or "Take Home" or "Total Net Pay" -> netPay
        - Any other deductions not covered above -> sum into otherDeductions

        For dates, look for:
        - "Pay Date" or "Payment Date" or "Date Paid" -> payDate
        - "Period Start" or "From" or "Period: DD/MM/YYYY to" -> payPeriodStart
        - "Period End" or "To" or "Period: to DD/MM/YYYY" -> payPeriodEnd

        For employer, look for the company name, typically at the top of the payslip.

        All monetary values must be numbers as strings with exactly 2 decimal places \
        (e.g. "4583.33", not "4,583.33"). Remove any currency symbols or thousands separators.

        All dates must be ISO 8601 format: "YYYY-MM-DD".

        If a field cannot be found, use null.

        Provide a confidence score from 0.0 to 1.0 indicating how confident you are \
        in the overall extraction accuracy.

        Respond with ONLY valid JSON, no markdown, no explanation. Use this exact schema:
        {
          "payDate": "YYYY-MM-DD" | null,
          "payPeriodStart": "YYYY-MM-DD" | null,
          "payPeriodEnd": "YYYY-MM-DD" | null,
          "grossPay": "0.00" | null,
          "netPay": "0.00" | null,
          "incomeTax": "0.00" | null,
          "socialInsurance": "0.00" | null,
          "universalCharge": "0.00" | null,
          "pensionContribution": "0.00" | null,
          "employerPensionContribution": "0.00" | null,
          "otherDeductions": "0.00" | null,
          "employer": "string" | null,
          "confidence": 0.0
        }

        --- PAYSLIP TEXT ---
        \(extractedText)
        --- END ---
        """
    }

    // MARK: - Bill Prompt

    private func buildBillPrompt(for extractedText: String) -> String {
        """
        You are a bill and invoice data extraction assistant. Parse the following bill/invoice \
        text and extract the structured financial data.

        This is an Irish billing context. Common providers include:
        - Electricity: ESB, Electric Ireland, Energia, SSE Airtricity, PrePayPower
        - Gas: Bord Gáis Energy, Flogas
        - Water: Irish Water / Uisce Éireann
        - Internet: Virgin Media, Eir, Vodafone, Pure Telecom, Digiweb
        - TV: Sky Ireland, Now TV
        - Mobile: Vodafone, Three, Eir, Tesco Mobile, GoMo, 48
        - Landline: Eir
        - Streaming: Netflix, Spotify, Disney+, Amazon Prime, Apple TV+
        - Software: Microsoft 365, Adobe, Dropbox
        - Health Insurance: Laya, VHI, Irish Life Health
        - Home Insurance: Allianz, AXA, Aviva, Zurich
        - Car Insurance: Allianz, AXA, Aviva, Liberty Insurance

        Look for:
        - Provider/vendor name, typically at the top of the bill -> vendor
        - "Bill Date" or "Invoice Date" or "Date" -> billDate
        - "Due Date" or "Payment Due" or "Pay By" -> dueDate
        - "Billing Period" or "From ... To" -> billingPeriodStart and billingPeriodEnd
        - "Total" or "Amount Due" or "Total Due" or "Balance Due" -> totalAmount
        - "Subtotal" or "Charges before VAT" -> subtotalAmount
        - "VAT" or "Tax" or "VAT @ 23%" or "VAT @ 13.5%" -> taxAmount
        - "Account Number" or "Account No" or "Customer Number" -> accountNumber

        For billType, classify as one of these exact strings:
        - "Gas" — gas supply
        - "Electric" — electricity supply
        - "Water" — water charges
        - "Internet" — broadband, fibre
        - "TV" — TV packages, satellite
        - "Mobile" — mobile phone plans
        - "Landline" — fixed-line phone
        - "Streaming" — Netflix, Spotify, streaming services
        - "Software" — software subscriptions
        - "Health Insurance" — health/medical insurance
        - "Home Insurance" — home/property insurance
        - "Car Insurance" — car/motor insurance
        - "Other" — anything else

        IMPORTANT: If a single bill covers multiple services (e.g. a Bord Gáis bill with \
        both gas and electric charges, or a Virgin Media bill with internet and TV), you MUST \
        populate the "lineItems" array with separate entries for each service. Each line item \
        should have its own billType and amount. The sum of line item amounts should equal totalAmount.

        For suggestedCategory, map to one of these exact strings:
        - "Utilities" — gas, electric, water, broadband, phone
        - "Entertainment" — TV, streaming, subscriptions
        - "Healthcare" — health insurance
        - "Personal" — home insurance, car insurance
        - "Other" — anything else

        All monetary values must be numbers as strings with exactly 2 decimal places \
        (e.g. "123.45", not "€123.45" or "123,45"). Remove any currency symbols or thousands separators.

        All dates must be ISO 8601 format: "YYYY-MM-DD".

        If a field cannot be found, use null.

        Provide a confidence score from 0.0 to 1.0 indicating how confident you are \
        in the overall extraction accuracy.

        Respond with ONLY valid JSON, no markdown, no explanation. Use this exact schema:
        {
          "vendor": "string" | null,
          "billDate": "YYYY-MM-DD" | null,
          "dueDate": "YYYY-MM-DD" | null,
          "billingPeriodStart": "YYYY-MM-DD" | null,
          "billingPeriodEnd": "YYYY-MM-DD" | null,
          "totalAmount": "0.00" | null,
          "subtotalAmount": "0.00" | null,
          "taxAmount": "0.00" | null,
          "accountNumber": "string" | null,
          "billType": "string" | null,
          "suggestedCategory": "string" | null,
          "confidence": 0.0,
          "lineItems": [
            {
              "billType": "string",
              "amount": "0.00",
              "label": "string" | null
            }
          ] | null
        }

        --- BILL TEXT ---
        \(extractedText)
        --- END ---
        """
    }

    // MARK: - Raw API Calls (Shared)

    private func callClaudeRaw(prompt: String) async throws -> String {
        guard let apiKey = keychain.retrieve(key: .claudeApiKey) else {
            throw ParsingError.noApiKeyConfigured
        }

        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParsingError.apiRequestFailed("No HTTP response received")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ParsingError.apiRequestFailed("Claude API returned status \(httpResponse.statusCode): \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String
        else {
            throw ParsingError.invalidResponse("Could not extract text from Claude response")
        }

        return text
    }

    private func callGeminiRaw(prompt: String) async throws -> String {
        guard let apiKey = keychain.retrieve(key: .geminiApiKey) else {
            throw ParsingError.noApiKeyConfigured
        }

        let requestBody: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1,
                "maxOutputTokens": 1024
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParsingError.apiRequestFailed("No HTTP response received")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ParsingError.apiRequestFailed("Gemini API returned status \(httpResponse.statusCode): \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String
        else {
            throw ParsingError.invalidResponse("Could not extract text from Gemini response")
        }

        return text
    }

    // MARK: - Shared JSON Decoding

    private func decodeJSON<T: Decodable>(_ text: String) throws -> T {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw ParsingError.invalidResponse("Response text is not valid UTF-8")
        }

        do {
            return try JSONDecoder().decode(T.self, from: jsonData)
        } catch {
            throw ParsingError.invalidResponse("JSON decode failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Payslip API Calls

    private func callClaudeAPI(extractedText: String) async throws -> ParsedPayslipData {
        let prompt = buildPayslipPrompt(for: extractedText)
        let text = try await callClaudeRaw(prompt: prompt)
        return try decodeJSON(text)
    }

    private func callGeminiAPI(extractedText: String) async throws -> ParsedPayslipData {
        let prompt = buildPayslipPrompt(for: extractedText)
        let text = try await callGeminiRaw(prompt: prompt)
        return try decodeJSON(text)
    }

    // MARK: - Bill API Calls

    private func callClaudeBillAPI(extractedText: String) async throws -> ParsedBillData {
        let prompt = buildBillPrompt(for: extractedText)
        let text = try await callClaudeRaw(prompt: prompt)
        return try decodeJSON(text)
    }

    private func callGeminiBillAPI(extractedText: String) async throws -> ParsedBillData {
        let prompt = buildBillPrompt(for: extractedText)
        let text = try await callGeminiRaw(prompt: prompt)
        return try decodeJSON(text)
    }

    // MARK: - Parse Payslip Document (Public API)

    func parseDocument(_ document: Document) async throws -> ParsedPayslipData {
        guard document.mimeType == "application/pdf" else {
            throw ParsingError.unsupportedFileType
        }

        let extractedText = try extractText(fromDocumentAt: document.localPath)
        return try await callWithFallback(extractedText: extractedText) { text in
            try await self.callClaudeAPI(extractedText: text)
        } geminiCall: { text in
            try await self.callGeminiAPI(extractedText: text)
        }
    }

    // MARK: - Parse Bill Document (Public API)

    func parseBillDocument(_ document: Document) async throws -> ParsedBillData {
        guard document.mimeType == "application/pdf" else {
            throw ParsingError.unsupportedFileType
        }

        let extractedText = try extractText(fromDocumentAt: document.localPath)
        return try await callWithFallback(extractedText: extractedText) { text in
            try await self.callClaudeBillAPI(extractedText: text)
        } geminiCall: { text in
            try await self.callGeminiBillAPI(extractedText: text)
        }
    }

    // MARK: - Provider Fallback Logic (Shared)

    private func callWithFallback<T>(
        extractedText: String,
        claudeCall: @escaping (String) async throws -> T,
        geminiCall: @escaping (String) async throws -> T
    ) async throws -> T {
        let preferred = preferredProvider
        let hasClaude = keychain.retrieve(key: .claudeApiKey) != nil
        let hasGemini = keychain.retrieve(key: .geminiApiKey) != nil

        guard hasClaude || hasGemini else {
            throw ParsingError.noApiKeyConfigured
        }

        var providers: [(AIProvider, () async throws -> T)] = []

        if preferred == .claude && hasClaude {
            providers.append((.claude, { try await claudeCall(extractedText) }))
            if hasGemini {
                providers.append((.gemini, { try await geminiCall(extractedText) }))
            }
        } else if preferred == .gemini && hasGemini {
            providers.append((.gemini, { try await geminiCall(extractedText) }))
            if hasClaude {
                providers.append((.claude, { try await claudeCall(extractedText) }))
            }
        } else if hasClaude {
            providers.append((.claude, { try await claudeCall(extractedText) }))
            if hasGemini {
                providers.append((.gemini, { try await geminiCall(extractedText) }))
            }
        } else {
            providers.append((.gemini, { try await geminiCall(extractedText) }))
        }

        var lastError = ""
        for (provider, call) in providers {
            do {
                return try await call()
            } catch {
                lastError = "\(provider.rawValue): \(error.localizedDescription)"
                continue
            }
        }

        throw ParsingError.apiRequestFailed(lastError)
    }

    // MARK: - Provider Preference

    var preferredProvider: AIProvider {
        if let raw = UserDefaults.standard.string(forKey: "preferredAIProvider"),
           let provider = AIProvider(rawValue: raw) {
            return provider
        }
        return .claude
    }

    // MARK: - Connection Test

    func testConnection(provider: AIProvider) async -> Bool {
        let testText = "Gross Pay: 1000.00\nNet Pay: 800.00\nPAYE: 150.00\nPRSI: 40.00\nUSC: 10.00"
        do {
            switch provider {
            case .claude:
                _ = try await callClaudeAPI(extractedText: testText)
            case .gemini:
                _ = try await callGeminiAPI(extractedText: testText)
            }
            return true
        } catch {
            return false
        }
    }
}
