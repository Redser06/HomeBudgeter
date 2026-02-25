import SwiftUI

struct RootView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        Group {
            switch authManager.authState {
            case .unknown:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                LoginView()
            case .signedIn:
                ContentView()
            }
        }
        .task {
            await authManager.restoreSession()
        }
    }
}

#Preview {
    RootView()
}
