//
//  XPManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Manages XP earning, level progression, and league tiers.
//  Currently backed by UserDefaults.
//  Migration path: replace the two UserDefaults calls in awardXP()
//  with a Supabase upsert and the totalXP getter with a Supabase fetch.
//

import Foundation

// MARK: - League Tier

enum LeagueTier: String, CaseIterable {
    case bronze  = "Bronze"
    case silver  = "Silver"
    case gold    = "Gold"
    case emerald = "Emerald"
    case diamond = "Diamond"

    var minXP: Int {
        switch self {
        case .bronze:  return 0
        case .silver:  return 500
        case .gold:    return 1000
        case .emerald: return 2500
        case .diamond: return 5000
        }
    }

    var maxXP: Int {
        switch self {
        case .bronze:  return 499
        case .silver:  return 999
        case .gold:    return 2499
        case .emerald: return 4999
        case .diamond: return Int.max
        }
    }

    var emoji: String {
        switch self {
        case .bronze:  return "🥉"
        case .silver:  return "🥈"
        case .gold:    return "🏆"
        case .emerald: return "💎"
        case .diamond: return "👑"
        }
    }

    var color: (String, String) {   // (top hex, bottom hex) for gradient
        switch self {
        case .bronze:  return ("CD7F32", "A0522D")
        case .silver:  return ("C0C0C0", "808080")
        case .gold:    return ("FFD700", "FFA500")
        case .emerald: return ("50C878", "2E8B57")
        case .diamond: return ("B9F2FF", "00BFFF")
        }
    }

    static func tier(for xp: Int) -> LeagueTier {
        return allCases.last { xp >= $0.minXP } ?? .bronze
    }
}

// MARK: - XP Award Types

enum XPAward {
    case lessonCompleted(perfectScore: Bool)
    case reviewPassed
    case chapterMastered

    var amount: Int {
        switch self {
        case .lessonCompleted(let perfect): return perfect ? 25 : 20
        case .reviewPassed:                 return 15
        case .chapterMastered:              return 50
        }
    }

    var label: String {
        switch self {
        case .lessonCompleted(let perfect): return perfect ? "+25 XP (Perfect!)" : "+20 XP"
        case .reviewPassed:                 return "+15 XP"
        case .chapterMastered:              return "+50 XP"
        }
    }
}

// MARK: - XPManager

final class XPManager {
    static let shared = XPManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private let xpKey    = "totalXP"

    // MARK: - Read

    var totalXP: Int {
        defaults.integer(forKey: xpKey)
    }

    var currentLevel: Int {
        totalXP / 100
    }

    var xpInCurrentLevel: Int {
        totalXP % 100
    }

    var currentTier: LeagueTier {
        LeagueTier.tier(for: totalXP)
    }

    /// XP progress within the current tier (0.0–1.0)
    var tierProgress: Double {
        let tier = currentTier
        guard tier != .diamond else { return 1.0 }
        let xpInTier  = totalXP - tier.minXP
        let tierRange = tier.maxXP - tier.minXP + 1
        return Double(xpInTier) / Double(tierRange)
    }

    /// XP needed to reach the next tier
    var xpToNextTier: Int {
        let tier = currentTier
        guard tier != .diamond else { return 0 }
        let next = LeagueTier.allCases[LeagueTier.allCases.firstIndex(of: tier)! + 1]
        return next.minXP - totalXP
    }

    // MARK: - Award

    @discardableResult
    func award(_ type: XPAward) -> Int {
        let amount = type.amount
        let newTotal = totalXP + amount
        // ── Supabase migration point ──────────────────────────────────────
        // Replace these two lines with: supabase.upsert("xp", newTotal, for: userId)
        defaults.set(newTotal, forKey: xpKey)
        // ─────────────────────────────────────────────────────────────────
        return amount
    }

    // MARK: - Reset (called by ProgressManager.resetAllProgress)

    func resetXP() {
        defaults.removeObject(forKey: xpKey)
    }
}
