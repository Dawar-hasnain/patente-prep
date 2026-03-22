//
//  UserProfileView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//  Restructured 17/03/26 — merged with ProgressDashboardView.
//

import SwiftUI

struct UserProfileView: View {
    // ── Identity ──────────────────────────────────────────────────────────
    @AppStorage("userName")  private var userName:  String = "Learner"
    @AppStorage("userEmoji") private var userEmoji: String = "🚗"

    // ── Stats ─────────────────────────────────────────────────────────────
    @State private var totalLearnedWords  = 0
    @State private var masteredChapters   = 0
    @State private var averageScore       = 0.0
    @State private var recallAccuracy     = 0.0
    @State private var currentStreak      = 0
    @State private var bestStreak         = 0
    @State private var lastActive: Date?  = nil
    @State private var progressDict: [ChapterList: Double] = [:]
    @State private var activityLog: [String: Int] = [:]  // "yyyy-MM-dd" -> wordsLearned

    // ── UI state ──────────────────────────────────────────────────────────
    @State private var pulse = false
    @State private var showUnlockAlert = false
    @State private var showEditProfile = false

    @ScaledMetric(relativeTo: .largeTitle) private var avatarEmojiSize: CGFloat = 72

    private let manager = ProgressManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // ── 1. Identity Header ────────────────────────────────────
                identityHeader

                // ── 2. Stat Cards ─────────────────────────────────────────
                statCardsRow

                Divider().padding(.horizontal)

                // ── 3. Streak ─────────────────────────────────────────────
                streakSection

                // ── 4. Activity Heatmap ───────────────────────────────────
                activityHeatmapSection

                Divider().padding(.horizontal)

                // ── 5. Achievements ───────────────────────────────────────
                achievementsSection

                Divider().padding(.horizontal)

                // ── 6. Chapter Breakdown ──────────────────────────────────
                chapterBreakdownSection

                Divider().padding(.horizontal)

                // ── 7. Actions ────────────────────────────────────────────
                actionsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear(perform: reloadData)
        .sheet(isPresented: $showEditProfile, onDismiss: reloadData) {
            EditProfileView()
        }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Text(userEmoji)
                    .font(.system(size: avatarEmojiSize))
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.appBackground))
                }
            }

            Text(userName)
                .font(.title2.bold())

            Text("Your Sorpasso Journey")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Last active
            if let date = lastActive {
                Text("Last active \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stat Cards

    private var statCardsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Words",    value: "\(totalLearnedWords)")
            statCard(title: "Chapters", value: "\(masteredChapters)/\(ChapterList.allCases.count)")
            statCard(title: "Avg Score",value: "\(Int(averageScore * 100))%")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(currentStreak > 0 ? .orange : .gray.opacity(0.4))
                    .font(.title2)
                    .scaleEffect(pulse ? 1.1 : 1.0)

                if currentStreak > 0 {
                    Text("\(currentStreak)-day streak")
                        .font(.headline.weight(.semibold))
                } else {
                    Text("No streak yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                if bestStreak > currentStreak && bestStreak > 0 {
                    Text("(Best: \(bestStreak))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text(motivationalMessage(for: currentStreak))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .orange.opacity(0.12), radius: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: - Activity Heatmap

    private var activityHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.headline)
                Spacer()
                Text("Last 28 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Day-of-week header
            HStack(spacing: 0) {
                ForEach(["M","T","W","T","F","S","S"], id: \.self) { d in
                    Text(d)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 4 rows × 7 columns grid
            let days = heatmapDays()
            let rows = days.chunked(into: 7)
            VStack(spacing: 5) {
                ForEach(rows.indices, id: \.self) { rowIdx in
                    HStack(spacing: 5) {
                        ForEach(rows[rowIdx], id: \.date) { cell in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(heatmapColor(for: cell.count))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("Less")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                ForEach([0, 1, 5, 10, 20], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(for: level))
                        .frame(width: 12, height: 12)
                }
                Text("More")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .glassCard()
    }

    private func heatmapDays() -> [(date: String, count: Int)] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        // Go back to Monday 4 weeks ago
        let startMonday = calendar.date(byAdding: .day, value: -(daysFromMonday + 21), to: today)!

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return (0..<28).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startMonday)!
            let key = formatter.string(from: day)
            return (date: key, count: activityLog[key] ?? 0)
        }
    }

    private func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0:       return Color.secondary.opacity(0.12)
        case 1...4:   return Color.green.opacity(0.3)
        case 5...9:   return Color.green.opacity(0.55)
        case 10...19: return Color.green.opacity(0.75)
        default:      return Color.green.opacity(0.95)
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Achievements")
                .font(.headline)

            let badges: [(condition: Bool, icon: String, color: Color, label: String)] = [
                (totalLearnedWords >= 50,  "rosette",     .accentColor, "50 Words"),
                (totalLearnedWords >= 100, "star.fill",   .yellow,      "100 Words"),
                (totalLearnedWords >= 500, "trophy.fill", .orange,      "500 Words"),
                (bestStreak >= 3,          "flame.fill",  .orange,      "3-Day Streak"),
                (bestStreak >= 7,          "crown.fill",  .purple,      "7-Day Streak"),
                (masteredChapters >= 1,    "book.closed.fill", .green,  "1st Chapter"),
            ]

            let earned = badges.filter { $0.condition }

            if earned.isEmpty {
                Text("Complete lessons and maintain streaks to earn achievements.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(earned.indices, id: \.self) { i in
                        let badge = earned[i]
                        VStack(spacing: 6) {
                            Image(systemName: badge.icon)
                                .font(.title2)
                                .foregroundColor(badge.color)
                            Text(badge.label)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // MARK: - Chapter Breakdown

    private var chapterBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters Overview")
                .font(.headline)

            ForEach(ChapterList.allCases) { chapter in
                let progress   = progressDict[chapter] ?? 0
                let isMastered = manager.isChapterMastered(chapter)
                let completed  = LessonManager.completedLessonCount(for: chapter)
                let total      = LessonManager.totalLessonCount(for: chapter)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(chapter.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if isMastered {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                        }
                        Text("\(completed)/\(total) lessons")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(isMastered ? .yellow : .blue)
                        .scaleEffect(x: 1, y: 1.8)
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    Text(
                        isMastered        ? "Mastered ✅" :
                        progress >= 0.7   ? "Ready for Final Review" :
                        progress > 0      ? "\(Int(progress * 100))% completed" :
                                            "Not started"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .glassCard()
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                manager.resetAllProgress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { reloadData() }
            } label: {
                Label("Reset All Progress", systemImage: "arrow.counterclockwise.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button {
                showUnlockAlert = true
            } label: {
                Label("Unlock All Chapters", systemImage: "lock.open.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .alert("Unlock All Chapters?", isPresented: $showUnlockAlert) {
                Button("Unlock") {
                    manager.unlockAllChaptersForTesting()
                    withAnimation(.spring()) { reloadData() }
                    HapticsManager.success()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will mark all chapters and words as learned for testing purposes.")
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Data Loading

    private func reloadData() {
        totalLearnedWords = manager.totalLearnedWords()
        masteredChapters  = manager.totalChaptersMastered()
        averageScore      = manager.averageScore()
        recallAccuracy    = manager.averageRecallAccuracy()
        currentStreak     = manager.currentStreak()
        bestStreak        = manager.bestStreak()
        lastActive        = manager.lastActiveDate()
        // Load 28 days of activity for the heatmap
        activityLog = UserDefaults.standard.dictionary(forKey: "learningActivity") as? [String: Int] ?? [:]

        var dict: [ChapterList: Double] = [:]
        for chapter in ChapterList.allCases {
            dict[chapter] = manager.progress(for: chapter)
        }
        withAnimation(.easeInOut) { progressDict = dict }
    }

    // MARK: - Helpers

    private func motivationalMessage(for streak: Int) -> String {
        switch streak {
        case 0:      return "Start learning today to begin your streak!"
        case 1:      return "Good start — consistency builds mastery"
        case 2...4:  return "You're on your way! Keep going"
        case 5...9:  return "Great habit forming!"
        case 10...20:return "Excellent streak — strong momentum!"
        default:     return "Legendary streak! You're unstoppable!"
        }
    }
}

// MARK: - Previews

#Preview("Profile") {
    NavigationStack {
        UserProfileView()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
    }
}
