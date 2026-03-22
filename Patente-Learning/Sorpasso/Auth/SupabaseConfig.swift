//
//  SupabaseConfig.swift
//  Patente-Learning
//
//  ⚠️ SETUP REQUIRED:
//  1. In Xcode → File → Add Package Dependencies
//     URL: https://github.com/supabase/supabase-swift
//     Version: Up to Next Major from 2.0.0
//
//  2. Replace the two placeholder strings below with your
//     Supabase project URL and anon key (Settings → API in Supabase dashboard)
//
//  3. In Xcode → Target → Info → URL Types, add a URL scheme:
//     Identifier: com.yourapp.oauth
//     URL Schemes:  patente-learning
//     (Required for Google OAuth deep-link callback)
//
//  4. In Xcode → Target → Signing & Capabilities:
//     Add "Sign In with Apple" capability
//

import Foundation
import Supabase

// MARK: - Credentials
// 🔑 Replace these with your actual Supabase project credentials
private let supabaseURL  = "https://bwsdsvebvyllxrzwqdie.supabase.co"
private let supabaseKey  = "sb_publishable_4Y6AjXYqyoDGHlpGB4JLQw_YN7M-I1J"

// MARK: - Shared Client
/// Single shared Supabase client used throughout the app.
/// Access via `SupabaseConfig.client` or the convenience global `supabaseClient`.
enum SupabaseConfig {
    static let client = SupabaseClient(
        supabaseURL: URL(string: supabaseURL)!,
        supabaseKey: supabaseKey
    )
}

/// Convenience shorthand used inside Auth files
let supabaseClient = SupabaseConfig.client
