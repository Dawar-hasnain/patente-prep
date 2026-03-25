//
//  LeaderboardManager.swift
//  Patente-Learning
//
//  Reads and writes the live leaderboard via Supabase.
//  Falls back gracefully to simulated data on any error (offline, table missing, etc.).
//
//  ── Supabase setup (run once in SQL editor) ──────────────────────────────
//
//  create table if not exists public.leaderboard (
//    user_id    uuid primary key references auth.users(id) on delete cascade,
//    username   text not null default 'Anonymous',
//    emoji      text not null default '🚗',
//    xp         integer not null default 0,
//    tier       text not null default 'Bronze',
//    updated_at timestamptz not null default now()
//  );
//
//  alter table public.leaderboard enable row level security;
//
//  create policy "lb_read"
//    on public.leaderboard for select
//    to anon, authenticated using (true);
//
//  create policy "lb_insert"
//    on public.leaderboard for insert
//    to authenticated with check (auth.uid() = user_id);
//
//  create policy "lb_update"
//    on public.leaderboard for update
//    to authenticated using (auth.uid() = user_id);
//
//  ─────────────────────────────────────────────────────────────────────────

import Foundation
import Supabase

// MARK: - Row model

struct LeaderboardRow: Codable {
    let user_id:  String
    let username: String
    let emoji:    String
    let xp:       Int
    let tier:     String

    // updated_at is set by Supabase — only needed for decoding, not encoding
    var updated_at: String?

    enum CodingKeys: String, CodingKey {
        case user_id, username, emoji, xp, tier, updated_at
    }

    init(user_id: String, username: String, emoji: String, xp: Int, tier: String) {
        self.user_id    = user_id
        self.username   = username
        self.emoji      = emoji
        self.xp         = xp
        self.tier       = tier
        self.updated_at = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - LeaderboardManager

final class LeaderboardManager {

    static let shared = LeaderboardManager()
    private init() {}

    // MARK: - Upsert

    /// Fire-and-forget: writes the current user's XP row to Supabase.
    /// Silently no-ops if the user is not authenticated or the network is unavailable.
    func upsertCurrentUser() {
        Task {
            guard let userId = supabaseClient.auth.currentUser?.id.uuidString else { return }
            let row = LeaderboardRow(
                user_id:  userId,
                username: UserDefaults.standard.string(forKey: "userName") ?? "Anonymous",
                emoji:    UserDefaults.standard.string(forKey: "userEmoji") ?? "🚗",
                xp:       XPManager.shared.totalXP,
                tier:     XPManager.shared.currentTier.rawValue
            )
            try? await supabaseClient
                .from("leaderboard")
                .upsert(row)
                .execute()
        }
    }

    // MARK: - Fetch

    /// Returns the top-25 entries for `tier`, sorted by XP descending.
    /// Throws on any network or Supabase error — caller should fall back to bots.
    func fetchLeaderboard(tier: String) async throws -> [LeaderboardRow] {
        let rows: [LeaderboardRow] = try await supabaseClient
            .from("leaderboard")
            .select("user_id, username, emoji, xp, tier")
            .eq("tier", value: tier)
            .order("xp", ascending: false)
            .limit(25)
            .execute()
            .value
        return rows
    }
}
