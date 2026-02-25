import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://qyfoxdoojjswnqwhthkm.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5Zm94ZG9vampzd25xd2h0aGttIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5MjU1MjMsImV4cCI6MjA4NzUwMTUyM30.rQcKFX4YGOiqHjDKsnjmQ8MwBtWUgaJ1lVIU6lrpFyg",
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: URL(string: "homebudgeter://auth-callback"),
                    flowType: .pkce
                )
            )
        )
    }
}
