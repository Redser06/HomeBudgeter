//
//  ContentView.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case budget = "Budget"
    case transactions = "Transactions"
    case savings = "Savings"
    case recurring = "Recurring"
    case payslips = "Payslips"
    case pension = "Pension"
    case reports = "Reports"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .budget: return "dollarsign.circle.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .savings: return "target"
        case .recurring: return "repeat.circle.fill"
        case .payslips: return "doc.text.fill"
        case .pension: return "building.columns.fill"
        case .reports: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedItem)
        } detail: {
            DetailView(selectedItem: selectedItem)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

struct SidebarView: View {
    @Binding var selectedItem: NavigationItem?

    var body: some View {
        List(NavigationItem.allCases, selection: $selectedItem) { item in
            NavigationLink(value: item) {
                Label(item.rawValue, systemImage: item.icon)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Home Budgeter")
        .frame(minWidth: 200)
    }
}

struct DetailView: View {
    let selectedItem: NavigationItem?

    var body: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .budget:
            BudgetView()
        case .transactions:
            TransactionsView()
        case .savings:
            SavingsGoalView()
        case .recurring:
            RecurringTransactionsView()
        case .payslips:
            PayslipView()
        case .pension:
            PensionView()
        case .reports:
            ReportsView()
        case .settings:
            SettingsView()
        case nil:
            Text("Select an item from the sidebar")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
