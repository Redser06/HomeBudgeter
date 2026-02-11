# CLAUDE.md — Home Budgeter

## Project Overview

macOS personal finance app built with SwiftUI + SwiftData. Native macOS 14+ (Sonoma).

## Build & Run

```bash
# Build
xcodebuild -scheme HomeBudgeter -destination "platform=macOS" build

# Run tests (473 tests)
xcodebuild test -scheme HomeBudgeter -destination "platform=macOS"

# Generate project from spec (requires XcodeGen)
xcodegen generate
```

## Architecture

- **Pattern**: MVVM — `@Observable` ViewModels, SwiftUI Views, SwiftData `@Model` entities
- **Navigation**: `NavigationSplitView` with sidebar enum (`NavigationItem`)
- **Persistence**: SwiftData (not Core Data). All models use `@Model` macro
- **State**: ViewModels are `@Observable` (not `ObservableObject`). No `@Published` — use stored properties
- **Currency**: Always use `Decimal` for monetary values, never `Double` or `Float`
- **Formatting**: Use `CurrencyFormatter.shared` for all currency display
- **Encryption**: AES-256-GCM via CryptoKit. Keys stored in Keychain via `KeychainManager`
- **Settings**: `UserDefaults` with `didSet` observers in `SettingsViewModel`
- **Default locale**: Ireland (EUR €)

## Key Conventions

### Models
- All SwiftData models are in `HomeBudgeter/Models/`
- Schema includes: `Transaction`, `BudgetCategory`, `Account`, `SavingsGoal`, `RecurringTemplate`, `Document`, `Payslip`, `PensionData`
- When adding a new `@Model`, add it to the schema in `HomeBudgeterApp.swift` AND in every test file's `setUp()` method

### ViewModels
- Accept `modelContext: ModelContext` as a parameter to methods (don't store it)
- Use `@MainActor` on any method that touches SwiftData context
- Properties like `showingCreateSheet`, `selectedItem` for sheet state

### Views
- Theme colours: `.primaryBlue`, `.budgetHealthy`, `.budgetDanger`, `.budgetWarning`
- Use `Color.budgetStatusColor(percentage:)` for budget health indicators
- Shared components in `Views/Shared/`: `StatCard`, `ProgressBar`, `CurrencyTextField`, `TransactionRow`, `QuickActionButton`, `BudgetCategoryCard`

### Services
- Singletons use `.shared` pattern
- `RecurringTransactionService` is `@MainActor`
- `FileEncryptionService` handles encrypt/decrypt with automatic key generation
- `KeychainManager` uses Security framework, throws `KeychainError`

### Tests
- All tests use in-memory `ModelContainer` with `ModelConfiguration(isStoredInMemoryOnly: true)`
- Test files are in `HomeBudgeterTests/` organized by: `Models/`, `ViewModels/`, `Services/`, `Integration/`
- When comparing `Decimal` values from floating-point literals (e.g. 17.99), use `Decimal(string: "17.99")` for exact comparison
- Methods touching SwiftData must be marked `@MainActor` in tests too

## File Layout

```
HomeBudgeter/
├── HomeBudgeterApp.swift
├── Models/          # SwiftData @Model entities
├── ViewModels/      # @Observable state management
├── Views/           # SwiftUI views (by feature + Shared/)
├── Services/        # Business logic & data access
├── Extensions/      # Color+Theme.swift
├── Utilities/       # Extensions.swift (Date, Decimal, View, String)
└── Resources/       # Info.plist, entitlements, assets

HomeBudgeterTests/
├── Models/          # Model unit tests
├── ViewModels/      # ViewModel unit tests
├── Services/        # Service unit tests
└── Integration/     # Persistence & data flow tests
```

## Adding New Features

1. Create `@Model` in `Models/` if needed — add to schema in `HomeBudgeterApp.swift` + all test `setUp()` methods
2. Create `@Observable` ViewModel in `ViewModels/`
3. Create View in `Views/<FeatureName>/`
4. Add `NavigationItem` case in `ContentView.swift` with icon and route
5. Add files to `HomeBudgeter.xcodeproj` (Xcode doesn't auto-discover files)
6. Write tests in `HomeBudgeterTests/<Layer>/`

## Common Pitfalls

- **Decimal precision**: `Decimal(17.99)` != `Decimal(string: "17.99")`. Always use string initializer for exact values
- **@MainActor**: Required on any code path that accesses `ModelContext`
- **RecurringTemplate.nextDueDate**: Defaults to `startDate` — a template created with `startDate: Date()` is immediately considered overdue
- **Xcode pbxproj**: New files must be manually added to the project file (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase)
- **Test schema**: Every test file's `setUp()` must include ALL `@Model` types in the `Schema` array, even if not used in that test
