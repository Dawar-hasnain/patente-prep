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

// MARK: - Daily Goal

/// How many XP the user wants to earn each day.
enum DailyGoal: Int, CaseIterable, Identifiable {
    case casual  = 10
    case regular = 20
    case intense = 30

    var id: Int { rawValue }

    /// XP target for the day.
    var target: Int { rawValue }

    var label: String {
        switch self {
        case .casual:  return "Casual"
        case .regular: return "Regular"
        case .intense: return "Intense"
        }
    }

    var description: String {
        switch self {
        case .casual:  return "10 XP · Light daily sessions"
        case .regular: return "20 XP · Steady daily habit"
        case .intense: return "30 XP · Full commitment"
        }
    }

    /// SF Symbol name for icon in Settings.
    var iconName: String {
        switch self {
        case .casual:  return "leaf.fill"
        case .regular: return "flame.fill"
        case .intense: return "bolt.fill"
        }
    }
}

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
    case mockExamPassed

    var amount: Int {
        switch self {
        case .lessonCompleted(let perfect): return perfect ? 25 : 20
        case .reviewPassed:                 return 15
        case .chapterMastered:              return 50
        case .mockExamPassed:               return 100
        }
    }

    var label: String {
        switch self {
        case .lessonCompleted(let perfect): return perfect ? "+25 XP (Perfect!)" : "+20 XP"
        case .reviewPassed:                 return "+15 XP"
        case .chapterMastered:              return "+50 XP"
        case .mockExamPassed:               return "+100 XP (Exam Passed!)"
        }
    }
}

// MARK: - XPManager

final class XPManager {
    static let shared = XPManager()
    private init() {}

    private let defaults      = UserDefaults.standard
    private let xpKey         = "totalXP"
    private let dailyGoalKey  = "dailyGoalXP"
    private let dailyDateKey  = "dailyXPDate"
    private let dailyEarnedKey = "dailyXPEarned"

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

    // MARK: - Daily Goal

    var dailyGoal: DailyGoal {
        get { DailyGoal(rawValue: defaults.integer(forKey: dailyGoalKey)) ?? .regular }
        set { defaults.set(newValue.rawValue, forKey: dailyGoalKey) }
    }

    /// XP earned today (resets automatically at midnight).
    var todayXP: Int {
        guard defaults.string(forKey: dailyDateKey) == todayDateString else { return 0 }
        return defaults.integer(forKey: dailyEarnedKey)
    }

    /// 0.0–1.0 progress toward today's goal (capped at 1.0).
    var dailyGoalProgress: Double {
        min(1.0, Double(todayXP) / Double(dailyGoal.target))
    }

    var dailyGoalMet: Bool { todayXP >= dailyGoal.target }

    private var todayDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func recordDailyXP(_ amount: Int) {
        let today   = todayDateString
        let stored  = defaults.string(forKey: dailyDateKey)
        let existing = (stored == today) ? defaults.integer(forKey: dailyEarnedKey) : 0
        defaults.set(today,            forKey: dailyDateKey)
        defaults.set(existing + amount, forKey: dailyEarnedKey)
    }

    // MARK: - Award

    @discardableResult
    func award(_ type: XPAward) -> Int {
        let amount   = type.amount
        let newTotal = totalXP + amount
        // ── Supabase migration point ──────────────────────────────────────
        // Replace these two lines with: supabase.upsert("xp", newTotal, for: userId)
        defaults.set(newTotal, forKey: xpKey)
        // ─────────────────────────────────────────────────────────────────
        recordDailyXP(amount)
        return amount
    }

    /// Deduct XP (e.g. for heart refills). Returns false if insufficient balance.
    @discardableResult
    func spendXP(_ amount: Int) -> Bool {
        let current = totalXP   // single read to avoid race
        guard current >= amount else { return false }
        defaults.set(current - amount, forKey: xpKey)
        return true
    }

    // MARK: - Reset (called by ProgressManager.resetAllProgress)

    func resetXP() {
        defaults.removeObject(forKey: xpKey)
        defaults.removeObject(forKey: dailyDateKey)
        defaults.removeObject(forKey: dailyEarnedKey)
    }
}
