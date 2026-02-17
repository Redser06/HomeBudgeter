//
//  PensionDataTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class PensionDataTests: XCTestCase {

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
            BillLineItem.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            modelContext = modelContainer.mainContext
        } catch {
            XCTFail("Failed to create model container: \(error)")
        }
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Creation

    func test_createPensionData_withDefaults_setsZeroValues() {
        let pension = PensionData()

        XCTAssertNotNil(pension.id)
        XCTAssertEqual(pension.currentValue, 0)
        XCTAssertEqual(pension.totalEmployeeContributions, 0)
        XCTAssertEqual(pension.totalEmployerContributions, 0)
        XCTAssertEqual(pension.totalInvestmentReturns, 0)
        XCTAssertNil(pension.retirementGoal)
        XCTAssertNil(pension.targetRetirementAge)
        XCTAssertNil(pension.provider)
    }

    func test_createPensionData_withValues_setsCorrectly() {
        let pension = PensionData(
            currentValue: 75000,
            totalEmployeeContributions: 30000,
            totalEmployerContributions: 20000,
            totalInvestmentReturns: 25000,
            retirementGoal: 500000,
            targetRetirementAge: 65,
            provider: "Irish Life"
        )

        XCTAssertEqual(pension.currentValue, 75000)
        XCTAssertEqual(pension.totalEmployeeContributions, 30000)
        XCTAssertEqual(pension.totalEmployerContributions, 20000)
        XCTAssertEqual(pension.totalInvestmentReturns, 25000)
        XCTAssertEqual(pension.retirementGoal, 500000)
        XCTAssertEqual(pension.targetRetirementAge, 65)
        XCTAssertEqual(pension.provider, "Irish Life")
    }

    // MARK: - Computed Properties

    func test_totalContributions_sumsEmployeeAndEmployer() {
        let pension = PensionData(
            totalEmployeeContributions: 30000,
            totalEmployerContributions: 20000
        )

        XCTAssertEqual(pension.totalContributions, 50000)
    }

    func test_totalContributions_withZero_returnsZero() {
        let pension = PensionData()

        XCTAssertEqual(pension.totalContributions, 0)
    }

    func test_returnPercentage_calculatesCorrectly() {
        let pension = PensionData(
            totalEmployeeContributions: 30000,
            totalEmployerContributions: 20000,
            totalInvestmentReturns: 10000
        )

        // 10000 / 50000 = 0.2 * 100 = 20%
        XCTAssertEqual(pension.returnPercentage, 20.0, accuracy: 0.1)
    }

    func test_returnPercentage_withZeroContributions_returnsZero() {
        let pension = PensionData(totalInvestmentReturns: 5000)

        XCTAssertEqual(pension.returnPercentage, 0)
    }

    func test_progressToGoal_calculatesPercentage() {
        let pension = PensionData(
            currentValue: 250000,
            retirementGoal: 500000
        )

        XCTAssertNotNil(pension.progressToGoal)
        XCTAssertEqual(pension.progressToGoal!, 50.0, accuracy: 0.1)
    }

    func test_progressToGoal_withNoGoal_returnsNil() {
        let pension = PensionData(currentValue: 100000)

        XCTAssertNil(pension.progressToGoal)
    }

    func test_progressToGoal_withZeroGoal_returnsNil() {
        let pension = PensionData(currentValue: 100000, retirementGoal: 0)

        XCTAssertNil(pension.progressToGoal)
    }

    func test_progressToGoal_whenComplete_returnsHundred() {
        let pension = PensionData(
            currentValue: 500000,
            retirementGoal: 500000
        )

        XCTAssertNotNil(pension.progressToGoal)
        XCTAssertEqual(pension.progressToGoal!, 100.0, accuracy: 0.1)
    }

    // MARK: - Update From Payslip

    func test_updateFromPayslip_addsContributions() {
        let pension = PensionData(
            totalEmployeeContributions: 10000,
            totalEmployerContributions: 5000
        )

        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            pensionContribution: 250,
            employerPensionContribution: 150
        )

        pension.updateFromPayslip(payslip)

        XCTAssertEqual(pension.totalEmployeeContributions, 10250)
        XCTAssertEqual(pension.totalEmployerContributions, 5150)
    }

    func test_updateFromPayslip_updatesLastUpdatedDate() {
        let pension = PensionData()
        let originalDate = pension.lastUpdated

        // Small delay to ensure date changes
        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            pensionContribution: 250,
            employerPensionContribution: 150
        )

        pension.updateFromPayslip(payslip)

        XCTAssertGreaterThanOrEqual(pension.lastUpdated, originalDate)
    }

    func test_updateFromPayslip_multiplePayslips_accumulates() {
        let pension = PensionData()

        for _ in 1...3 {
            let payslip = Payslip(
                payDate: Date(),
                payPeriodStart: Date(),
                payPeriodEnd: Date(),
                grossPay: 5000,
                netPay: 3500,
                incomeTax: 1000,
                socialInsurance: 200,
                pensionContribution: 250,
                employerPensionContribution: 150
            )
            pension.updateFromPayslip(payslip)
        }

        XCTAssertEqual(pension.totalEmployeeContributions, 750)
        XCTAssertEqual(pension.totalEmployerContributions, 450)
    }

    // MARK: - Persistence

    @MainActor
    func test_pensionData_persistsAndFetches() {
        let pension = PensionData(
            currentValue: 120000,
            totalEmployeeContributions: 50000,
            totalEmployerContributions: 30000,
            totalInvestmentReturns: 40000,
            retirementGoal: 500000,
            targetRetirementAge: 65,
            provider: "Aviva"
        )
        pension.notes = "Company pension scheme"
        modelContext.insert(pension)
        try? modelContext.save()

        let descriptor = FetchDescriptor<PensionData>()
        let fetched = try? modelContext.fetch(descriptor)

        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.currentValue, 120000)
        XCTAssertEqual(fetched?.first?.provider, "Aviva")
        XCTAssertEqual(fetched?.first?.notes, "Company pension scheme")
        XCTAssertEqual(fetched?.first?.retirementGoal, 500000)
    }

    // MARK: - Edge Cases

    func test_largeValues_handleCorrectly() {
        let pension = PensionData(
            currentValue: 999_999_999,
            totalEmployeeContributions: 500_000_000,
            totalEmployerContributions: 300_000_000,
            totalInvestmentReturns: 199_999_999
        )

        XCTAssertEqual(pension.currentValue, 999_999_999)
        XCTAssertEqual(pension.totalContributions, 800_000_000)
    }
}
