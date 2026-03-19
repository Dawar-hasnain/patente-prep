//
//  LessonCompletionView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//  Updated 17/03/26 — Added weekly streak dots and XP display.
//

import SwiftUI

struct LessonCompletionView: View {
    let chapter: ChapterList
    let lessonIndex: Int
    let correctAnswers: Int
    let totalWords: Int
    let onContinue: () -> Void
    let onNextLesson: (() -> Void)?

    // ── Animation state ───────────────────────────────────────────────────
    @State private var scaleIcon    = false
    @State private var showContent  = false
    @State private var showStreak   = false
    @State private var showButtons  = false
    @State private var particlesBurst = false

    private let streak = ProgressManager.shared.currentStreak()

    // XP already awarded by WordLearningView before this screen appears
    private var xpEarned: Int {
        let ratio = Double(correctAnswers) / Double(totalWords)
        return ratio == 1.0 ? XPAward.lessonCompleted(perfectScore: true).amount
                             : XPAward.lessonCompleted(perfectScore: false).amount
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ParticleBurstView(active: $particlesBurst)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icon ──────────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.25), Color.green.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(scaleIcon ? 1.0 : 0.3)
                        .opacity(scaleIcon ? 1.0 : 0.0)
                }
                .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 8)
                .padding(.bottom, 20)

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("Lesson \(lessonIndex + 1) Complete!")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)

                    Text(chapter.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 16)
                .padding(.bottom, 20)

                // ── XP + Score stat row ───────────────────────────────────
                HStack(spacing: 12) {
                    // XP earned
                    statBadge(
                        icon: "star.fill",
                        value: "+\(xpEarned)",
                        label: "XP Earned",
                        color: .yellow
                    )

                    // Correct answers
                    statBadge(
                        icon: "brain.head.profile",
                        value: "\(correctAnswers)/\(totalWords)",
                        label: "Correct",
                        color: scoreColor
                    )

                    // Streak
                    if streak > 0 {
                        statBadge(
                            icon: "flame.fill",
                            value: "\(streak)",
                            label: "Day Streak",
                            color: .orange
                        )
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)

                // ── Score message ─────────────────────────────────────────
                Text(scoreMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(showContent ? 1 : 0)
                    .padding(.bottom, 20)

                // ── Weekly streak dots ────────────────────────────────────
                weeklyStreakDots
                    .padding(.horizontal, 28)
                    .opacity(showStreak ? 1 : 0)
                    .offset(y: showStreak ? 0 : 10)
                    .padding(.bottom, 24)

                Spacer()

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 14) {
                    if let next = onNextLesson {
                        Button(action: next) {
                            HStack(spacing: 10) {
                                Text("Next Lesson")
                                    .font(.headline)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.accentColor))
                            .foregroundColor(.white)
                        }
                    }

                    Button(action: onContinue) {
                        Text(onNextLesson == nil ? "Continue" : "Back to Map")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.secondary.opacity(0.12)))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
                .opacity(showButtons ? 1 : 0)
                .offset(y: showButtons ? 0 : 20)
            }
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Weekly Streak Dots

    private var weeklyStreakDots: some View {
        let days = weekDays()

        return VStack(spacing: 10) {
            Text("WEEKLY STREAK")
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .tracking(1)

            HStack(spacing: 0) {
                ForEach(days, id: \.label) { day in
                    ZStack {
                        if day.isToday {
                            // Today — just earned, show as filled green
                            Circle()
                                .fill(Color.green)
                                .frame(width: 36, height: 36)
                            Text(day.label)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.white)
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
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private func weekDays() -> [(label: String, isActive: Bool, isToday: Bool)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2   // Monday = 2 in Gregorian
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"

        // Find the Monday that starts this ISO week
        let weekday = calendar.component(.weekday, from: today)
        // Convert to Mon=0 … Sun=6 offset
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: monday)!
            let label = formatter.string(from: day).uppercased()
            let isToday = calendar.isDateInToday(day)
            let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
            // Today counts as active since the user just completed a lesson
            let isActive = isToday || (!isToday && daysAgo < streak && daysAgo >= 0)
            return (label, isActive, isToday)
        }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            scaleIcon = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            particlesBurst = true
            HapticsManager.success()
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            showContent = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            showStreak = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.65)) {
            showButtons = true
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        let ratio = Double(correctAnswers) / Double(totalWords)
        if ratio >= 0.875 { return .green }
        if ratio >= 0.625 { return .orange }
        return .red
    }

    private var scoreMessage: String {
        let ratio = Double(correctAnswers) / Double(totalWords)
        switch ratio {
        case 1.0:      return "Perfect score! Eccellente! 🌟"
        case 0.875...: return "Ottimo lavoro! Almost perfect 🎯"
        case 0.625...: return "Bene! Keep up the practice 💪"
        default:       return "Don't worry — review will help these stick 🔁"
        }
    }

    @ViewBuilder
    private func statBadge(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Particle Burst

struct ParticleBurstView: View {
    @Binding var active: Bool
    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let angle: Double
        let speed: CGFloat
    }

    private let colors: [Color] = [.green, .blue, .orange, .yellow, .mint, .purple]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: p.size, height: p.size)
                        .position(x: p.x, y: p.y)
                        .opacity(active ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.2).delay(Double.random(in: 0...0.3)),
                            value: active
                        )
                }
            }
            .onAppear {
                let cx = geo.size.width / 2
                let cy = geo.size.height * 0.35
                particles = (0..<40).map { _ in
                    let angle = Double.random(in: 0...(2 * .pi))
                    let speed = CGFloat.random(in: 60...220)
                    return Particle(
                        color: colors.randomElement()!,
                        x: cx + cos(angle) * speed,
                        y: cy + sin(angle) * speed,
                        size: CGFloat.random(in: 5...12),
                        angle: angle,
                        speed: speed
                    )
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Full Score") {
    LessonCompletionView(
        chapter: .la_strada,
        lessonIndex: 0,
        correctAnswers: 8,
        totalWords: 8,
        onContinue: { },
        onNextLesson: { }
    )
}

#Preview("Partial Score – No Next Lesson") {
    LessonCompletionView(
        chapter: .segnaletica_stradale,
        lessonIndex: 2,
        correctAnswers: 5,
        totalWords: 8,
        onContinue: { },
        onNextLesson: nil
    )
}
