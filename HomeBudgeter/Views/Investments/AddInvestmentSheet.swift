import SwiftUI
import SwiftData

struct AddInvestmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let viewModel: InvestmentViewModel

    @State private var symbol: String = ""
    @State private var name: String = ""
    @State private var assetType: AssetType = .stock
    @State private var currencyCode: String = "EUR"
    @State private var selectedAccount: Account?
    @State private var selectedMember: HouseholdMember?

    @Query(filter: #Predicate<Account> { $0.isActive }) private var accounts: [Account]

    let currencies = ["EUR", "USD", "GBP", "CHF", "JPY", "CAD", "AUD"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Investment")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Form {
                Section("Details") {
                    TextField("Symbol (e.g. AAPL)", text: $symbol)
                    TextField("Name (e.g. Apple Inc.)", text: $name)

                    Picker("Asset Type", selection: $assetType) {
                        ForEach(AssetType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }

                    Picker("Currency", selection: $currencyCode) {
                        ForEach(currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section("Assignment") {
                    Picker("Account", selection: $selectedAccount) {
                        Text("None").tag(nil as Account?)
                        ForEach(accounts, id: \.id) { account in
                            Text(account.name).tag(account as Account?)
                        }
                    }

                    if !viewModel.householdMembers.isEmpty {
                        Picker("Member", selection: $selectedMember) {
                            Text("None").tag(nil as HouseholdMember?)
                            ForEach(viewModel.householdMembers, id: \.id) { member in
                                Label(member.name, systemImage: member.icon)
                                    .tag(member as HouseholdMember?)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Add Investment") {
                    viewModel.addInvestment(
                        symbol: symbol,
                        name: name,
                        assetType: assetType,
                        currencyCode: currencyCode,
                        account: selectedAccount,
                        owner: selectedMember,
                        modelContext: modelContext
                    )
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(symbol.trimmingCharacters(in: .whitespaces).isEmpty ||
                         name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 400)
    }
}
