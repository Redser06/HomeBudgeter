//
//  SavingsGoalViewModel.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class SavingsGoalViewModel {
    var goals: [SavingsGoal] = []
    var showingCreateSheet: Bool = false
    var selectedGoal: SavingsGoal?
    var selectedMember: HouseholdMember?

    // MARK: - Computed Properties

    var totalSaved: Decimal {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    var totalTarget: Decimal {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    var filteredGoals: [SavingsGoal] {
        guard let member = selectedMember else { return goals }
        return goals.filter { $0.member?.id == member.id }
    }

    var completedGoals: [SavingsGoal] {
        filteredGoals.filter { $0.isCompleted }
    }

    var activeGoals: [SavingsGoal] {
        filteredGoals.filter { !$0.isCompleted }
    }

    // MARK: - Data Methods

    func loadGoals(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SavingsGoal>()

        do {
            let fetched = try modelContext.fetch(descriptor)
            goals = fetched.sorted { lhs, rhs in
                let priorityOrder: [GoalPriority: Int] = [.high: 0, .medium: 1, .low: 2]
                let lhsPriority = priorityOrder[lhs.priority] ?? 1
                let rhsPriority = priorityOrder[rhs.priority] ?? 1
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                switch (lhs.deadline, rhs.deadline) {
                case let (l?, r?):
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.createdAt < rhs.createdAt
                }
            }
        } catch {
            print("Error loading savings goals: \(error)")
        }
    }

    func createGoal(
        name: String,
        targetAmount: Decimal,
        deadline: Date? = nil,
        priority: GoalPriority = .medium,
        icon: String = "target",
        notes: String? = nil,
        modelContext: ModelContext
    ) {
        let goal = SavingsGoal(
            name: name,
            targetAmount: targetAmount,
            deadline: deadline,
            priority: priority,
            icon: icon,
            notes: notes
        )
        modelContext.insert(goal)
        try? modelContext.save()
        loadGoals(modelContext: modelContext)
    }

    func updateGoal(goal: SavingsGoal, modelContext: ModelContext) {
        goal.updatedAt = Date()
        try? modelContext.save()
        loadGoals(modelContext: modelContext)
    }

    func deleteGoal(goal: SavingsGoal, modelContext: ModelContext) {
        modelContext.delete(goal)
        try? modelContext.save()
        loadGoals(modelContext: modelContext)
    }

    func addContribution(goal: SavingsGoal, amount: Decimal, modelContext: ModelContext) {
        goal.currentAmount += amount
        goal.updatedAt = Date()
        if goal.currentAmount >= goal.targetAmount {
            goal.isCompleted = true
        }
        try? modelContext.save()
        loadGoals(modelContext: modelContext)
    }
}
