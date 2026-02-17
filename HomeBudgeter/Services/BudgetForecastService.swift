//
//  BudgetForecastService.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

// MARK: - Forecast Data

struct CategoryForecast: Identifiable {
    let id = UUID()
    let categoryType: CategoryType
    let predictedSpend: Decimal
    let budgetAmount: Decimal
    let averageSpend: Decimal
    let monthsOfData: Int
    let trend: SpendTrend
    let recurringAmount: Decimal

    var predictedUtilisation: Double {
        guard budgetAmount > 0 else { return 0 }
        return Double(truncating: (predictedSpend / budgetAmount) as NSNumber) * 100
    }

    var isLikelyOverBudget: Bool {
        predictedSpend > budgetAmount && budgetAmount > 0
    }

    var overspendAmount: Decimal {
        max(predictedSpend - budgetAmount, 0)
    }
}

enum SpendTrend: String {
    case increasing = "Increasing"
    case decreasing = "Decreasing"
    case stable = "Stable"
    case insufficient = "Insufficient Data"
}

struct MonthlyForecastSummary {
    let predictedIncome: Decimal
    let predictedExpenses: Decimal
    let predictedNet: Decimal
    let predictedSavingsRate: Double
    let categoryForecasts: [CategoryForecast]
    let forecastMonth: Date
    let confidence: ForecastConfidence
}

enum ForecastConfidence: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var description: String {
        switch self {
        case .high: return "6+ months of data"
        case .medium: return "3-5 months of data"
        case .low: return "Less than 3 months"
        }
    }
}

// MARK: - BudgetForecastService

@MainActor
class BudgetForecastService {
    static let shared = BudgetForecastService()
    private init() {}

    func generateForecast(modelContext: ModelContext) -> MonthlyForecastSummary {
        let calendar = Calendar.current
        let now = Date()

        // Target: next month
        guard let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now))!) else {
            return emptyForecast(date: now)
        }

        // Fetch historical transactions (up to 6 months back)
        let monthsToAnalyse = 6
        guard let historyStart = calendar.date(byAdding: .month, value: -monthsToAnalyse, to: now) else {
            return emptyForecast(date: nextMonthStart)
        }

        let predicate = #Predicate<Transaction> { transaction in
            transaction.date >= historyStart
        }
        let descriptor = FetchDescriptor<Transaction>(predicate: predicate)

        let budgetDescriptor = FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { $0.isActive }
        )

        let recurringDescriptor = FetchDescriptor<RecurringTemplate>(
            predicate: #Predicate { $0.isActive }
        )

        do {
            let transactions = try modelContext.fetch(descriptor)
            let budgetCategories = try modelContext.fetch(budgetDescriptor)
            let recurringTemplates = try modelContext.fetch(recurringDescriptor)

            // Group transactions by month and category
            let monthlyData = groupByMonth(transactions: transactions, calendar: calendar)
            let monthCount = monthlyData.count

            // Determine confidence
            let confidence: ForecastConfidence
            if monthCount >= 6 { confidence = .high }
            else if monthCount >= 3 { confidence = .medium }
            else { confidence = .low }

            // Predict income
            let predictedIncome = predictAmount(
                monthlyData: monthlyData,
                type: .income,
                calendar: calendar
            )

            // Build category forecasts
            var categoryForecasts: [CategoryForecast] = []
            for budgetCategory in budgetCategories {
                let categoryName = budgetCategory.type.rawValue
                let monthlyAmounts = monthlyData.map { monthData -> Decimal in
                    monthData.value
                        .filter { $0.type == .expense && $0.category?.type.rawValue == categoryName }
                        .reduce(Decimal.zero) { $0 + $1.amount }
                }

                let recurringForCategory = recurringTemplates
                    .filter { $0.type == .expense && $0.category?.type == budgetCategory.type }
                    .reduce(Decimal.zero) { $0 + $1.monthlyEquivalentAmount }

                let predicted = predictCategorySpend(
                    monthlyAmounts: monthlyAmounts,
                    recurringAmount: recurringForCategory
                )

                let average = monthlyAmounts.isEmpty ? Decimal.zero :
                    monthlyAmounts.reduce(Decimal.zero, +) / Decimal(monthlyAmounts.count)

                let trend = determineTrend(amounts: monthlyAmounts)

                categoryForecasts.append(CategoryForecast(
                    categoryType: budgetCategory.type,
                    predictedSpend: predicted,
                    budgetAmount: budgetCategory.budgetAmount,
                    averageSpend: average,
                    monthsOfData: monthlyAmounts.filter { $0 > 0 }.count,
                    trend: trend,
                    recurringAmount: recurringForCategory
                ))
            }

            // Sort by predicted utilisation (most at risk first)
            categoryForecasts.sort { $0.predictedUtilisation > $1.predictedUtilisation }

            let predictedExpenses = categoryForecasts.reduce(Decimal.zero) { $0 + $1.predictedSpend }
            let predictedNet = predictedIncome - predictedExpenses
            let savingsRate = predictedIncome > 0
                ? Double(truncating: (predictedNet / predictedIncome) as NSNumber) * 100
                : 0

            return MonthlyForecastSummary(
                predictedIncome: predictedIncome,
                predictedExpenses: predictedExpenses,
                predictedNet: predictedNet,
                predictedSavingsRate: savingsRate,
                categoryForecasts: categoryForecasts,
                forecastMonth: nextMonthStart,
                confidence: confidence
            )
        } catch {
            print("Error generating forecast: \(error)")
            return emptyForecast(date: nextMonthStart)
        }
    }

    // MARK: - Private Helpers

    private func groupByMonth(transactions: [Transaction], calendar: Calendar) -> [(key: Date, value: [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction -> Date in
            let components = calendar.dateComponents([.year, .month], from: transaction.date)
            return calendar.date(from: components) ?? transaction.date
        }
        return grouped.sorted { $0.key < $1.key }
    }

    private func predictAmount(monthlyData: [(key: Date, value: [Transaction])], type: TransactionType, calendar: Calendar) -> Decimal {
        let monthlyAmounts = monthlyData.map { monthData -> Decimal in
            monthData.value
                .filter { $0.type == type }
                .reduce(Decimal.zero) { $0 + $1.amount }
        }

        guard !monthlyAmounts.isEmpty else { return Decimal.zero }

        // Exponential weighted moving average — recent months weighted more
        return exponentialWeightedAverage(amounts: monthlyAmounts)
    }

    private func predictCategorySpend(monthlyAmounts: [Decimal], recurringAmount: Decimal) -> Decimal {
        guard !monthlyAmounts.isEmpty else { return recurringAmount }

        let historicalPrediction = exponentialWeightedAverage(amounts: monthlyAmounts)

        // Blend: 70% historical pattern, 30% known recurring
        if recurringAmount > 0 {
            let blended = historicalPrediction * Decimal(string: "0.7")! + recurringAmount * Decimal(string: "0.3")!
            return max(blended, recurringAmount)
        }

        return historicalPrediction
    }

    private func exponentialWeightedAverage(amounts: [Decimal]) -> Decimal {
        guard !amounts.isEmpty else { return Decimal.zero }
        guard amounts.count > 1 else { return amounts[0] }

        // Alpha = 0.4 gives good recency bias
        let alpha = Decimal(string: "0.4")!
        var weightedSum = Decimal.zero
        var weightSum = Decimal.zero

        for (index, amount) in amounts.enumerated() {
            let recencyWeight = pow(alpha, amounts.count - 1 - index)
            weightedSum += amount * recencyWeight
            weightSum += recencyWeight
        }

        guard weightSum > 0 else { return amounts.last ?? Decimal.zero }
        return weightedSum / weightSum
    }

    private func determineTrend(amounts: [Decimal]) -> SpendTrend {
        guard amounts.count >= 3 else { return .insufficient }

        let recentThree = Array(amounts.suffix(3))
        let firstHalf = recentThree[0]
        let lastHalf = recentThree[2]

        guard firstHalf > 0 else { return .stable }

        let changePercent = Double(truncating: ((lastHalf - firstHalf) / firstHalf) as NSNumber) * 100

        if changePercent > 10 { return .increasing }
        if changePercent < -10 { return .decreasing }
        return .stable
    }

    private func emptyForecast(date: Date) -> MonthlyForecastSummary {
        MonthlyForecastSummary(
            predictedIncome: 0,
            predictedExpenses: 0,
            predictedNet: 0,
            predictedSavingsRate: 0,
            categoryForecasts: [],
            forecastMonth: date,
            confidence: .low
        )
    }
}
