import Foundation
import SwiftUI

// MARK: - CurrencyFormatter

/// Thread-safe currency formatting service.
/// Caches one `NumberFormatter` per `AppLocale` so repeated calls are cheap.
/// All public methods may be called from any thread.
final class CurrencyFormatter {

    // MARK: Shared singleton
    static let shared = CurrencyFormatter()

    // MARK: Private state

    private let lock = NSLock()
    private var _currentLocale: AppLocale = .ireland

    /// One formatter cached per locale, created lazily on first use.
    private var cache: [AppLocale: NumberFormatter] = [:]

    // MARK: Init
    private init() {}

    // MARK: Public Interface

    /// The currently active locale.
    var locale: AppLocale {
        lock.lock(); defer { lock.unlock() }
        return _currentLocale
    }

    /// Convenience: currency symbol for the active locale.
    var currencySymbol: String {
        lock.lock(); defer { lock.unlock() }
        return _currentLocale.currencySymbol
    }

    /// Switch the active locale (e.g. when the user changes a setting).
    func setLocale(_ locale: AppLocale) {
        lock.lock(); defer { lock.unlock() }
        _currentLocale = locale
    }

    // MARK: Formatting

    /// Full formatted string, e.g. €1,234.56 / £1,234.56 / $1,234.56 / 1.234,56 €
    func format(_ amount: Decimal) -> String {
        lock.lock()
        let locale = _currentLocale
        let formatter = cachedFormatter(for: locale)
        lock.unlock()
        return formatter.string(from: amount as NSNumber) ?? fallback(for: locale, amount: amount)
    }

    /// Full formatted string accepting Double.
    func format(_ amount: Double) -> String {
        format(Decimal(amount))
    }

    /// Compact notation: €1.2K / €3.4M. Negatives are handled correctly (−€1.2K).
    func formatCompact(_ amount: Decimal) -> String {
        let doubleAmount = Double(truncating: amount as NSNumber)
        let absAmount = abs(doubleAmount)
        let sign = doubleAmount < 0 ? "−" : ""

        lock.lock()
        let locale = _currentLocale
        lock.unlock()

        let symbol = locale.currencySymbol

        // For EU (de_DE) the symbol trails; for all others it leads.
        let symbolTrails = locale == .eu

        func compose(_ value: String) -> String {
            symbolTrails ? "\(sign)\(value) \(symbol)" : "\(sign)\(symbol)\(value)"
        }

        if absAmount >= 1_000_000 {
            return compose(String(format: "%.1fM", absAmount / 1_000_000))
        } else if absAmount >= 1_000 {
            return compose(String(format: "%.1fK", absAmount / 1_000))
        }
        // Below 1 000: fall back to full format (handles negatives natively via formatter).
        return format(amount)
    }

    /// Compact notation accepting Double.
    func formatCompact(_ amount: Double) -> String {
        formatCompact(Decimal(amount))
    }

    // MARK: Parsing

    /// Parse a string entered by the user into a `Decimal`, stripping symbols and
    /// normalising the decimal separator for the active locale.
    func parse(_ string: String) -> Decimal? {
        lock.lock()
        let locale = _currentLocale
        lock.unlock()

        var clean = string
            .replacingOccurrences(of: locale.currencySymbol, with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-") // Unicode minus → hyphen
            .trimmingCharacters(in: .whitespaces)

        // EU locale (de_DE) uses "." as thousands separator and "," as decimal.
        // Ireland uses "," as thousands separator and "." as decimal.
        switch locale {
        case .eu:
            // Remove thousands dot, replace decimal comma with dot.
            clean = clean
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        case .ireland, .uk, .usa:
            // Remove thousands comma; decimal is already ".".
            clean = clean.replacingOccurrences(of: ",", with: "")
        }

        return Decimal(string: clean)
    }

    /// Parse a string into a Double
    func parseDouble(_ string: String) -> Double? {
        guard let decimal = parse(string) else { return nil }
        return Double(truncating: decimal as NSNumber)
    }

    /// Currency code for the active locale (e.g., EUR, GBP, USD)
    var currencyCode: String {
        lock.lock(); defer { lock.unlock() }
        return _currentLocale.currencyCode
    }

    /// Formats amount with explicit sign prefix (+/-)
    func formatWithSign(_ amount: Double, forceSign: Bool = false) -> String {
        let formatted = format(abs(amount))
        if amount > 0 && forceSign {
            return "+\(formatted)"
        } else if amount < 0 {
            return "-\(formatted)"
        }
        return formatted
    }

    // MARK: Private helpers

    /// Returns (and caches) the `NumberFormatter` for the given locale.
    /// **Must be called inside `lock`.**
    private func cachedFormatter(for appLocale: AppLocale) -> NumberFormatter {
        if let existing = cache[appLocale] {
            return existing
        }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = appLocale.locale
        f.currencyCode = appLocale.currencyCode
        f.currencySymbol = appLocale.currencySymbol
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        // Negative values: use standard sign (−) before the symbol where applicable.
        f.negativeFormat = appLocale == .eu ? "-#,##0.00 ¤" : "-¤#,##0.00"
        cache[appLocale] = f
        return f
    }

    private func fallback(for locale: AppLocale, amount: Decimal) -> String {
        "\(locale.currencySymbol)\(amount)"
    }
}

// MARK: - SwiftUI Environment Key

struct CurrencyFormatterKey: EnvironmentKey {
    static let defaultValue = CurrencyFormatter.shared
}

extension EnvironmentValues {
    var currencyFormatter: CurrencyFormatter {
        get { self[CurrencyFormatterKey.self] }
        set { self[CurrencyFormatterKey.self] = newValue }
    }
}
