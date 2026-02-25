//
//  PayslipViewModelTests.swift
//  HomeBudgeterTests
//
//  Created by Home Budgeter Team
//

import XCTest
import SwiftData
@testable import Home_Budgeter

final class PayslipViewModelTests: XCTestCase {

    var sut: PayslipViewModel!
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

        sut = PayslipViewModel()
    }

    override func tearDown() {
        sut = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    // MARK: - Helper

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)!
    }

    // MARK: - Initial State

    func test_initialState_hasEmptyPayslips() {
        XCTAssertTrue(sut.payslips.isEmpty)
        XCTAssertFalse(sut.showingCreateSheet)
        XCTAssertNil(sut.selectedPayslip)
    }

    func test_initialState_filterYearIsCurrentYear() {
        let currentYear = Calendar.current.component(.year, from: Date())
        XCTAssertEqual(sut.filterYear, currentYear)
    }

    func test_initialState_filterEmployerIsNil() {
        XCTAssertNil(sut.filterEmployer)
    }

    // MARK: - Computed Properties With No Data

    func test_totalGrossYTD_withNoPayslips_returnsZero() {
        XCTAssertEqual(sut.totalGrossYTD, 0)
    }

    func test_totalNetYTD_withNoPayslips_returnsZero() {
        XCTAssertEqual(sut.totalNetYTD, 0)
    }

    func test_totalTaxYTD_withNoPayslips_returnsZero() {
        XCTAssertEqual(sut.totalTaxYTD, 0)
    }

    func test_averageNetPay_withNoPayslips_returnsZero() {
        XCTAssertEqual(sut.averageNetPay, 0)
    }

    func test_filteredPayslips_withNoPayslips_returnsEmpty() {
        XCTAssertTrue(sut.filteredPayslips.isEmpty)
    }

    // MARK: - Create Payslip

    @MainActor
    func test_createPayslip_addsToList() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let payDate = makeDate(year: currentYear, month: 6, day: 25)
        let periodStart = makeDate(year: currentYear, month: 6, day: 1)
        let periodEnd = makeDate(year: currentYear, month: 6, day: 30)

        // When
        sut.createPayslip(
            payDate: payDate,
            payPeriodStart: periodStart,
            payPeriodEnd: periodEnd,
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: 150,
            pensionContribution: 100,
            employerPensionContribution: 50,
            otherDeductions: 0,
            employer: "Acme Corp",
            notes: "June payslip",
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.payslips.count, 1)

        let payslip = sut.payslips.first!
        XCTAssertEqual(payslip.grossPay, 5000)
        XCTAssertEqual(payslip.netPay, 3500)
        XCTAssertEqual(payslip.incomeTax, 1000)
        XCTAssertEqual(payslip.socialInsurance, 200)
        XCTAssertEqual(payslip.universalCharge, 150)
        XCTAssertEqual(payslip.pensionContribution, 100)
        XCTAssertEqual(payslip.employerPensionContribution, 50)
        XCTAssertEqual(payslip.otherDeductions, 0)
        XCTAssertEqual(payslip.employer, "Acme Corp")
        XCTAssertEqual(payslip.notes, "June payslip")
    }

    @MainActor
    func test_createMultiplePayslips_allPersist() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        // When
        for month in 1...3 {
            let payDate = makeDate(year: currentYear, month: month, day: 25)
            let periodStart = makeDate(year: currentYear, month: month, day: 1)
            let periodEnd = makeDate(year: currentYear, month: month, day: 28)

            sut.createPayslip(
                payDate: payDate,
                payPeriodStart: periodStart,
                payPeriodEnd: periodEnd,
                grossPay: Decimal(month) * 1000,
                netPay: Decimal(month) * 700,
                incomeTax: Decimal(month) * 200,
                socialInsurance: Decimal(month) * 50,
                universalCharge: nil,
                pensionContribution: 0,
                employerPensionContribution: 0,
                otherDeductions: 0,
                employer: "Test Co",
                notes: nil,
                modelContext: modelContext
            )
        }

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.payslips.count, 3)
    }

    // MARK: - Delete Payslip

    @MainActor
    func test_deletePayslip_removesFromList() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let payDate = makeDate(year: currentYear, month: 3, day: 25)
        let periodStart = makeDate(year: currentYear, month: 3, day: 1)
        let periodEnd = makeDate(year: currentYear, month: 3, day: 31)

        sut.createPayslip(
            payDate: payDate,
            payPeriodStart: periodStart,
            payPeriodEnd: periodEnd,
            grossPay: 4000,
            netPay: 3000,
            incomeTax: 700,
            socialInsurance: 150,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.payslips.count, 1)

        guard let payslip = sut.payslips.first else {
            XCTFail("No payslip found")
            return
        }

        // When
        sut.deletePayslip(payslip, modelContext: modelContext)

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.payslips.count, 0)
    }

    // MARK: - Total Gross YTD

    @MainActor
    func test_totalGrossYTD_sumsCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 5500,
            netPay: 3800,
            incomeTax: 1100,
            socialInsurance: 220,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.totalGrossYTD, 10500)
    }

    // MARK: - Total Net YTD

    @MainActor
    func test_totalNetYTD_sumsCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 5500,
            netPay: 3800,
            incomeTax: 1100,
            socialInsurance: 220,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.totalNetYTD, 7300)
    }

    // MARK: - Total Tax YTD

    @MainActor
    func test_totalTaxYTD_sumsCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 5500,
            netPay: 3800,
            incomeTax: 1100,
            socialInsurance: 220,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.totalTaxYTD, 2100)
    }

    // MARK: - Average Net Pay

    @MainActor
    func test_averageNetPay_calculatesCorrectly() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3000,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 5000,
            netPay: 4000,
            incomeTax: 800,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        // Average of 3000 and 4000 = 3500
        XCTAssertEqual(sut.averageNetPay, 3500)
    }

    // MARK: - Filter By Year

    @MainActor
    func test_filterByYear_showsOnlyMatchingYear() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        // Payslip in current year
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 6, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 6, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 6, day: 30),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Payslip in previous year
        sut.createPayslip(
            payDate: makeDate(year: currentYear - 1, month: 6, day: 25),
            payPeriodStart: makeDate(year: currentYear - 1, month: 6, day: 1),
            payPeriodEnd: makeDate(year: currentYear - 1, month: 6, day: 30),
            grossPay: 4000,
            netPay: 2800,
            incomeTax: 800,
            socialInsurance: 150,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.loadPayslips(modelContext: modelContext)

        // When - filter to current year (default)
        XCTAssertEqual(sut.filteredPayslips.count, 1)
        XCTAssertEqual(sut.filteredPayslips.first?.grossPay, 5000)

        // When - filter to previous year
        sut.filterYear = currentYear - 1
        XCTAssertEqual(sut.filteredPayslips.count, 1)
        XCTAssertEqual(sut.filteredPayslips.first?.grossPay, 4000)
    }

    // MARK: - Filter By Employer

    @MainActor
    func test_filterByEmployer_showsOnlyMatchingEmployer() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Acme Corp",
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 6000,
            netPay: 4200,
            incomeTax: 1200,
            socialInsurance: 240,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Other Inc",
            notes: nil,
            modelContext: modelContext
        )

        sut.loadPayslips(modelContext: modelContext)

        // When - no employer filter
        XCTAssertEqual(sut.filteredPayslips.count, 2)

        // When - filter by specific employer
        sut.filterEmployer = "Acme Corp"
        XCTAssertEqual(sut.filteredPayslips.count, 1)
        XCTAssertEqual(sut.filteredPayslips.first?.employer, "Acme Corp")
    }

    // MARK: - Pension Data Auto-Creation

    @MainActor
    func test_createPayslip_autoCreatesPensionData_whenNoneExistsAndHasContributions() {
        // Given - no PensionData exists
        let currentYear = Calendar.current.component(.year, from: Date())

        // When - create payslip with pension contributions
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 250,
            employerPensionContribution: 125,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then - PensionData should be auto-created
        let descriptor = FetchDescriptor<PensionData>()
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetched?.count, 1)
        XCTAssertEqual(fetched?.first?.currentValue, 0)
        XCTAssertEqual(fetched?.first?.totalEmployeeContributions, 250)
        XCTAssertEqual(fetched?.first?.totalEmployerContributions, 125)
    }

    @MainActor
    func test_createPayslip_doesNotCreatePensionData_whenContributionsAreZero() {
        // Given - no PensionData exists
        let currentYear = Calendar.current.component(.year, from: Date())

        // When - create payslip with zero pension contributions
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then - no PensionData should be created
        let descriptor = FetchDescriptor<PensionData>()
        let fetched = try? modelContext.fetch(descriptor)
        XCTAssertEqual(fetched?.count, 0)
    }

    // MARK: - Pension Data Integration

    @MainActor
    func test_createPayslip_updatesPensionData() {
        // Given
        let pensionData = PensionData(
            currentValue: 10000,
            totalEmployeeContributions: 5000,
            totalEmployerContributions: 3000
        )
        modelContext.insert(pensionData)
        try? modelContext.save()

        let currentYear = Calendar.current.component(.year, from: Date())

        // When
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 250,
            employerPensionContribution: 125,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        let descriptor = FetchDescriptor<PensionData>()
        let fetchedPension = try? modelContext.fetch(descriptor).first
        XCTAssertNotNil(fetchedPension)
        XCTAssertEqual(fetchedPension?.totalEmployeeContributions, 5250) // 5000 + 250
        XCTAssertEqual(fetchedPension?.totalEmployerContributions, 3125) // 3000 + 125
    }

    // MARK: - Computed Totals With Year Filter

    @MainActor
    func test_totalGrossYTD_onlyCountsFilteredYear() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 3, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 3, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 3, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear - 1, month: 3, day: 25),
            payPeriodStart: makeDate(year: currentYear - 1, month: 3, day: 1),
            payPeriodEnd: makeDate(year: currentYear - 1, month: 3, day: 31),
            grossPay: 9999,
            netPay: 7000,
            incomeTax: 2000,
            socialInsurance: 400,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.loadPayslips(modelContext: modelContext)

        // Then - default filter year is current year
        XCTAssertEqual(sut.totalGrossYTD, 5000)

        // When - switch to last year
        sut.filterYear = currentYear - 1
        XCTAssertEqual(sut.totalGrossYTD, 9999)
    }

    // MARK: - Create Payslip Without Universal Charge

    @MainActor
    func test_createPayslip_withNilUniversalCharge() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        // When
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 4, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 4, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 4, day: 30),
            grossPay: 4500,
            netPay: 3200,
            incomeTax: 900,
            socialInsurance: 180,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertNil(sut.payslips.first?.universalCharge)
    }

    // MARK: - Create Payslip Without Employer

    @MainActor
    func test_createPayslip_withNilEmployer() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        // When
        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 5, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 5, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 5, day: 31),
            grossPay: 4000,
            netPay: 2800,
            incomeTax: 800,
            socialInsurance: 160,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertNil(sut.payslips.first?.employer)
    }

    // MARK: - Sorted by Date Descending

    @MainActor
    func test_filteredPayslips_sortedByDateDescending() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 1000,
            netPay: 700,
            incomeTax: 200,
            socialInsurance: 50,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 3, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 3, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 3, day: 31),
            grossPay: 3000,
            netPay: 2100,
            incomeTax: 600,
            socialInsurance: 150,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 2000,
            netPay: 1400,
            incomeTax: 400,
            socialInsurance: 100,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: nil,
            notes: nil,
            modelContext: modelContext
        )

        sut.loadPayslips(modelContext: modelContext)

        // Then - most recent first
        let filtered = sut.filteredPayslips
        XCTAssertEqual(filtered.count, 3)
        XCTAssertEqual(filtered[0].grossPay, 3000) // March
        XCTAssertEqual(filtered[1].grossPay, 2000) // February
        XCTAssertEqual(filtered[2].grossPay, 1000) // January
    }

    // MARK: - Update Payslip

    @MainActor
    func test_updatePayslip_persistsChanges() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Old Corp",
            notes: nil,
            modelContext: modelContext
        )
        sut.loadPayslips(modelContext: modelContext)

        guard let payslip = sut.payslips.first else {
            XCTFail("No payslip found")
            return
        }

        // When
        payslip.employer = "New Corp"
        payslip.grossPay = 6000
        sut.updatePayslip(payslip, modelContext: modelContext)

        // Then
        sut.loadPayslips(modelContext: modelContext)
        XCTAssertEqual(sut.payslips.first?.employer, "New Corp")
        XCTAssertEqual(sut.payslips.first?.grossPay, 6000)
    }

    // MARK: - Available Employers

    @MainActor
    func test_availableEmployers_listsDistinctEmployers() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 1, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 1, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 1, day: 31),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Acme Corp",
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 2, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 2, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 2, day: 28),
            grossPay: 5000,
            netPay: 3500,
            incomeTax: 1000,
            socialInsurance: 200,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Acme Corp",
            notes: nil,
            modelContext: modelContext
        )

        sut.createPayslip(
            payDate: makeDate(year: currentYear, month: 3, day: 25),
            payPeriodStart: makeDate(year: currentYear, month: 3, day: 1),
            payPeriodEnd: makeDate(year: currentYear, month: 3, day: 31),
            grossPay: 6000,
            netPay: 4200,
            incomeTax: 1200,
            socialInsurance: 240,
            universalCharge: nil,
            pensionContribution: 0,
            employerPensionContribution: 0,
            otherDeductions: 0,
            employer: "Beta Inc",
            notes: nil,
            modelContext: modelContext
        )

        sut.loadPayslips(modelContext: modelContext)

        // Then
        XCTAssertEqual(sut.availableEmployers.count, 2)
        XCTAssertTrue(sut.availableEmployers.contains("Acme Corp"))
        XCTAssertTrue(sut.availableEmployers.contains("Beta Inc"))
    }
}
