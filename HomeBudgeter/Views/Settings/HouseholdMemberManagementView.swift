import SwiftUI
import SwiftData

struct HouseholdMemberManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = HouseholdMemberViewModel()
    @State private var showingAddSheet = false
    @State private var editingMember: HouseholdMember?
    @State private var showingDeleteConfirmation = false
    @State private var memberToDelete: HouseholdMember?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.members.isEmpty {
                HStack {
                    Text("No household members configured")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(viewModel.members, id: \.id) { member in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(member.color)
                            .frame(width: 12, height: 12)

                        Image(systemName: member.icon)
                            .foregroundColor(member.color)
                            .frame(width: 20)

                        Text(member.name)
                            .fontWeight(member.isDefault ? .semibold : .regular)

                        if member.isDefault {
                            Text("Default")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(member.color.opacity(0.15))
                                .foregroundColor(member.color)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Button {
                            editingMember = member
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                        Button {
                            memberToDelete = member
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                showingAddSheet = true
            } label: {
                Label("Add Member", systemImage: "plus.circle")
            }
            .controlSize(.small)
        }
        .onAppear {
            viewModel.loadMembers(modelContext: modelContext)
        }
        .sheet(isPresented: $showingAddSheet) {
            MemberFormSheet(viewModel: viewModel)
        }
        .sheet(item: $editingMember) { member in
            MemberFormSheet(viewModel: viewModel, editing: member)
        }
        .alert("Delete Member?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { memberToDelete = nil }
            Button("Delete", role: .destructive) {
                if let member = memberToDelete {
                    viewModel.deleteMember(member, modelContext: modelContext)
                }
                memberToDelete = nil
            }
        } message: {
            Text("The member will be removed. Their accounts, payslips, and savings goals will be kept but unassigned.")
        }
    }
}

// MARK: - Member Form Sheet

private struct MemberFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let viewModel: HouseholdMemberViewModel
    var editing: HouseholdMember?

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var selectedIcon: String = "person.circle.fill"
    @State private var isDefault: Bool = false

    init(viewModel: HouseholdMemberViewModel, editing: HouseholdMember? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        if let member = editing {
            _name = State(initialValue: member.name)
            _selectedColorHex = State(initialValue: member.colorHex)
            _selectedIcon = State(initialValue: member.icon)
            _isDefault = State(initialValue: member.isDefault)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(editing != nil ? "Edit Member" : "Add Member")
                        .font(.headline)
                    Text("Configure a household member's appearance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Details
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Default Member", isOn: $isDefault)
                    }

                    Divider()

                    // Colour
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colour")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 8), spacing: 10) {
                            ForEach(HouseholdMemberViewModel.colorPalette, id: \.hex) { color in
                                Circle()
                                    .fill(Color(hex: color.hex) ?? .blue)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.primary, lineWidth: selectedColorHex == color.hex ? 2.5 : 0)
                                    )
                                    .scaleEffect(selectedColorHex == color.hex ? 1.1 : 1.0)
                                    .animation(.easeInOut(duration: 0.15), value: selectedColorHex)
                                    .onTapGesture {
                                        selectedColorHex = color.hex
                                    }
                            }
                        }
                    }

                    Divider()

                    // Icon
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(48)), count: 8), spacing: 10) {
                            ForEach(HouseholdMemberViewModel.iconOptions, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? .blue).opacity(0.2) : Color.secondary.opacity(0.06))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? .blue) : .clear, lineWidth: 1.5)
                                    )
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                    }

                    Divider()

                    // Preview
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preview")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: selectedColorHex) ?? .blue)
                                .frame(width: 14, height: 14)
                            Image(systemName: selectedIcon)
                                .font(.title3)
                                .foregroundColor(Color(hex: selectedColorHex) ?? .blue)
                            Text(name.isEmpty ? "Member Name" : name)
                                .font(.body)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)

                            if isDefault {
                                Text("Default")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background((Color(hex: selectedColorHex) ?? .blue).opacity(0.15))
                                    .foregroundColor(Color(hex: selectedColorHex) ?? .blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(editing != nil ? "Save" : "Add Member") {
                    if let member = editing {
                        viewModel.updateMember(
                            member,
                            name: name,
                            colorHex: selectedColorHex,
                            icon: selectedIcon,
                            isDefault: isDefault,
                            modelContext: modelContext
                        )
                    } else {
                        viewModel.addMember(
                            name: name,
                            colorHex: selectedColorHex,
                            icon: selectedIcon,
                            isDefault: isDefault,
                            modelContext: modelContext
                        )
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 460, height: 580)
    }
}
