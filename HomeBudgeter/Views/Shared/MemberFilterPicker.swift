import SwiftUI
import SwiftData

struct MemberFilterPicker: View {
    @Binding var selectedMember: HouseholdMember?
    let members: [HouseholdMember]

    var body: some View {
        Picker("Member", selection: $selectedMember) {
            Label("All Members", systemImage: "person.2")
                .tag(nil as HouseholdMember?)

            ForEach(members, id: \.id) { member in
                Label {
                    Text(member.name)
                } icon: {
                    Image(systemName: member.icon)
                }
                .tag(member as HouseholdMember?)
            }
        }
        .frame(width: 180)
    }
}
