import SwiftUI

struct CurrencyTextField: View {
    let title: String
    @Binding var value: Decimal
    let locale: AppLocale

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    init(title: String, value: Binding<Decimal>, locale: AppLocale = .ireland) {
        self.title = title
        self._value = value
        self.locale = locale
    }

    var body: some View {
        HStack {
            Text(locale.currencySymbol)
                .foregroundStyle(.secondary)
                .font(.body)

            TextField(title, text: $textValue)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onChange(of: textValue) { _, newValue in
                    // Filter to only allow valid currency input
                    let filtered = filterCurrencyInput(newValue)
                    if filtered != newValue {
                        textValue = filtered
                    }

                    // Parse and update binding
                    if let parsed = parseAmount(filtered) {
                        value = parsed
                    }
                }
                .onAppear {
                    textValue = formatForEditing(value)
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        // Format nicely when losing focus
                        textValue = formatForEditing(value)
                    }
                }
        }
        .padding(8)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFocused ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }

    private func filterCurrencyInput(_ input: String) -> String {
        var result = ""
        var hasDecimal = false
        var decimalPlaces = 0

        for char in input {
            if char.isNumber {
                if hasDecimal {
                    if decimalPlaces < 2 {
                        result.append(char)
                        decimalPlaces += 1
                    }
                } else {
                    result.append(char)
                }
            } else if char == "." || char == "," {
                if !hasDecimal {
                    result.append(".")
                    hasDecimal = true
                }
            }
        }

        return result
    }

    private func parseAmount(_ string: String) -> Decimal? {
        Decimal(string: string.replacingOccurrences(of: ",", with: "."))
    }

    private func formatForEditing(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        return formatter.string(from: amount as NSNumber) ?? "0.00"
    }
}

struct CurrencyDisplay: View {
    let amount: Decimal
    let style: DisplayStyle
    let showSign: Bool

    @Environment(\.currencyFormatter) private var formatter

    enum DisplayStyle {
        case large
        case medium
        case small
        case compact

        var font: Font {
            switch self {
            case .large: return .largeTitle
            case .medium: return .title2
            case .small: return .body
            case .compact: return .caption
            }
        }

        var weight: Font.Weight {
            switch self {
            case .large, .medium: return .bold
            case .small: return .semibold
            case .compact: return .medium
            }
        }
    }

    init(amount: Decimal, style: DisplayStyle = .medium, showSign: Bool = false) {
        self.amount = amount
        self.style = style
        self.showSign = showSign
    }

    var body: some View {
        Text(displayText)
            .font(style.font)
            .fontWeight(style.weight)
    }

    private var displayText: String {
        let formatted = style == .compact ? formatter.formatCompact(amount) : formatter.format(amount)
        if showSign && amount > 0 {
            return "+\(formatted)"
        }
        return formatted
    }
}

#Preview {
    VStack(spacing: 20) {
        CurrencyTextField(title: "Amount", value: .constant(123.45))

        CurrencyDisplay(amount: 1234.56, style: .large)
        CurrencyDisplay(amount: 1234.56, style: .medium, showSign: true)
        CurrencyDisplay(amount: 1234567.89, style: .compact)
    }
    .padding()
    .frame(width: 300)
}
