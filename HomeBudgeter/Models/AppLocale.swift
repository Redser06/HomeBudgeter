import Foundation

// MARK: - AppLocale

/// Represents the supported regional locale configurations for the app.
/// Each case carries locale-specific formatting, currency, and tax metadata.
enum AppLocale: String, CaseIterable, Codable, Identifiable {
    case ireland = "ie"
    case uk      = "gb"
    case usa     = "us"
    case eu      = "eu"

    var id: String { rawValue }

    // MARK: Display

    var displayName: String {
        switch self {
        case .ireland: return "Ireland"
        case .uk:      return "United Kingdom"
        case .usa:     return "United States"
        case .eu:      return "European Union"
        }
    }

    /// Short name suitable for compact pickers or labels.
    var shortName: String {
        switch self {
        case .ireland: return "Ireland"
        case .uk:      return "UK"
        case .usa:     return "USA"
        case .eu:      return "EU"
        }
    }

    /// Flag emoji for the locale.
    var flag: String {
        switch self {
        case .ireland: return "🇮🇪"
        case .uk:      return "🇬🇧"
        case .usa:     return "🇺🇸"
        case .eu:      return "🇪🇺"
        }
    }

    // MARK: Currency

    var currencyCode: String {
        switch self {
        case .ireland, .eu: return "EUR"
        case .uk:           return "GBP"
        case .usa:          return "USD"
        }
    }

    var currencySymbol: String {
        switch self {
        case .ireland, .eu: return "€"
        case .uk:           return "£"
        case .usa:          return "$"
        }
    }

    var currencyName: String {
        switch self {
        case .ireland, .eu: return "Euro"
        case .uk:           return "British Pound"
        case .usa:          return "US Dollar"
        }
    }

    // MARK: Locale

    /// The `Foundation.Locale` that governs number and date formatting.
    var locale: Locale {
        switch self {
        case .ireland: return Locale(identifier: "en_IE")
        case .uk:      return Locale(identifier: "en_GB")
        case .usa:     return Locale(identifier: "en_US")
        case .eu:      return Locale(identifier: "de_DE")
        }
    }

    // MARK: Tax Labels

    var taxLabels: TaxLabels {
        switch self {
        case .ireland:
            return TaxLabels(
                incomeTax: "PAYE",
                socialInsurance: "PRSI",
                universalCharge: "USC"
            )
        case .uk:
            return TaxLabels(
                incomeTax: "Income Tax",
                socialInsurance: "National Insurance",
                universalCharge: nil
            )
        case .usa:
            return TaxLabels(
                incomeTax: "Federal Tax",
                socialInsurance: "Social Security",
                universalCharge: "Medicare"
            )
        case .eu:
            return TaxLabels(
                incomeTax: "Income Tax",
                socialInsurance: "Social Contributions",
                universalCharge: nil
            )
        }
    }

    // MARK: Formatted example

    /// A sample formatted amount demonstrating this locale's currency style.
    var exampleFormatted: String {
        switch self {
        case .ireland: return "€1,234.56"
        case .uk:      return "£1,234.56"
        case .usa:     return "$1,234.56"
        case .eu:      return "1.234,56 €"
        }
    }
}

// MARK: - TaxLabels

struct TaxLabels {
    /// Primary income tax label (e.g. "PAYE", "Federal Tax").
    let incomeTax: String
    /// Social insurance / contributions label.
    let socialInsurance: String
    /// Optional third deduction (e.g. "USC", "Medicare").
    let universalCharge: String?

    /// All non-nil labels as an array, for list rendering.
    var all: [String] {
        [incomeTax, socialInsurance, universalCharge].compactMap { $0 }
    }
}
