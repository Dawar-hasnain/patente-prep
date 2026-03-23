//
//  HeartsManager.swift
//  Patente-Learning
//
//  Manages the heart (lives) pool across sessions.
//  Hearts regenerate automatically — one every 30 minutes.
//  Users may spend 20 XP for an instant full refill.
//
//  Usage from a session view:
//    let starting = HeartsManager.shared.currentHearts   // read on session start
//    HeartsManager.shared.depleteAll()                    // called when hearts hit 0
//    HeartsManager.shared.refillWithXP()                  // called from refill button
//    HeartsManager.shared.save(hearts: remaining)         // called on successful finish
//

import Foundation

final class HeartsManager {

    static let shared = HeartsManager()
    private init() {}

    // MARK: - Constants

    static let maxHearts     = 5
    static let minutesPerHeart = 30   // one heart regenerates every 30 min
    static let xpRefillCost  = 20     // XP cost for an instant full refill

    // MARK: - UserDefaults

    private let defaults        = UserDefaults.standard
    private let heartsKey       = "hearts_count"
    private let depletedAtKey   = "hearts_depleted_at"

    // MARK: - Stored Accessors

    private var storedHearts: Int {
        get {
            let v = defaults.integer(forKey: heartsKey)
            // 0 is the UserDefaults default; treat "never set" as full hearts
            return defaults.object(forKey: heartsKey) == nil ? Self.maxHearts : v
        }
        set { defaults.set(newValue, forKey: heartsKey) }
    }

    private var depletedAt: Date? {
        get { defaults.object(forKey: depletedAtKey) as? Date }
        set {
            if let d = newValue { defaults.set(d, forKey: depletedAtKey) }
            else { defaults.removeObject(forKey: depletedAtKey) }
        }
    }

    // MARK: - Computed Hearts (with automatic regen)

    /// Hearts available right now, accounting for time-based regeneration.
    var currentHearts: Int {
        let stored = storedHearts
        guard stored < Self.maxHearts, let depletion = depletedAt else {
            return Self.maxHearts
        }

        let secondsElapsed = Date().timeIntervalSince(depletion)
        let minutesElapsed = Int(secondsElapsed / 60)
        let regenerated    = minutesElapsed / Self.minutesPerHeart

        guard regenerated > 0 else { return stored }

        let restored = min(Self.maxHearts, stored + regenerated)

        // Persist so we don't re-count from zero on next call
        storedHearts = restored
        if restored >= Self.maxHearts {
            depletedAt = nil
        } else {
            // Advance the depletion anchor by the intervals already consumed
            depletedAt = depletion.addingTimeInterval(
                TimeInterval(regenerated * Self.minutesPerHeart * 60)
            )
        }
        return restored
    }

    /// Seconds until the next single heart regenerates. 0 if hearts are full.
    var timeUntilNextHeart: TimeInterval {
        guard currentHearts < Self.maxHearts, let depletion = depletedAt else { return 0 }
        let interval  = TimeInterval(Self.minutesPerHeart * 60)
        let elapsed   = Date().timeIntervalSince(depletion)
        let remainder = interval - elapsed.truncatingRemainder(dividingBy: interval)
        return max(0, remainder)
    }

    /// True if the user can spend XP to refill.
    var canRefillWithXP: Bool {
        currentHearts < Self.maxHearts && XPManager.shared.totalXP >= Self.xpRefillCost
    }

    // MARK: - Mutations

    /// Called when a session ends with hearts = 0.
    func depleteAll() {
        storedHearts = 0
        depletedAt   = Date()
    }

    /// Called when a session completes successfully — persist remaining hearts.
    func save(hearts remaining: Int) {
        let clamped = max(0, min(Self.maxHearts, remaining))
        storedHearts = clamped
        if clamped < Self.maxHearts, depletedAt == nil {
            // Started regen from this moment
            depletedAt = Date()
        } else if clamped >= Self.maxHearts {
            depletedAt = nil
        }
    }

    /// Spend XP and restore all hearts. Returns true on success.
    @discardableResult
    func refillWithXP() -> Bool {
        guard XPManager.shared.spendXP(Self.xpRefillCost) else { return false }
        storedHearts = Self.maxHearts
        depletedAt   = nil
        return true
    }

    /// Hard reset — called by ProgressManager.resetAllProgress().
    func reset() {
        defaults.removeObject(forKey: heartsKey)
        defaults.removeObject(forKey: depletedAtKey)
    }
}
