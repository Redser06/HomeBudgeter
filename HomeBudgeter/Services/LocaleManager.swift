import Foundation
import SwiftUI

// MARK: - LocaleManager

/// Centralised service that owns the app's active `AppLocale`.
///
/// - Persists the selected locale via `UserDefaults` (key: `"selectedLocale"`).
/// - On every locale change it synchronises `CurrencyFormatter.shared` so that
///   all in-flight formatters immediately reflect the new locale.
/// - Exposes itself as a SwiftUI `EnvironmentObject` / Environment value so that
///   any view can read `@Environment(\.localeManager)` without needing an explicit
///   object graph.
///
/// Usage:
/// ```swift
/// // In App scene:
/// ContentView()
///     .environment(\.localeManager, LocaleManager.shared)
///
/// // In a view:
/// @Environment(\.localeManager) private var localeManager
/// ```
@Observable
final class LocaleManager {

    // MARK: Singleton

    static let shared = LocaleManager()

    // MARK: Persisted State

    /// The currently active locale.
    /// Changing this value immediately updates `CurrencyFormatter.shared`
    /// and persists the choice to `UserDefaults`.
    var currentLocale: AppLocale {
        didSet {
            guard currentLocale != oldValue else { return }
            persist(currentLocale)
            CurrencyFormatter.shared.setLocale(currentLocale)
        }
    }

    // MARK: Init

    private init() {
        // Restore from UserDefaults; fall back to Ireland.
        if let raw = UserDefaults.standard.string(forKey: Keys.selectedLocale),
           let saved = AppLocale(rawValue: raw) {
            currentLocale = saved
        } else {
            currentLocale = .ireland
        }
        // Ensure the formatter is aligned with the restored locale.
        CurrencyFormatter.shared.setLocale(currentLocale)
    }

    // MARK: Public Helpers

    /// The currency symbol for the active locale.
    var currencySymbol: String { currentLocale.currencySymbol }

    /// The currency code for the active locale.
    var currencyCode: String { currentLocale.currencyCode }

    /// Tax labels for the active locale.
    var taxLabels: TaxLabels { currentLocale.taxLabels }

    /// Formats `amount` using the active locale's full currency style.
    func format(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.format(amount)
    }

    /// Formats `amount` using the active locale's compact currency style.
    func formatCompact(_ amount: Decimal) -> String {
        CurrencyFormatter.shared.formatCompact(amount)
    }

    /// Parses a user-entered string into a `Decimal` using locale-aware rules.
    func parse(_ string: String) -> Decimal? {
        CurrencyFormatter.shared.parse(string)
    }

    // MARK: Private

    private enum Keys {
        static let selectedLocale = "selectedLocale"
    }

    private func persist(_ locale: AppLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: Keys.selectedLocale)
    }
}

// MARK: - SwiftUI Environment Key

private struct LocaleManagerKey: EnvironmentKey {
    static let defaultValue: LocaleManager = .shared
}

extension EnvironmentValues {
    /// Access the shared `LocaleManager` from any view's environment.
    var localeManager: LocaleManager {
        get { self[LocaleManagerKey.self] }
        set { self[LocaleManagerKey.self] = newValue }
    }
}
