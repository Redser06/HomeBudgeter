import SwiftUI

struct LoginView: View {
    @State private var authManager = AuthManager.shared

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App Icon & Title
            VStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.primaryBlue)

                Text("Home Budgeter")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sign in to sync your finances across devices")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Sign In Button
            Button {
                Task { await authManager.signInWithGoogle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Sign in with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: 280)
                .frame(height: 44)
            }
            .buttonStyle(.bordered)

            if let error = authManager.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Text("Your data is encrypted and stored securely")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 24)
        }
        .frame(minWidth: 400, minHeight: 500)
        .padding()
    }
}

#Preview {
    LoginView()
}
