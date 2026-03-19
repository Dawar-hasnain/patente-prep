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
    let onKeepAlive: () -> Void   // dismiss and focus user on learning
    let onDismiss: () -> Void     // "maybe later"

    // ── State ─────────────────────────────────────────────────────────────
    @State private var timeRemaining: TimeInterval = 0
    @State private var flicker = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let streak = ProgressManager.shared.currentStreak()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("Streak\nat Risk!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
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
                    .font(.system(size: 100))
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
                        .font(.system(size: 36, weight: .black, design: .monospaced))
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
                            .font(.system(size: 40, weight: .black, design: .rounded))
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
                            if day.isToday {
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
    /// Active = the day is within the current streak window.
    private func weekDays() -> [(label: String, isActive: Bool, isToday: Bool)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2   // Monday = 2 in Gregorian
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"   // single letter: M T W T F S S

        // Find the Monday that starts this ISO week
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let label = formatter.string(from: day).uppercased()
            let isToday = calendar.isDateInToday(day)
            let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            // Active = within streak window, but not today (not yet earned in StreakAtRisk)
            let isActive = !isToday && daysAgo >= 0 && daysAgo < streak
            return (label, isActive, isToday)
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
