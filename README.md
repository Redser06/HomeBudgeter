# Home Budgeter

A native macOS personal finance application built with SwiftUI and SwiftData.

## Features

### Dashboard
- Financial overview with income, expenses, and net balance
- Monthly spending trends with interactive charts
- Budget health indicators with colour-coded alerts
- Quick actions for common tasks

### Transactions
- Full CRUD for income, expenses, and transfers
- Filtering by type, category, date range, and search text
- Sorting by date or amount (ascending/descending)
- Linked to accounts and budget categories

### Budget Management
- 11 budget category types (housing, food, transport, utilities, etc.)
- Per-category spending limits with progress tracking
- Configurable alert threshold (default 80%)
- Monthly rollover tracking

### Savings Goals
- Create goals with target amounts, deadlines, and priority levels
- Track contributions and progress percentage
- Active vs completed goal views
- Aggregate totals across all goals

### Recurring Transactions
- Template-based scheduling (daily, weekly, biweekly, monthly, quarterly, yearly)
- Automatic transaction generation when due
- Pause/resume and overdue detection
- Linked to categories and accounts

### Accounts
- Six account types: checking, savings, credit card, investment, pension, cash
- Balance tracking per account
- Transfer support between accounts

### Documents
- Import and classify documents (payslips, bills, receipts, statements, tax)
- Optional AES-256-GCM encryption at rest
- Keychain-managed encryption keys
- File size and date tracking

### Settings
- Multi-locale support: Ireland (EUR), UK (GBP), USA (USD), EU (EUR)
- Configurable first day of week and budget start day
- Dark mode preference (system/light/dark)
- Budget alert threshold slider
- Document encryption toggle
- Data export to JSON

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 5.9

## Getting Started

1. Clone the repository
2. Open `HomeBudgeter.xcodeproj` in Xcode
3. Build and run (Cmd+R)

Alternatively, if you have [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed:
```bash
cd HomeBudgeter
xcodegen generate
open HomeBudgeter.xcodeproj
```

## Project Structure

```
HomeBudgeter/
├── HomeBudgeterApp.swift          # App entry point & SwiftData container
├── Models/                        # SwiftData @Model entities
│   ├── Transaction.swift
│   ├── BudgetCategory.swift
│   ├── Account.swift
│   ├── SavingsGoal.swift
│   ├── RecurringTemplate.swift
│   ├── Document.swift
│   ├── Payslip.swift
│   ├── PensionData.swift
│   └── AppLocale.swift
├── ViewModels/                    # @Observable state management
│   ├── DashboardViewModel.swift
│   ├── BudgetViewModel.swift
│   ├── TransactionsViewModel.swift
│   ├── SavingsGoalViewModel.swift
│   ├── RecurringViewModel.swift
│   ├── DocumentsViewModel.swift
│   └── SettingsViewModel.swift
├── Views/
│   ├── ContentView.swift          # NavigationSplitView root
│   ├── Dashboard/
│   ├── Budget/
│   ├── Transactions/
│   ├── Savings/
│   ├── Recurring/
│   ├── Documents/
│   ├── Settings/
│   └── Shared/                    # Reusable components
├── Services/
│   ├── DataService.swift          # SwiftData query helpers
│   ├── CurrencyFormatter.swift    # Thread-safe locale-aware formatting
│   ├── RecurringTransactionService.swift
│   ├── FileEncryptionService.swift
│   ├── KeychainManager.swift
│   ├── LocaleManager.swift
│   └── PersistenceController.swift
├── Extensions/
│   └── Color+Theme.swift
└── Utilities/
    └── Extensions.swift

HomeBudgeterTests/
├── Models/           # 7 test files
├── ViewModels/       # 7 test files
├── Services/         # 3 test files
└── Integration/      # 2 test files
```

## Architecture

- **MVVM** with `@Observable` ViewModels and SwiftUI Views
- **SwiftData** for persistence (SQLite-backed, in-process)
- **NavigationSplitView** sidebar navigation pattern
- **Decimal** type for all monetary values (no floating-point precision issues)
- **CryptoKit** AES-256-GCM for document encryption
- **Security framework** for Keychain credential storage
- **UserDefaults** for app settings

## Testing

Run the full test suite from Xcode (Cmd+U) or via command line:

```bash
xcodebuild test -scheme HomeBudgeter -destination "platform=macOS"
```

**473 tests** across models, view models, services, and integration layers.

## Locale Support

| Region | Currency | Tax Labels |
|--------|----------|------------|
| Ireland | EUR (€) | Income Tax, USC, PRSI |
| United Kingdom | GBP (£) | Income Tax, NI |
| United States | USD ($) | Federal Tax, State Tax, FICA |
| European Union | EUR (€) | Income Tax, Social Security |

## License

Copyright 2024 Home Budgeter Team. All rights reserved.
