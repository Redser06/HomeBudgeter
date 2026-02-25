import Foundation
import AppKit
import Supabase

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    enum AuthState: Equatable {
        case unknown
        case signedOut
        case signedIn(userId: UUID)
    }

    private(set) var authState: AuthState = .unknown
    private(set) var userEmail: String?
    private(set) var errorMessage: String?

    var currentUserId: UUID? {
        if case .signedIn(let userId) = authState { return userId }
        return nil
    }

    var isSignedIn: Bool {
        if case .signedIn = authState { return true }
        return false
    }

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Session Restore

    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            authState = .signedIn(userId: session.user.id)
            userEmail = session.user.email
        } catch {
            authState = .signedOut
        }
    }

    // MARK: - Sign in with Google (OAuth browser flow)

    func signInWithGoogle() async {
        do {
            let url = try await supabase.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "homebudgeter://auth-callback")
            )
            NSWorkspace.shared.open(url)
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Handle OAuth Callback

    func handleOAuthCallback(url: URL) async {
        do {
            let session = try await supabase.auth.session(from: url)
            authState = .signedIn(userId: session.user.id)
            userEmail = session.user.email
            errorMessage = nil
        } catch {
            errorMessage = "Auth callback failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Account Linking

    func linkGoogleAccount() async {
        do {
            let response = try await supabase.auth.getLinkIdentityURL(provider: .google)
            NSWorkspace.shared.open(response.url)
        } catch {
            errorMessage = "Link Google failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
        } catch {
            print("Sign out error: \(error.localizedDescription)")
        }
        authState = .signedOut
        userEmail = nil
        errorMessage = nil
    }
}
