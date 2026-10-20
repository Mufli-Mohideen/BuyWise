import Foundation
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://zjrcucrduuwjztwaypcn.supabase.co")!
    static let anonKey = "sb_publishable_xBk5BN2sP0Rx0gfVwg0TiQ_C0oAkwLE"
    static let authCallbackURL = URL(string: "buywise://login-callback")!
    static let passwordResetURL = URL(string: "buywise://reset-password")!
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
)
