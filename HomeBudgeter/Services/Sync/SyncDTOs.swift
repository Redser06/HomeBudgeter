import Foundation

// MARK: - ISO8601 Date Coding Strategy

extension JSONDecoder {
    static let supabase: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter.supabase.date(from: string) {
                return date
            }
            if let date = ISO8601DateFormatter.supabaseFractional.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }()
}

extension JSONEncoder {
    static let supabase: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.supabase.string(from: date))
        }
        return encoder
    }()
}

extension ISO8601DateFormatter {
    static let supabase: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static let supabaseFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Decimal String Coding

struct DecimalString: Codable, Sendable {
    let value: Decimal

    init(_ value: Decimal) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleVal = try? container.decode(Double.self) {
            value = Decimal(string: "\(doubleVal)") ?? Decimal(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            guard let decimal = Decimal(string: stringVal) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid decimal: \(stringVal)")
            }
            value = decimal
        } else {
            throw DecodingError.typeMismatch(Decimal.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected number or string"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(value)")
    }
}

// MARK: - DTOs

struct HouseholdMemberDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let name: String
    let colorHex: String
    let icon: String
    let isDefault: Bool
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, name, icon
        case userId = "user_id"
        case colorHex = "color_hex"
        case isDefault = "is_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AccountDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let ownerId: UUID?
    let name: String
    let type: String
    let balance: DecimalString
    let currencyCode: String
    let isActive: Bool
    let institution: String?
    let accountNumber: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, name, type, balance, institution, notes
        case userId = "user_id"
        case ownerId = "owner_id"
        case currencyCode = "currency_code"
        case isActive = "is_active"
        case accountNumber = "account_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BudgetCategoryDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let type: String
    let budgetAmount: DecimalString
    let spentAmount: DecimalString
    let period: String
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, type, period
        case userId = "user_id"
        case budgetAmount = "budget_amount"
        case spentAmount = "spent_amount"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RecurringTemplateDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let accountId: UUID?
    let categoryId: UUID?
    let name: String
    let amount: DecimalString
    let type: String
    let frequency: String
    let startDate: Date
    let endDate: Date?
    let nextDueDate: Date
    let lastProcessedDate: Date?
    let isActive: Bool
    let notes: String?
    let isVariableAmount: Bool
    let isAutoPay: Bool
    let priceHistoryData: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, name, amount, type, frequency, notes
        case userId = "user_id"
        case accountId = "account_id"
        case categoryId = "category_id"
        case startDate = "start_date"
        case endDate = "end_date"
        case nextDueDate = "next_due_date"
        case lastProcessedDate = "last_processed_date"
        case isActive = "is_active"
        case isVariableAmount = "is_variable_amount"
        case isAutoPay = "is_auto_pay"
        case priceHistoryData = "price_history_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TransactionDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let accountId: UUID?
    let categoryId: UUID?
    let templateId: UUID?
    let amount: DecimalString
    let date: Date
    let descriptionText: String
    let type: String
    let isRecurring: Bool
    let recurringFrequency: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, amount, date, type, notes
        case userId = "user_id"
        case accountId = "account_id"
        case categoryId = "category_id"
        case templateId = "template_id"
        case descriptionText = "description_text"
        case isRecurring = "is_recurring"
        case recurringFrequency = "recurring_frequency"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct BillLineItemDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let transactionId: UUID?
    let billType: String
    let amount: DecimalString
    let label: String?
    let provider: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, amount, label, provider
        case userId = "user_id"
        case transactionId = "transaction_id"
        case billType = "bill_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SavingsGoalDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let memberId: UUID?
    let name: String
    let targetAmount: DecimalString
    let currentAmount: DecimalString
    let deadline: Date?
    let priority: String
    let icon: String
    let notes: String?
    let isCompleted: Bool
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, name, deadline, priority, icon, notes
        case userId = "user_id"
        case memberId = "member_id"
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PayslipDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let memberId: UUID?
    let payDate: Date
    let payPeriodStart: Date
    let payPeriodEnd: Date
    let grossPay: DecimalString
    let netPay: DecimalString
    let incomeTax: DecimalString
    let socialInsurance: DecimalString
    let universalCharge: DecimalString?
    let pensionContribution: DecimalString
    let employerPensionContribution: DecimalString
    let otherDeductions: DecimalString
    let healthInsurancePremium: DecimalString
    let employer: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, employer, notes
        case userId = "user_id"
        case memberId = "member_id"
        case payDate = "pay_date"
        case payPeriodStart = "pay_period_start"
        case payPeriodEnd = "pay_period_end"
        case grossPay = "gross_pay"
        case netPay = "net_pay"
        case incomeTax = "income_tax"
        case socialInsurance = "social_insurance"
        case universalCharge = "universal_charge"
        case pensionContribution = "pension_contribution"
        case employerPensionContribution = "employer_pension_contribution"
        case otherDeductions = "other_deductions"
        case healthInsurancePremium = "health_insurance_premium"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PensionDataDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let memberId: UUID?
    let currentValue: DecimalString
    let totalEmployeeContributions: DecimalString
    let totalEmployerContributions: DecimalString
    let totalInvestmentReturns: DecimalString
    let retirementGoal: DecimalString?
    let targetRetirementAge: Int?
    let lastUpdated: Date
    let provider: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, provider, notes
        case userId = "user_id"
        case memberId = "member_id"
        case currentValue = "current_value"
        case totalEmployeeContributions = "total_employee_contributions"
        case totalEmployerContributions = "total_employer_contributions"
        case totalInvestmentReturns = "total_investment_returns"
        case retirementGoal = "retirement_goal"
        case targetRetirementAge = "target_retirement_age"
        case lastUpdated = "last_updated"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct DocumentDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let transactionId: UUID?
    let payslipId: UUID?
    let pensionId: UUID?
    let filename: String
    let storagePath: String
    let uploadDate: Date
    let documentType: String
    let fileSize: Int64
    let mimeType: String
    let isProcessed: Bool
    let extractedData: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, filename, notes
        case userId = "user_id"
        case transactionId = "transaction_id"
        case payslipId = "payslip_id"
        case pensionId = "pension_id"
        case storagePath = "storage_path"
        case uploadDate = "upload_date"
        case documentType = "document_type"
        case fileSize = "file_size"
        case mimeType = "mime_type"
        case isProcessed = "is_processed"
        case extractedData = "extracted_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InvestmentDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let ownerId: UUID?
    let accountId: UUID?
    let symbol: String
    let name: String
    let assetType: String
    let currencyCode: String
    let notes: String?
    let priceHistoryData: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, notes
        case userId = "user_id"
        case ownerId = "owner_id"
        case accountId = "account_id"
        case assetType = "asset_type"
        case currencyCode = "currency_code"
        case priceHistoryData = "price_history_data"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct InvestmentTransactionDTO: SyncDTO {
    let id: UUID
    let userId: UUID
    let investmentId: UUID?
    let transactionType: String
    let quantity: DecimalString
    let pricePerUnit: DecimalString
    let fees: DecimalString
    let date: Date
    let notes: String?
    let createdAt: Date
    let updatedAt: Date

    var syncId: UUID { id }
    var syncUpdatedAt: Date { updatedAt }

    enum CodingKeys: String, CodingKey {
        case id, quantity, date, notes, fees
        case userId = "user_id"
        case investmentId = "investment_id"
        case transactionType = "transaction_type"
        case pricePerUnit = "price_per_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
