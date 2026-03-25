//
//  StreakAtRiskView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Shown once per day when the user opens the app without having
//  practiced today, and has a streak worth protecting (≥ 2 days).
//

import SwiftUI
import Combine

struct StreakAtRiskView: View {
    let onKeepAlive:  () -> Void          // dismiss and go learn
    let onDismiss:    () -> Void          // "maybe later"
    var onFreezeUsed: (() -> Void)? = nil // called after a freeze is successfully applied

    // ── State ─────────────────────────────────────────────────────────────
    @State private var timeRemaining: TimeInterval = 0
    @State private var flicker        = false
    @State private var freezeCount    = ProgressManager.shared.streakFreezeCount
    @State private var xpBalance      = XPManager.shared.totalXP
    @State private var freezeApplied  = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let streak = ProgressManager.shared.currentStreak()

    @ScaledMetric(relativeTo: .largeTitle) private var flameEmojiSize: CGFloat = 100

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("Streak\nat Risk!")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)

                    Text("Don't let your hard work fade away.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 32)

                // ── Dimmed flickering flame ───────────────────────────────
                Text("🔥")
                    .font(.system(size: flameEmojiSize))
                    .opacity(flicker ? 0.2 : 0.3)
                    .scaleEffect(flicker ? 0.95 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: flicker
                    )
                    .grayscale(1.0)
                    .padding(.bottom, 28)

                // ── Countdown ─────────────────────────────────────────────
                VStack(spacing: 6) {
                    Text("RESETS IN")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.red)
                        .tracking(1.5)

                    Text(formattedCountdown)
                        .font(.system(.title, design: .monospaced).weight(.black))
                        .foregroundColor(.red)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.red.opacity(0.2), lineWidth: 1.5)
                        )
                )
                .padding(.bottom, 24)

                // ── Streak stat ───────────────────────────────────────────
                VStack(spacing: 6) {
                    Text("CURRENT STREAK")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                        .tracking(1)

                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundColor(Color.gray.opacity(0.4))
                        Text("\(streak)")
                            .font(.system(.title, design: .rounded).weight(.black))
                            .foregroundColor(Color.gray.opacity(0.5))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

                // ── Weekly dot tracker ────────────────────────────────────
                weeklyDotTracker
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

                Spacer()

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 12) {

                    // Primary: keep streak alive by learning
                    Button(action: onKeepAlive) {
                        Text("KEEP STREAK ALIVE")
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange)
                                    .shadow(color: .orange.opacity(0.4), radius: 6, y: 4)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    // Secondary: use a streak freeze (if owned)
                    if freezeApplied {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.blue)
                            Text("Streak protected for today 🧊")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 6)

                    } else if freezeCount > 0 {
                        Button {
                            applyFreeze()
                        } label: {
                            HStack(spacing: 8) {
                                Text("🧊")
                                Text("Use Freeze  (\(freezeCount) left)")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1.5)
                                    )
                            )
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                    } else if xpBalance >= XPManager.streakFreezeCost {
                        Button {
                            if XPManager.shared.purchaseStreakFreeze() {
                                xpBalance   = XPManager.shared.totalXP
                                freezeCount = ProgressManager.shared.streakFreezeCount
                                applyFreeze()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("🧊")
                                Text("Buy Freeze — \(XPManager.streakFreezeCost) XP")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1.5)
                                    )
                            )
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onDismiss) {
                        Text("Maybe later")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .underline()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            flicker = true
            updateCountdown()
        }
        .onReceive(timer) { _ in
            updateCountdown()
        }
    }

    // MARK: - Weekly Dot Tracker

    private var weeklyDotTracker: some View {
        let days = weekDays()

        return VStack(spacing: 10) {
            Text("WEEKLY PROGRESS")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .tracking(1)

            HStack(spacing: 0) {
                ForEach(days, id: \.label) { day in
                    VStack(spacing: 6) {
                        ZStack {
                            if day.isToday && !day.isFrozen {
                                // Dashed red circle — not yet earned
                                Circle()
                                    .stroke(
                                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                                    )
                                    .foregroundColor(.red)
                                    .frame(width: 36, height: 36)
                                Text(day.label)
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.red)
                            } else if day.isFrozen {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(Circle().strokeBorder(Color.blue.opacity(0.4), lineWidth: 1.5))
                                Text("🧊")
                                    .font(.system(size: 16))
                            } else if day.isActive {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 36, height: 36)
                                Text(day.label)
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(day.label)
                                    .font(.caption2.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private func applyFreeze() {
        guard ProgressManager.shared.useStreakFreeze() else { return }
        withAnimation { freezeApplied = true }
        freezeCount = ProgressManager.shared.streakFreezeCount
        HapticsManager.success()
        // Auto-dismiss after a brief moment so the user sees the confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onFreezeUsed?()
            onDismiss()
        }
    }

    private var formattedCountdown: String {
        let h = Int(timeRemaining) / 3600
        let m = (Int(timeRemaining) % 3600) / 60
        let s = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func updateCountdown() {
        let calendar = Calendar.current
        let now = Date()
        guard let midnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return }
        timeRemaining = max(0, midnight.timeIntervalSince(now))
    }

    /// Builds the 7-day row relative to today.
    private func weekDays() -> [(label: String, isActive: Bool, isToday: Bool, isFrozen: Bool)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2   // Monday = 2 in Gregorian
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"   // single letter: M T W T F S S
        let dateKeyFormatter = DateFormatter()
        dateKeyFormatter.dateFormat = "yyyy-MM-dd"

        // Find the Monday that starts this ISO week
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let label = formatter.string(from: day).uppercased()
            let isToday = calendar.isDateInToday(day)
            let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            let isActive = !isToday && daysAgo >= 0 && daysAgo < streak
            let dateKey = dateKeyFormatter.string(from: day)
            let isFrozen = ProgressManager.shared.isDateFrozen(dateKey)
            return (label, isActive, isToday, isFrozen)
        }
    }
}

// MARK: - Preview

#Preview("Streak at Risk") {
    StreakAtRiskView(
        onKeepAlive: { print("Keep alive") },
        onDismiss: { print("Dismissed") }
    )
}
