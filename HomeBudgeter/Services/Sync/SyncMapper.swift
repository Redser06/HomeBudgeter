import Foundation
import SwiftData

@MainActor
struct SyncMapper {

    // MARK: - HouseholdMember

    static func toDTO(_ model: HouseholdMember, userId: UUID) -> HouseholdMemberDTO {
        HouseholdMemberDTO(
            id: model.id, userId: userId, name: model.name,
            colorHex: model.colorHex, icon: model.icon,
            isDefault: model.isDefault,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: HouseholdMemberDTO, to model: HouseholdMember) {
        model.name = dto.name
        model.colorHex = dto.colorHex
        model.icon = dto.icon
        model.isDefault = dto.isDefault
        model.updatedAt = dto.updatedAt
    }

    static func createFromDTO(_ dto: HouseholdMemberDTO, context: ModelContext) -> HouseholdMember {
        let m = HouseholdMember(name: dto.name, colorHex: dto.colorHex, icon: dto.icon, isDefault: dto.isDefault)
        m.id = dto.id
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        context.insert(m)
        return m
    }

    // MARK: - Account

    static func toDTO(_ model: Account, userId: UUID) -> AccountDTO {
        AccountDTO(
            id: model.id, userId: userId, ownerId: model.owner?.id,
            name: model.name, type: model.type.rawValue,
            balance: DecimalString(model.balance),
            currencyCode: model.currencyCode, isActive: model.isActive,
            institution: model.institution, accountNumber: model.accountNumber,
            notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: AccountDTO, to model: Account, context: ModelContext) {
        model.name = dto.name
        model.type = AccountType(rawValue: dto.type) ?? .other
        model.balance = dto.balance.value
        model.currencyCode = dto.currencyCode
        model.isActive = dto.isActive
        model.institution = dto.institution
        model.accountNumber = dto.accountNumber
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
        if let ownerId = dto.ownerId {
            model.owner = fetchModel(HouseholdMember.self, id: ownerId, context: context)
        }
    }

    static func createFromDTO(_ dto: AccountDTO, context: ModelContext) -> Account {
        let m = Account(name: dto.name, type: AccountType(rawValue: dto.type) ?? .other,
                        balance: dto.balance.value, currencyCode: dto.currencyCode,
                        isActive: dto.isActive, institution: dto.institution,
                        accountNumber: dto.accountNumber, notes: dto.notes)
        m.id = dto.id
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let ownerId = dto.ownerId {
            m.owner = fetchModel(HouseholdMember.self, id: ownerId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - BudgetCategory

    static func toDTO(_ model: BudgetCategory, userId: UUID) -> BudgetCategoryDTO {
        BudgetCategoryDTO(
            id: model.id, userId: userId, type: model.type.rawValue,
            budgetAmount: DecimalString(model.budgetAmount),
            spentAmount: DecimalString(model.spentAmount),
            period: model.period.rawValue, isActive: model.isActive,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: BudgetCategoryDTO, to model: BudgetCategory) {
        model.type = CategoryType(rawValue: dto.type) ?? .other
        model.budgetAmount = dto.budgetAmount.value
        model.spentAmount = dto.spentAmount.value
        model.period = BudgetPeriod(rawValue: dto.period) ?? .monthly
        model.isActive = dto.isActive
        model.updatedAt = dto.updatedAt
    }

    static func createFromDTO(_ dto: BudgetCategoryDTO, context: ModelContext) -> BudgetCategory {
        let m = BudgetCategory(type: CategoryType(rawValue: dto.type) ?? .other,
                               budgetAmount: dto.budgetAmount.value,
                               spentAmount: dto.spentAmount.value,
                               period: BudgetPeriod(rawValue: dto.period) ?? .monthly,
                               isActive: dto.isActive)
        m.id = dto.id
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        context.insert(m)
        return m
    }

    // MARK: - RecurringTemplate

    static func toDTO(_ model: RecurringTemplate, userId: UUID) -> RecurringTemplateDTO {
        var priceHistoryJSON: String? = nil
        if let data = model.priceHistoryData, let str = String(data: data, encoding: .utf8) {
            priceHistoryJSON = str
        }
        return RecurringTemplateDTO(
            id: model.id, userId: userId, accountId: model.account?.id,
            categoryId: model.category?.id, name: model.name,
            amount: DecimalString(model.amount), type: model.type.rawValue,
            frequency: model.frequency.rawValue, startDate: model.startDate,
            endDate: model.endDate, nextDueDate: model.nextDueDate,
            lastProcessedDate: model.lastProcessedDate, isActive: model.isActive,
            notes: model.notes, isVariableAmount: model.isVariableAmount,
            isAutoPay: model.isAutoPay, priceHistoryData: priceHistoryJSON,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: RecurringTemplateDTO, to model: RecurringTemplate, context: ModelContext) {
        model.name = dto.name
        model.amount = dto.amount.value
        model.type = TransactionType(rawValue: dto.type) ?? .expense
        model.frequency = RecurringFrequency(rawValue: dto.frequency) ?? .monthly
        model.startDate = dto.startDate
        model.endDate = dto.endDate
        model.nextDueDate = dto.nextDueDate
        model.lastProcessedDate = dto.lastProcessedDate
        model.isActive = dto.isActive
        model.notes = dto.notes
        model.isVariableAmount = dto.isVariableAmount
        model.isAutoPay = dto.isAutoPay
        model.priceHistoryData = dto.priceHistoryData?.data(using: .utf8)
        model.updatedAt = dto.updatedAt
        if let accountId = dto.accountId {
            model.account = fetchModel(Account.self, id: accountId, context: context)
        }
        if let categoryId = dto.categoryId {
            model.category = fetchModel(BudgetCategory.self, id: categoryId, context: context)
        }
    }

    static func createFromDTO(_ dto: RecurringTemplateDTO, context: ModelContext) -> RecurringTemplate {
        let m = RecurringTemplate(name: dto.name, amount: dto.amount.value,
                                  type: TransactionType(rawValue: dto.type) ?? .expense,
                                  frequency: RecurringFrequency(rawValue: dto.frequency) ?? .monthly,
                                  startDate: dto.startDate, endDate: dto.endDate,
                                  nextDueDate: dto.nextDueDate, isActive: dto.isActive,
                                  isVariableAmount: dto.isVariableAmount, isAutoPay: dto.isAutoPay,
                                  notes: dto.notes)
        m.id = dto.id
        m.lastProcessedDate = dto.lastProcessedDate
        m.priceHistoryData = dto.priceHistoryData?.data(using: .utf8)
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let accountId = dto.accountId {
            m.account = fetchModel(Account.self, id: accountId, context: context)
        }
        if let categoryId = dto.categoryId {
            m.category = fetchModel(BudgetCategory.self, id: categoryId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - Transaction

    static func toDTO(_ model: Transaction, userId: UUID) -> TransactionDTO {
        TransactionDTO(
            id: model.id, userId: userId, accountId: model.account?.id,
            categoryId: model.category?.id, templateId: model.parentTemplate?.id,
            amount: DecimalString(model.amount), date: model.date,
            descriptionText: model.descriptionText, type: model.type.rawValue,
            isRecurring: model.isRecurring,
            recurringFrequency: model.recurringFrequency?.rawValue,
            notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: TransactionDTO, to model: Transaction, context: ModelContext) {
        model.amount = dto.amount.value
        model.date = dto.date
        model.descriptionText = dto.descriptionText
        model.type = TransactionType(rawValue: dto.type) ?? .expense
        model.isRecurring = dto.isRecurring
        model.recurringFrequency = dto.recurringFrequency.flatMap { RecurringFrequency(rawValue: $0) }
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
        if let accountId = dto.accountId {
            model.account = fetchModel(Account.self, id: accountId, context: context)
        }
        if let categoryId = dto.categoryId {
            model.category = fetchModel(BudgetCategory.self, id: categoryId, context: context)
        }
        if let templateId = dto.templateId {
            model.parentTemplate = fetchModel(RecurringTemplate.self, id: templateId, context: context)
        }
    }

    static func createFromDTO(_ dto: TransactionDTO, context: ModelContext) -> Transaction {
        let m = Transaction(amount: dto.amount.value, date: dto.date,
                            descriptionText: dto.descriptionText,
                            type: TransactionType(rawValue: dto.type) ?? .expense,
                            isRecurring: dto.isRecurring,
                            recurringFrequency: dto.recurringFrequency.flatMap { RecurringFrequency(rawValue: $0) },
                            notes: dto.notes)
        m.id = dto.id
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let accountId = dto.accountId {
            m.account = fetchModel(Account.self, id: accountId, context: context)
        }
        if let categoryId = dto.categoryId {
            m.category = fetchModel(BudgetCategory.self, id: categoryId, context: context)
        }
        if let templateId = dto.templateId {
            m.parentTemplate = fetchModel(RecurringTemplate.self, id: templateId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - BillLineItem

    static func toDTO(_ model: BillLineItem, userId: UUID) -> BillLineItemDTO {
        BillLineItemDTO(
            id: model.id, userId: userId, transactionId: model.transaction?.id,
            billType: model.billType.rawValue, amount: DecimalString(model.amount),
            label: model.label, provider: model.provider,
            createdAt: Date(), updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: BillLineItemDTO, to model: BillLineItem, context: ModelContext) {
        model.billType = BillType(rawValue: dto.billType) ?? .other
        model.amount = dto.amount.value
        model.label = dto.label
        model.provider = dto.provider
        model.updatedAt = dto.updatedAt
        if let txId = dto.transactionId {
            model.transaction = fetchModel(Transaction.self, id: txId, context: context)
        }
    }

    static func createFromDTO(_ dto: BillLineItemDTO, context: ModelContext) -> BillLineItem {
        let m = BillLineItem(billType: BillType(rawValue: dto.billType) ?? .other,
                             amount: dto.amount.value, label: dto.label, provider: dto.provider)
        m.id = dto.id
        m.updatedAt = dto.updatedAt
        if let txId = dto.transactionId {
            m.transaction = fetchModel(Transaction.self, id: txId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - SavingsGoal

    static func toDTO(_ model: SavingsGoal, userId: UUID) -> SavingsGoalDTO {
        SavingsGoalDTO(
            id: model.id, userId: userId, memberId: model.member?.id,
            name: model.name, targetAmount: DecimalString(model.targetAmount),
            currentAmount: DecimalString(model.currentAmount),
            deadline: model.deadline, priority: model.priority.rawValue,
            icon: model.icon, notes: model.notes, isCompleted: model.isCompleted,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: SavingsGoalDTO, to model: SavingsGoal, context: ModelContext) {
        model.name = dto.name
        model.targetAmount = dto.targetAmount.value
        model.currentAmount = dto.currentAmount.value
        model.deadline = dto.deadline
        model.priority = GoalPriority(rawValue: dto.priority) ?? .medium
        model.icon = dto.icon
        model.notes = dto.notes
        model.isCompleted = dto.isCompleted
        model.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            model.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
    }

    static func createFromDTO(_ dto: SavingsGoalDTO, context: ModelContext) -> SavingsGoal {
        let m = SavingsGoal(name: dto.name, targetAmount: dto.targetAmount.value,
                            currentAmount: dto.currentAmount.value, deadline: dto.deadline,
                            priority: GoalPriority(rawValue: dto.priority) ?? .medium,
                            icon: dto.icon, notes: dto.notes)
        m.id = dto.id
        m.isCompleted = dto.isCompleted
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            m.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - Payslip

    static func toDTO(_ model: Payslip, userId: UUID) -> PayslipDTO {
        PayslipDTO(
            id: model.id, userId: userId, memberId: model.member?.id,
            payDate: model.payDate, payPeriodStart: model.payPeriodStart,
            payPeriodEnd: model.payPeriodEnd,
            grossPay: DecimalString(model.grossPay), netPay: DecimalString(model.netPay),
            incomeTax: DecimalString(model.incomeTax),
            socialInsurance: DecimalString(model.socialInsurance),
            universalCharge: model.universalCharge.map { DecimalString($0) },
            pensionContribution: DecimalString(model.pensionContribution),
            employerPensionContribution: DecimalString(model.employerPensionContribution),
            otherDeductions: DecimalString(model.otherDeductions),
            healthInsurancePremium: DecimalString(model.healthInsurancePremium),
            employer: model.employer, notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: PayslipDTO, to model: Payslip, context: ModelContext) {
        model.payDate = dto.payDate
        model.payPeriodStart = dto.payPeriodStart
        model.payPeriodEnd = dto.payPeriodEnd
        model.grossPay = dto.grossPay.value
        model.netPay = dto.netPay.value
        model.incomeTax = dto.incomeTax.value
        model.socialInsurance = dto.socialInsurance.value
        model.universalCharge = dto.universalCharge?.value
        model.pensionContribution = dto.pensionContribution.value
        model.employerPensionContribution = dto.employerPensionContribution.value
        model.otherDeductions = dto.otherDeductions.value
        model.healthInsurancePremium = dto.healthInsurancePremium.value
        model.employer = dto.employer
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            model.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
    }

    static func createFromDTO(_ dto: PayslipDTO, context: ModelContext) -> Payslip {
        let m = Payslip(payDate: dto.payDate, payPeriodStart: dto.payPeriodStart,
                        payPeriodEnd: dto.payPeriodEnd, grossPay: dto.grossPay.value,
                        netPay: dto.netPay.value, incomeTax: dto.incomeTax.value,
                        socialInsurance: dto.socialInsurance.value,
                        universalCharge: dto.universalCharge?.value,
                        pensionContribution: dto.pensionContribution.value,
                        employerPensionContribution: dto.employerPensionContribution.value,
                        otherDeductions: dto.otherDeductions.value,
                        healthInsurancePremium: dto.healthInsurancePremium.value,
                        employer: dto.employer)
        m.id = dto.id
        m.notes = dto.notes
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            m.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - PensionData

    static func toDTO(_ model: PensionData, userId: UUID) -> PensionDataDTO {
        PensionDataDTO(
            id: model.id, userId: userId, memberId: model.member?.id,
            currentValue: DecimalString(model.currentValue),
            totalEmployeeContributions: DecimalString(model.totalEmployeeContributions),
            totalEmployerContributions: DecimalString(model.totalEmployerContributions),
            totalInvestmentReturns: DecimalString(model.totalInvestmentReturns),
            retirementGoal: model.retirementGoal.map { DecimalString($0) },
            targetRetirementAge: model.targetRetirementAge,
            lastUpdated: model.lastUpdated, provider: model.provider, notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: PensionDataDTO, to model: PensionData, context: ModelContext) {
        model.currentValue = dto.currentValue.value
        model.totalEmployeeContributions = dto.totalEmployeeContributions.value
        model.totalEmployerContributions = dto.totalEmployerContributions.value
        model.totalInvestmentReturns = dto.totalInvestmentReturns.value
        model.retirementGoal = dto.retirementGoal?.value
        model.targetRetirementAge = dto.targetRetirementAge
        model.lastUpdated = dto.lastUpdated
        model.provider = dto.provider
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            model.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
    }

    static func createFromDTO(_ dto: PensionDataDTO, context: ModelContext) -> PensionData {
        let m = PensionData(currentValue: dto.currentValue.value,
                            totalEmployeeContributions: dto.totalEmployeeContributions.value,
                            totalEmployerContributions: dto.totalEmployerContributions.value,
                            totalInvestmentReturns: dto.totalInvestmentReturns.value,
                            retirementGoal: dto.retirementGoal?.value,
                            targetRetirementAge: dto.targetRetirementAge,
                            provider: dto.provider)
        m.id = dto.id
        m.notes = dto.notes
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let memberId = dto.memberId {
            m.member = fetchModel(HouseholdMember.self, id: memberId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - Document

    static func toDTO(_ model: Document, userId: UUID) -> DocumentDTO {
        DocumentDTO(
            id: model.id, userId: userId,
            transactionId: model.linkedTransaction?.id,
            payslipId: model.linkedPayslip?.id,
            pensionId: model.linkedPension?.id,
            filename: model.filename, storagePath: model.localPath,
            uploadDate: model.uploadDate, documentType: model.documentType.rawValue,
            fileSize: model.fileSize, mimeType: model.mimeType,
            isProcessed: model.isProcessed, extractedData: model.extractedData,
            notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: DocumentDTO, to model: Document, context: ModelContext) {
        model.filename = dto.filename
        model.localPath = dto.storagePath
        model.uploadDate = dto.uploadDate
        model.documentType = DocumentType(rawValue: dto.documentType) ?? .other
        model.fileSize = dto.fileSize
        model.mimeType = dto.mimeType
        model.isProcessed = dto.isProcessed
        model.extractedData = dto.extractedData
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
    }

    static func createFromDTO(_ dto: DocumentDTO, context: ModelContext) -> Document {
        let m = Document(filename: dto.filename, localPath: dto.storagePath,
                         documentType: DocumentType(rawValue: dto.documentType) ?? .other,
                         fileSize: dto.fileSize, mimeType: dto.mimeType)
        m.id = dto.id
        m.uploadDate = dto.uploadDate
        m.isProcessed = dto.isProcessed
        m.extractedData = dto.extractedData
        m.notes = dto.notes
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        context.insert(m)
        return m
    }

    // MARK: - Investment

    static func toDTO(_ model: Investment, userId: UUID) -> InvestmentDTO {
        var priceJSON: String? = nil
        if let data = model.priceHistoryData, let str = String(data: data, encoding: .utf8) {
            priceJSON = str
        }
        return InvestmentDTO(
            id: model.id, userId: userId, ownerId: model.owner?.id,
            accountId: model.account?.id, symbol: model.symbol, name: model.name,
            assetType: model.assetType.rawValue, currencyCode: model.currencyCode,
            notes: model.notes, priceHistoryData: priceJSON,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: InvestmentDTO, to model: Investment, context: ModelContext) {
        model.symbol = dto.symbol
        model.name = dto.name
        model.assetType = AssetType(rawValue: dto.assetType) ?? .stock
        model.currencyCode = dto.currencyCode
        model.notes = dto.notes
        model.priceHistoryData = dto.priceHistoryData?.data(using: .utf8)
        model.updatedAt = dto.updatedAt
        if let ownerId = dto.ownerId {
            model.owner = fetchModel(HouseholdMember.self, id: ownerId, context: context)
        }
        if let accountId = dto.accountId {
            model.account = fetchModel(Account.self, id: accountId, context: context)
        }
    }

    static func createFromDTO(_ dto: InvestmentDTO, context: ModelContext) -> Investment {
        let m = Investment(symbol: dto.symbol, name: dto.name,
                           assetType: AssetType(rawValue: dto.assetType) ?? .stock,
                           currencyCode: dto.currencyCode, notes: dto.notes)
        m.id = dto.id
        m.priceHistoryData = dto.priceHistoryData?.data(using: .utf8)
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let ownerId = dto.ownerId {
            m.owner = fetchModel(HouseholdMember.self, id: ownerId, context: context)
        }
        if let accountId = dto.accountId {
            m.account = fetchModel(Account.self, id: accountId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - InvestmentTransaction

    static func toDTO(_ model: InvestmentTransaction, userId: UUID) -> InvestmentTransactionDTO {
        InvestmentTransactionDTO(
            id: model.id, userId: userId, investmentId: model.investment?.id,
            transactionType: model.transactionType.rawValue,
            quantity: DecimalString(model.quantity),
            pricePerUnit: DecimalString(model.pricePerUnit),
            fees: DecimalString(model.fees), date: model.date, notes: model.notes,
            createdAt: model.createdAt, updatedAt: model.updatedAt
        )
    }

    static func applyDTO(_ dto: InvestmentTransactionDTO, to model: InvestmentTransaction, context: ModelContext) {
        model.transactionType = InvestmentTransactionType(rawValue: dto.transactionType) ?? .buy
        model.quantity = dto.quantity.value
        model.pricePerUnit = dto.pricePerUnit.value
        model.fees = dto.fees.value
        model.date = dto.date
        model.notes = dto.notes
        model.updatedAt = dto.updatedAt
        if let investmentId = dto.investmentId {
            model.investment = fetchModel(Investment.self, id: investmentId, context: context)
        }
    }

    static func createFromDTO(_ dto: InvestmentTransactionDTO, context: ModelContext) -> InvestmentTransaction {
        let m = InvestmentTransaction(transactionType: InvestmentTransactionType(rawValue: dto.transactionType) ?? .buy,
                                      quantity: dto.quantity.value, pricePerUnit: dto.pricePerUnit.value,
                                      fees: dto.fees.value, date: dto.date, notes: dto.notes)
        m.id = dto.id
        m.createdAt = dto.createdAt
        m.updatedAt = dto.updatedAt
        if let investmentId = dto.investmentId {
            m.investment = fetchModel(Investment.self, id: investmentId, context: context)
        }
        context.insert(m)
        return m
    }

    // MARK: - Helper

    private static func fetchModel<T: PersistentModel>(_ type: T.Type, id: UUID, context: ModelContext) -> T? {
        let descriptor = FetchDescriptor<T>(predicate: #Predicate { _ in true })
        guard let results = try? context.fetch(descriptor) else { return nil }
        return results.first { model in
            (model as? any Identifiable)?.id as? UUID == id
        }
    }
}
