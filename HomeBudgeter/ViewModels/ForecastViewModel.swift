//
//  ForecastViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@Observable
class ForecastViewModel {
    var forecast: MonthlyForecastSummary?
    var isLoading = false

    var predictedIncome: Decimal { forecast?.predictedIncome ?? 0 }
    var predictedExpenses: Decimal { forecast?.predictedExpenses ?? 0 }
    var predictedNet: Decimal { forecast?.predictedNet ?? 0 }
    var predictedSavingsRate: Double { forecast?.predictedSavingsRate ?? 0 }
    var categoryForecasts: [CategoryForecast] { forecast?.categoryForecasts ?? [] }
    var confidence: ForecastConfidence { forecast?.confidence ?? .low }

    var forecastMonthString: String {
        guard let date = forecast?.forecastMonth else { return "Next Month" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    var atRiskCategories: [CategoryForecast] {
        categoryForecasts.filter { $0.isLikelyOverBudget }
    }

    var totalPredictedOverspend: Decimal {
        atRiskCategories.reduce(Decimal.zero) { $0 + $1.overspendAmount }
    }

    @MainActor
    func loadForecast(modelContext: ModelContext) {
        isLoading = true
        forecast = BudgetForecastService.shared.generateForecast(modelContext: modelContext)
        isLoading = false
    }
}
