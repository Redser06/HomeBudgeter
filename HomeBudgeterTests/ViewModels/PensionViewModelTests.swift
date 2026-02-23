//
//  PensionViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class PensionViewModelTests: XCTestCase {

    var sut: PensionViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    @MainActor
    override func setUp() {
        super.setUp()

        let schema = Schema([
            Transaction.self,
            BudgetCategory.self,
            Account.self,
            Document.self,
            SavingsGoal.self,
            Payslip.self,
            PensionData.self,
            RecurringTemplate.self,
            BillLineItem.self,
            HouseholdMember.self,
            Investment.self,
            InvestmentTransaction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }

        sut = PensionViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func test_initialState_hasnilPensionData() {
        XCTAssertNil(sut.pensionData)
    }

    func test_initialState_hasEmptyContributionHistory() {
        XCTAssertTrue(sut.contributionHistory.isEmpty)
    }

    func test_initialState_sheetsAreDismissed() {
        XCTAssertFalse(sut.showingEditSheet)
        XCTAssertFalse(sut.showingSetupSheet)
    }

    // MARK: - Computed Properties with No Data

    func test_currentValue_withNoData_returnsZero() {
        XCTAssertEqual(sut.currentValue, 0)
    }

    func test_totalContributions_withNoData_returnsZero() {
        XCTAssertEqual(sut.totalContributions, 0)
    }

    func test_employeeContributions_withNoData_returnsZero() {
        XCTAssertEqual(sut.employeeContributions, 0)
    }

    func test_employerContributions_withNoData_returnsZero() {
        XCTAssertEqual(sut.employerContributions, 0)
    }

    func test_investmentReturns_withNoData_returnsZero() {
        XCTAssertEqual(sut.investmentReturns, 0)
    }

    func test_progressToGoal_withNoData_returnsNil() {
        XCTAssertNil(sut.progressToGoal)
    }

    func test_returnPercentage_withNoData_returnsZero() {
        XCTAssertEqual(sut.returnPercentage, 0)
    }

    func test_projectionScenarios_withNoData_isEmpty() {
        XCTAssertTrue(sut.projectionScenarios.isEmpty)
    }

    // MARK: - Create Pension Data

    @MainActor
    func test_createPensionData_setsPensionData() {
        sut.createPensionData(
            currentValue: 50000,
            provider: "Irish Life",
            retirementGoal: 500000,
            targetRetirementAge: 65,
            notes: "Company pension",
            modelContext: modelContext
        )

        XCTAssertNotNil(sut.pensionData)
        XCTAssertEqual(sut.pensionData?.currentValue, 50000)
        XCTAssertEqual(sut.pensionData?.provider, "Irish Life")
        XCTAssertEqual(sut.pensionData?.retirementGoal, 500000)
        XCTAssertEqual(sut.pensionData?.targetRetirementAge, 65)
        XCTAssertEqual(sut.pensionData?.notes, "Company pension")
    }

    @MainActor
    func test_createPensionData_loadsAfterCreation() {
        sut.createPensionData(
            currentValue: 75000,
            provider: nil,
            retirementGoal: nil,
            targetRetirementAge: nil,
            notes: nil,
            modelContext: modelContext
        )

        XCTAssertNotNil(sut.pensionData)
        XCTAssertEqual(sut.currentValue, 75000)
    }

    @MainActor
    func test_createPensionData_withOptionalNils_setsCorrectly() {
        sut.createPensionData(
            currentValue: 10000,
            provider: nil,
            retirementGoal: nil,
            targetRetirementAge: nil,
            notes: nil,
            modelContext: modelContext
        )

        XCTAssertNotNil(sut.pensionData)
        XCTAssertNil(sut.pensionData?.provider)
        XCTAssertNil(sut.pensionData?.retirementGoal)
        XCTAssertNil(sut.pensionData?.targetRetirementAge)
        XCTAssertNil(sut.pensionData?.notes)
    }

    @MainActor
    func test_createPensionData_persistsToContext() {
        sut.createPensionData(
            currentValue: 30000,
            provider: "Aviva",
            retirementGoal: 400000,
            targetRetirementAge: 67,
            notes: nil,
            modelContext: modelContext
        )

        let descriptor = FetchDescriptor<PensionData>()
        let fetched = try? modelContext.fetch(descriptor)

        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.currentValue, 30000)
        XCTAssertEqual(fetched?.first?.provider, "Aviva")
    }

    // MARK: - Update Pension Data

    @MainActor
    func test_updatePensionData_savesChanges() {
        // Given
        sut.createPensionData(
            currentValue: 50000,
            provider: "Irish Life",
            retirementGoal: 500000,
            targetRetirementAge: 65,
            notes: "Initial",
            modelContext: modelContext
        )

        // When
        sut.updatePensionData(
            currentValue: 60000,
            investmentReturns: 5000,
            provider: "Zurich",
            retirementGoal: 600000,
            targetRetirementAge: 67,
            notes: "Updated",
            modelContext: modelContext
        )

        // Then
        XCTAssertEqual(sut.pensionData?.currentValue, 60000)
        XCTAssertEqual(sut.pensionData?.totalInvestmentReturns, 5000)
        XCTAssertEqual(sut.pensionData?.provider, "Zurich")
        XCTAssertEqual(sut.pensionData?.retirementGoal, 600000)
        XCTAssertEqual(sut.pensionData?.targetRetirementAge, 67)
        XCTAssertEqual(sut.pensionData?.notes, "Updated")
    }

    @MainActor
    func test_updatePensionData_updatesLastUpdatedDate() {
        // Given
        sut.createPensionData(
            currentValue: 50000,
            provider: nil,
            retirementGoal: nil,
            targetRetirementAge: nil,
            notes: nil,
            modelContext: modelContext
        )
        let originalDate = sut.pensionData?.lastUpdated

        // When
        sut.updatePensionData(
            currentValue: 55000,
            investmentReturns: 2000,
            provider: nil,
            retirementGoal: nil,
            targetRetirementAge: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        XCTAssertNotNil(sut.pensionData?.lastUpdated)
        if let original = originalDate, let updated = sut.pensionData?.lastUpdated {
            XCTAssertGreaterThanOrEqual(updated, original)
        }
    }

    @MainActor
    func test_updatePensionData_withNoExistingData_doesNothing() {
        // When - no pension data exists
        sut.updatePensionData(
            currentValue: 100000,
            investmentReturns: 10000,
            provider: "Test",
            retirementGoal: nil,
            targetRetirementAge: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        XCTAssertNil(sut.pensionData)
    }

    // MARK: - Computed Properties with Data

    @MainActor
    func test_computedProperties_reflectPensionData() {
        // Given
        let pension = PensionData(
            currentValue: 100000,
            totalEmployeeContributions: 40000,
            totalEmployerContributions: 25000,
            totalInvestmentReturns: 35000,
            retirementGoal: 500000,
            targetRetirementAge: 65,
            provider: "Irish Life"
        )
        modelContext.insert(pension)
        try? modelContext.save()

        // When
        sut.loadPensionData(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.currentValue, 100000)
        XCTAssertEqual(sut.totalContributions, 65000)
        XCTAssertEqual(sut.employeeContributions, 40000)
        XCTAssertEqual(sut.employerContributions, 25000)
        XCTAssertEqual(sut.investmentReturns, 35000)
    }

    @MainActor
    func test_progressToGoal_withGoalSet_returnsPercentage() {
        let pension = PensionData(
            currentValue: 250000,
            retirementGoal: 500000
        )
        modelContext.insert(pension)
        try? modelContext.save()

        sut.loadPensionData(modelContext: modelContext)

        XCTAssertNotNil(sut.progressToGoal)
        XCTAssertEqual(sut.progressToGoal!, 50.0, accuracy: 0.1)
    }

    @MainActor
    func test_returnPercentage_withContributions_calculatesCorrectly() {
        let pension = PensionData(
            totalEmployeeContributions: 30000,
            totalEmployerContributions: 20000,
            totalInvestmentReturns: 10000
        )
        modelContext.insert(pension)
        try? modelContext.save()

        sut.loadPensionData(modelContext: modelContext)

        // 10000 / 50000 = 0.2 * 100 = 20%
        XCTAssertEqual(sut.returnPercentage, 20.0, accuracy: 0.1)
    }

    // MARK: - Load Pension Data

    @MainActor
    func test_loadPensionData_fetchesExistingRecord() {
        // Given
        let pension = PensionData(
            currentValue: 80000,
            provider: "Zurich"
        )
        modelContext.insert(pension)
        try? modelContext.save()

        // When
        sut.loadPensionData(modelContext: modelContext)

        // Then
        XCTAssertNotNil(sut.pensionData)
        XCTAssertEqual(sut.pensionData?.currentValue, 80000)
        XCTAssertEqual(sut.pensionData?.provider, "Zurich")
    }

    @MainActor
    func test_loadPensionData_withNoRecords_setsNil() {
        sut.loadPensionData(modelContext: modelContext)

        XCTAssertNil(sut.pensionData)
    }

    // MARK: - Load Contribution History

    @MainActor
    func test_loadContributionHistory_fromPayslips() {
        // Given - create payslips within last 12 months
        let calendar = Calendar.current
        let today = Date()

        for monthOffset in 0..<3 {
            let payDate = calendar.date(byAdding: .month, value: -monthOffset, to: today)!
            let periodStart = calendar.date(byAdding: .day, value: -30, to: payDate)!
            let payslip = Payslip(
                payDate: payDate,
                payPeriodStart: periodStart,
                payPeriodEnd: payDate,
                grossPay: 5000,
                netPay: 3500,
                incomeTax: 1000,
                socialInsurance: 200,
                pensionContribution: 250,
                employerPensionContribution: 150
            )
            modelContext.insert(payslip)
        }
        try? modelContext.save()

        // When
        sut.loadContributionHistory(modelContext: modelContext)

        // Then
        XCTAssertFalse(sut.contributionHistory.isEmpty)
        XCTAssertLessThanOrEqual(sut.contributionHistory.count, 3)

        for data in sut.contributionHistory {
            XCTAssertEqual(data.employeeAmount, 250.0, accuracy: 0.01)
            XCTAssertEqual(data.employerAmount, 150.0, accuracy: 0.01)
            XCTAssertEqual(data.total, 400.0, accuracy: 0.01)
        }
    }

    @MainActor
    func test_loadContributionHistory_excludesOldPayslips() {
        // Given - create a payslip older than 12 months
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .month, value: -14, to: Date())!
        let periodStart = calendar.date(byAdding: .day, value: -30, to: oldDate)!

        let oldPayslip = Payslip(
            payDate: oldDate,
            payPeriodStart: periodStart,
            payPeriodEnd: oldDate,
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            pensionContribution: 500,
            employerPensionContribution: 300
        )
        modelContext.insert(oldPayslip)
        try? modelContext.save()

        // When
        sut.loadContributionHistory(modelContext: modelContext)

        // Then
        XCTAssertTrue(sut.contributionHistory.isEmpty)
    }

    @MainActor
    func test_loadContributionHistory_aggregatesSameMonthPayslips() {
        // Given - two payslips in the same month
        let calendar = Calendar.current
        let today = Date()
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let midMonth = calendar.date(byAdding: .day, value: 15, to: firstDay)!

        let payslip1 = Payslip(
            payDate: firstDay,
            payPeriodStart: firstDay,
            payPeriodEnd: midMonth,
            grossPay: 2500,
            netPay: 1750,
            incomeTax: 500,
            socialInsurance: 100,
            pensionContribution: 125,
            employerPensionContribution: 75
        )
        let payslip2 = Payslip(
            payDate: midMonth,
            payPeriodStart: midMonth,
            payPeriodEnd: calendar.date(byAdding: .month, value: 1, to: firstDay)!,
            grossPay: 2500,
            netPay: 1750,
            incomeTax: 500,
            socialInsurance: 100,
            pensionContribution: 125,
            employerPensionContribution: 75
        )
        modelContext.insert(payslip1)
        modelContext.insert(payslip2)
        try? modelContext.save()

        // When
        sut.loadContributionHistory(modelContext: modelContext)

        // Then - should be aggregated into one month
        XCTAssertEqual(sut.contributionHistory.count, 1)
        XCTAssertEqual(sut.contributionHistory.first?.employeeAmount ?? 0, 250.0, accuracy: 0.01)
        XCTAssertEqual(sut.contributionHistory.first?.employerAmount ?? 0, 150.0, accuracy: 0.01)
    }

    @MainActor
    func test_loadContributionHistory_withNoPayslips_returnsEmpty() {
        sut.loadContributionHistory(modelContext: modelContext)

        XCTAssertTrue(sut.contributionHistory.isEmpty)
    }

    @MainActor
    func test_loadContributionHistory_sortedByDate() {
        // Given - create payslips out of order
        let calendar = Calendar.current
        let today = Date()

        let dates = [
            calendar.date(byAdding: .month, value: -3, to: today)!,
            calendar.date(byAdding: .month, value: -1, to: today)!,
            calendar.date(byAdding: .month, value: -5, to: today)!
        ]

        for date in dates {
            let periodStart = calendar.date(byAdding: .day, value: -30, to: date)!
            let payslip = Payslip(
                payDate: date,
                payPeriodStart: periodStart,
                payPeriodEnd: date,
                grossPay: 5000,
                netPay: 3500,
                incomeTax: 1000,
                socialInsurance: 200,
                pensionContribution: 250,
                employerPensionContribution: 150
            )
            modelContext.insert(payslip)
        }
        try? modelContext.save()

        // When
        sut.loadContributionHistory(modelContext: modelContext)

        // Then - verify sorted ascending by date
        for i in 1..<sut.contributionHistory.count {
            XCTAssertLessThanOrEqual(
                sut.contributionHistory[i - 1].date,
                sut.contributionHistory[i].date
            )
        }
    }

    // MARK: - Projection Engine

    func test_projection_zeroGrowth_linearAccumulationOnly() {
        let projections = PensionViewModel.generateProjection(
            currentValue: 10000,
            monthlyContribution: 500,
            annualGrowthRate: 0,
            currentAge: 30,
            retirementAge: 35
        )

        XCTAssertEqual(projections.count, 5)
        // With 0% growth: 5 years * 12 months * 500 = 30000 contributions + 10000 start
        let finalValue = projections.last!.endValue
        XCTAssertEqual(finalValue, 40000, accuracy: 0.01)
        // All growth should be zero
        for projection in projections {
            XCTAssertEqual(projection.growth, 0, accuracy: 0.01)
        }
    }

    func test_projection_growthNoContributions_compoundFormulaMatches() {
        let projections = PensionViewModel.generateProjection(
            currentValue: 10000,
            monthlyContribution: 0,
            annualGrowthRate: 12,
            currentAge: 30,
            retirementAge: 31
        )

        XCTAssertEqual(projections.count, 1)
        // Monthly rate = 1%, compounded 12 times: 10000 * (1.01)^12 = ~11268.25
        let expected = 10000.0 * Foundation.pow(1.01, 12.0)
        XCTAssertEqual(projections.last!.endValue, expected, accuracy: 0.01)
        // No contributions
        XCTAssertEqual(projections.last!.contributions, 0, accuracy: 0.01)
    }

    func test_projection_growthPlusContributions_exceedsLinearSum() {
        let projections = PensionViewModel.generateProjection(
            currentValue: 10000,
            monthlyContribution: 500,
            annualGrowthRate: 5,
            currentAge: 30,
            retirementAge: 40
        )

        let finalValue = projections.last!.endValue
        // Linear sum would be: 10000 + (500 * 120) = 70000
        XCTAssertGreaterThan(finalValue, 70000)
    }

    func test_projection_retirementAgeLessThanCurrentAge_emptyResult() {
        let projections = PensionViewModel.generateProjection(
            currentValue: 10000,
            monthlyContribution: 500,
            annualGrowthRate: 5,
            currentAge: 65,
            retirementAge: 60
        )

        XCTAssertTrue(projections.isEmpty)
    }

    func test_projection_yearCountMatchesYearsToRetirement() {
        let projections = PensionViewModel.generateProjection(
            currentValue: 10000,
            monthlyContribution: 100,
            annualGrowthRate: 5,
            currentAge: 30,
            retirementAge: 67
        )

        XCTAssertEqual(projections.count, 37)
    }

    func test_calculateProjections_correctNumberOfScenarios() {
        sut.selectedScenarioBands = [.conservative, .moderate, .aggressive]
        sut.projectionCurrentAge = 30
        sut.projectionRetirementAge = 65
        sut.calculateProjections()

        XCTAssertEqual(sut.projectionScenarios.count, 3)
        // Verify they are in rate order
        XCTAssertEqual(sut.projectionScenarios[0].annualGrowthRate, 3.0, accuracy: 0.01)
        XCTAssertEqual(sut.projectionScenarios[1].annualGrowthRate, 5.0, accuracy: 0.01)
        XCTAssertEqual(sut.projectionScenarios[2].annualGrowthRate, 7.0, accuracy: 0.01)
    }

    func test_calculateProjections_customRateUsedCorrectly() {
        sut.selectedScenarioBands = [.custom]
        sut.projectionCustomGrowthRate = 8.5
        sut.projectionCurrentAge = 30
        sut.projectionRetirementAge = 65
        sut.calculateProjections()

        XCTAssertEqual(sut.projectionScenarios.count, 1)
        XCTAssertEqual(sut.projectionScenarios.first!.annualGrowthRate, 8.5, accuracy: 0.01)
    }

    func test_calculateProjections_additionalContributionIncreasesProjection() {
        sut.selectedScenarioBands = [.moderate]
        sut.projectionCurrentAge = 30
        sut.projectionRetirementAge = 65

        // Without additional contribution
        sut.projectionAdditionalContribution = 0
        sut.calculateProjections()
        let baseValue = sut.projectionScenarios.first?.finalValue ?? 0

        // With additional contribution
        sut.projectionAdditionalContribution = 200
        sut.calculateProjections()
        let boostedValue = sut.projectionScenarios.first?.finalValue ?? 0

        XCTAssertGreaterThan(boostedValue, baseValue)
    }

    // MARK: - PensionContributionData

    func test_pensionContributionData_totalIsSumOfAmounts() {
        let data = PensionContributionData(
            date: Date(),
            employeeAmount: 250.0,
            employerAmount: 150.0
        )

        XCTAssertEqual(data.total, 400.0, accuracy: 0.01)
    }

    func test_pensionContributionData_hasUniqueId() {
        let data1 = PensionContributionData(date: Date(), employeeAmount: 100, employerAmount: 50)
        let data2 = PensionContributionData(date: Date(), employeeAmount: 100, employerAmount: 50)

        XCTAssertNotEqual(data1.id, data2.id)
    }

    func test_pensionContributionData_zeroAmounts() {
        let data = PensionContributionData(date: Date(), employeeAmount: 0, employerAmount: 0)

        XCTAssertEqual(data.total, 0)
    }

    // MARK: - Full Workflow

    @MainActor
    func test_fullWorkflow_createLoadUpdateLoad() {
        // Create
        sut.createPensionData(
            currentValue: 50000,
            provider: "Irish Life",
            retirementGoal: 500000,
            targetRetirementAge: 65,
            notes: "Initial setup",
            modelContext: modelContext
        )
        XCTAssertEqual(sut.currentValue, 50000)
        XCTAssertEqual(sut.pensionData?.provider, "Irish Life")

        // Create fresh ViewModel and load
        let sut2 = PensionViewModel()
        sut2.loadPensionData(modelContext: modelContext)
        XCTAssertEqual(sut2.currentValue, 50000)

        // Update
        sut2.updatePensionData(
            currentValue: 60000,
            investmentReturns: 8000,
            provider: "Zurich",
            retirementGoal: 600000,
            targetRetirementAge: 67,
            notes: "Switched provider",
            modelContext: modelContext
        )
        XCTAssertEqual(sut2.currentValue, 60000)
        XCTAssertEqual(sut2.investmentReturns, 8000)
        XCTAssertEqual(sut2.pensionData?.provider, "Zurich")

        // Reload from original
        sut.loadPensionData(modelContext: modelContext)
        XCTAssertEqual(sut.currentValue, 60000)
    }
}
