//
//  PayslipTests.swift
//  HomeBudgeterTests
//
//  Created by QA Agent
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class PayslipTests: XCTestCase {

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
            InvestmentTransaction.self,
            SyncQueueEntry.self
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

    // MARK: - Helpers

    private func makePayslip(
        grossPay: Decimal = 5000,
        netPay: Decimal = 3500,
        incomeTax: Decimal = 1000,
        socialInsurance: Decimal = 200,
        universalCharge: Decimal? = 150,
        pensionContribution: Decimal = 250,
        employerPensionContribution: Decimal = 150,
        otherDeductions: Decimal = 50,
        employer: String? = "Acme Corp"
    ) -> Payslip {
        Payslip(
            payDate: Date(),
            payPeriodStart: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            payPeriodEnd: Date(),
            grossPay: grossPay,
            netPay: netPay,
            incomeTax: incomeTax,
            socialInsurance: socialInsurance,
            universalCharge: universalCharge,
            pensionContribution: pensionContribution,
            employerPensionContribution: employerPensionContribution,
            otherDeductions: otherDeductions,
            employer: employer
        )
    }

    // MARK: - Creation

    func test_createPayslip_setsAllFields() {
        let payslip = makePayslip()

        XCTAssertNotNil(payslip.id)
        XCTAssertEqual(payslip.grossPay, 5000)
        XCTAssertEqual(payslip.netPay, 3500)
        XCTAssertEqual(payslip.incomeTax, 1000)
        XCTAssertEqual(payslip.socialInsurance, 200)
        XCTAssertEqual(payslip.universalCharge, 150)
        XCTAssertEqual(payslip.pensionContribution, 250)
        XCTAssertEqual(payslip.employerPensionContribution, 150)
        XCTAssertEqual(payslip.otherDeductions, 50)
        XCTAssertEqual(payslip.employer, "Acme Corp")
        XCTAssertNotNil(payslip.createdAt)
    }

    func test_createPayslip_withDefaults_setsZeroPension() {
        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: 4000,
            netPay: 3000,
            incomeTax: 800,
            socialInsurance: 200
        )

        XCTAssertEqual(payslip.pensionContribution, 0)
        XCTAssertEqual(payslip.employerPensionContribution, 0)
        XCTAssertEqual(payslip.otherDeductions, 0)
        XCTAssertNil(payslip.universalCharge)
        XCTAssertNil(payslip.employer)
    }

    // MARK: - Computed Properties

    func test_totalDeductions_sumsAllDeductions() {
        let payslip = makePayslip()

        // incomeTax(1000) + socialInsurance(200) + universalCharge(150) + pensionContribution(250) + otherDeductions(50) = 1650
        XCTAssertEqual(payslip.totalDeductions, 1650)
    }

    func test_totalDeductions_withNilUniversalCharge_excludesIt() {
        let payslip = makePayslip(universalCharge: nil)

        // incomeTax(1000) + socialInsurance(200) + 0 + pensionContribution(250) + otherDeductions(50) = 1500
        XCTAssertEqual(payslip.totalDeductions, 1500)
    }

    func test_totalPensionContribution_sumsBothContributions() {
        let payslip = makePayslip(pensionContribution: 250, employerPensionContribution: 150)

        XCTAssertEqual(payslip.totalPensionContribution, 400)
    }

    func test_totalPensionContribution_withZero_returnsZero() {
        let payslip = makePayslip(pensionContribution: 0, employerPensionContribution: 0)

        XCTAssertEqual(payslip.totalPensionContribution, 0)
    }

    func test_formattedPayDate_returnsNonEmptyString() {
        let payslip = makePayslip()

        XCTAssertFalse(payslip.formattedPayDate.isEmpty)
    }

    func test_payPeriodDescription_containsDash() {
        let payslip = makePayslip()

        XCTAssertTrue(payslip.payPeriodDescription.contains(" - "))
    }

    // MARK: - Persistence

    @MainActor
    func test_payslip_persistsAndFetches() {
        let payslip = makePayslip()
        payslip.notes = "January salary"
        modelContext.insert(payslip)
        try? modelContext.save()

        let descriptor = FetchDescriptor<Payslip>()
        let fetched = try? modelContext.fetch(descriptor)

        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.grossPay, 5000)
        XCTAssertEqual(fetched?.first?.employer, "Acme Corp")
        XCTAssertEqual(fetched?.first?.notes, "January salary")
    }

    @MainActor
    func test_multiplePayslips_allPersist() {
        for i in 1...3 {
            let payslip = makePayslip(grossPay: Decimal(i * 1000))
            modelContext.insert(payslip)
        }
        try? modelContext.save()

        let descriptor = FetchDescriptor<Payslip>()
        let fetched = try? modelContext.fetch(descriptor)

        XCTAssertEqual(fetched?.count, 3)
    }

    // MARK: - Edge Cases

    func test_payslip_withLargeValues_handlesCorrectly() {
        let payslip = makePayslip(grossPay: 999_999.99, netPay: 700_000)

        XCTAssertEqual(payslip.grossPay, Decimal(string: "999999.99"))
    }

    func test_payslip_withZeroValues_isValid() {
        let payslip = Payslip(
            payDate: Date(),
            payPeriodStart: Date(),
            payPeriodEnd: Date(),
            grossPay: 0,
            netPay: 0,
            incomeTax: 0,
            socialInsurance: 0
        )

        XCTAssertEqual(payslip.grossPay, 0)
        XCTAssertEqual(payslip.totalDeductions, 0)
        XCTAssertEqual(payslip.totalPensionContribution, 0)
    }
}
