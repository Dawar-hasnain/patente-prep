//
//  LeagueView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Shows the user's league tier, XP progress, and a simulated leaderboard.
//  Migration path: replace generateLeaderboard() with a Supabase query.
//

import SwiftUI

// MARK: - Leaderboard Entry

struct LeaderboardEntry: Identifiable {
    let id: Int           // rank
    let name: String
    let emoji: String
    let xp: Int
    let isCurrentUser: Bool
}

// MARK: - LeagueView

struct LeagueView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var animateBadge = false

    @ScaledMetric(relativeTo: .largeTitle) private var tierEmojiSize: CGFloat = 56
    private let xp = XPManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // ── League Hero ───────────────────────────────────────────
                leagueHero

                // ── XP Progress ───────────────────────────────────────────
                xpProgressSection

                // ── Leaderboard ───────────────────────────────────────────
                leaderboardSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear {
            entries = generateLeaderboard()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.2)) {
                animateBadge = true
            }
        }
    }

    // MARK: - League Hero

    private var leagueHero: some View {
        let tier = xp.currentTier
        let (topHex, botHex) = tier.color

        return VStack(spacing: 12) {
            // Badge
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: topHex), Color(hex: botHex)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: Color(hex: topHex).opacity(0.4), radius: 16, y: 8)
                    .rotationEffect(.degrees(animateBadge ? 0 : -8))
                    .scaleEffect(animateBadge ? 1.0 : 0.7)

                Text(tier.emoji)
                    .font(.system(size: tierEmojiSize))
            }

            Text(tier.rawValue + " League")
                .font(.system(.title2, design: .rounded).weight(.bold))

            // Next tier hint
            if tier != .diamond {
                Text("\(xp.xpToNextTier) XP to \(nextTierName())")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Maximum tier reached 👑")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - XP Progress

    private var xpProgressSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("XP Progress")
                    .font(.headline)
                Spacer()
                Text("\(xp.totalXP) XP  ·  Level \(xp.currentLevel)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: tierGradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(xp.tierProgress))
                        .animation(.spring(response: 0.8, dampingFraction: 0.75), value: xp.tierProgress)
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            // Tier labels
            HStack {
                Text(xp.currentTier.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if xp.currentTier != .diamond {
                    Text(nextTierName())
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                Spacer()
                Text("Top 25 · \(xp.currentTier.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Find user rank
            let userRank = entries.first(where: { $0.isCurrentUser })?.id ?? 0
            let promotionZone = 10
            let demotionZone  = 20

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in

                    // Promotion zone divider
                    if entry.id == promotionZone + 1 {
                        zoneDivider(
                            label: "Promotion Zone",
                            color: .green,
                            systemImage: "arrow.up.circle.fill"
                        )
                    }

                    // Demotion zone divider
                    if entry.id == demotionZone + 1 {
                        zoneDivider(
                            label: "Demotion Zone",
                            color: .red,
                            systemImage: "arrow.down.circle.fill"
                        )
                    }

                    leaderboardRow(entry: entry, promotionZone: promotionZone, demotionZone: demotionZone)
                }
            }
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func leaderboardRow(entry: LeaderboardEntry, promotionZone: Int, demotionZone: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Text("\(entry.id)")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .foregroundColor(entry.id <= 3 ? .primary : .secondary)
                .frame(width: 28, alignment: .leading)

            // Avatar
            ZStack {
                Circle()
                    .fill(entry.isCurrentUser ? Color.green.opacity(0.3) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                Text(entry.emoji)
                    .font(.title3)
            }

            // Name + XP
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(entry.isCurrentUser ? .primary : .primary)
                Text("\(entry.xp) XP")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Medal for top 3
            if entry.id == 1 { Text("🥇").font(.title3) }
            else if entry.id == 2 { Text("🥈").font(.title3) }
            else if entry.id == 3 { Text("🥉").font(.title3) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(entry.isCurrentUser ? Color.green.opacity(0.08) : Color.clear)
        .overlay(
            entry.isCurrentUser ?
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
            : nil
        )
    }

    @ViewBuilder
    private func zoneDivider(label: String, color: Color, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
            Rectangle()
                .fill(color.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(color.opacity(0.05))
    }

    // MARK: - Leaderboard Generation
    //
    // ── Supabase migration point ──────────────────────────────────────────
    // Replace this entire function with:
    //   let rows = try await supabase.from("xp").select("username,emoji,xp")
    //               .order("xp", ascending: false).limit(25).execute()
    //   return rows.map { LeaderboardEntry(id: rank, name: $0.username, ...) }
    // ─────────────────────────────────────────────────────────────────────
    private func generateLeaderboard() -> [LeaderboardEntry] {
        let userXP   = xp.totalXP
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "You"
        let userEmoji = UserDefaults.standard.string(forKey: "userEmoji") ?? "🚗"

        let botNames = [
            ("Marco R.",    "🦊"), ("Sofia B.",   "🐧"), ("Luca M.",    "🦁"),
            ("Giulia T.",   "🐼"), ("Andrea C.",  "🐨"), ("Valentina F.","🦋"),
            ("Alessandro V.","🐯"), ("Chiara M.", "🦅"), ("Matteo R.",  "🐸"),
            ("Elena P.",    "🦊"), ("Roberto G.", "🐺"), ("Francesca L.","🦄"),
            ("Davide C.",   "🐻"), ("Sara N.",    "🦝"), ("Giorgio M.", "🐙"),
            ("Laura R.",    "🦜"), ("Simone T.",  "🐬"), ("Anna C.",    "🦈"),
            ("Paolo B.",    "🐊"), ("Martina F.", "🦓"), ("Stefano R.", "🦍"),
            ("Claudia M.",  "🦧"), ("Riccardo P.","🦣"), ("Monica T.",  "🐘"),
        ]

        // Place user at a realistic rank (top third of the league)
        let targetRank = max(4, Int.random(in: 4...12))

        var allEntries: [(name: String, emoji: String, xp: Int, isUser: Bool)] = []

        // Add user
        allEntries.append((userName, userEmoji, userXP, true))

        // Generate bots with XP spread around the user
        for (idx, bot) in botNames.enumerated() {
            let rank = idx + 1  // 1-based before sorting
            let spread = 25     // XP variance between adjacent ranks
            let xpOffset = (targetRank - rank) * spread
            let botXP = max(0, userXP + xpOffset + Int.random(in: -10...10))
            allEntries.append((bot.0, bot.1, botXP, false))
        }

        // Sort by XP descending and assign ranks
        let sorted = allEntries.sorted { $0.xp > $1.xp }
        return sorted.enumerated().map { idx, entry in
            LeaderboardEntry(
                id: idx + 1,
                name: entry.name,
                emoji: entry.emoji,
                xp: entry.xp,
                isCurrentUser: entry.isUser
            )
        }
    }

    // MARK: - Helpers

    private func nextTierName() -> String {
        let tier = xp.currentTier
        guard let idx = LeagueTier.allCases.firstIndex(of: tier),
              idx + 1 < LeagueTier.allCases.count else { return "" }
        return LeagueTier.allCases[idx + 1].rawValue
    }

    private var tierGradientColors: [Color] {
        let (top, bot) = xp.currentTier.color
        return [Color(hex: top), Color(hex: bot)]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LeagueView()
            .navigationTitle("League")
            .navigationBarTitleDisplayMode(.inline)
    }
}
