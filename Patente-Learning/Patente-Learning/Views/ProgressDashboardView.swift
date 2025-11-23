//
//  ProgressDashboardView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct ProgressDashboardView: View {
    @State private var progressDict: [ChapterList: Double] = [:]
    @State private var averageScore: Double = 0
    @State private var totalLearnedWords: Int = 0
    @State private var masteredChapters: Int = 0
    @State private var lastActive: Date? = nil
    @State private var nextReview: ReviewCheckpoint? = nil
    @State private var selectedDay: String? = nil
    @State private var selectedCount: Int? = nil
    @State private var weeklyActivity: [(date: String, count: Int)] = []
    @State private var animatedCount: Double = 0
    @State private var pulse = false

    private let manager = ProgressManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 25) {

                // MARK: - Header Summary
                headerSection

                Divider().padding(.horizontal)

                // MARK: - Activity Section
                activitySection

                Divider().padding(.horizontal)
                
                // MARK: - Streak Section
                let current = manager.currentStreak()
                let best = manager.bestStreak()

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(current > 0 ? .orange : .gray.opacity(0.5))
                            .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 0)
                            .font(.title2)
                            .scaleEffect(pulse ? 1.1 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                value: pulse
                            )

                        if current > 0 {
                            Text("\(current)-day streak")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)

                        } else {
                            Text("No current streak yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }

                        if best > 0 && best > current {
                            Text("(Best: \(best))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 💬 Motivational message
                    Text(motivationalMessage(for: current))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .shadow(color: .orange.opacity(0.15), radius: 5, x: 0, y: 2)
                .onAppear { pulse = true }

                Button(action: {
                    if let firstChapter = ChapterList.allCases.first {
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.rootViewController = UIHostingController(rootView: RecallModeView(chapter: firstChapter))
                            window.makeKeyAndVisible()
                        }
                    }
                }) {
                    Label("Recall Practice", systemImage: "brain.head.profile")
                        .font(.headline)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }
                .buttonStyle(.plain)
                
                Button {
                    let weak = ProgressManager.shared.weakWords()
                    
                    // Check if there are any weak words to recall
                    if !weak.isEmpty {
                        let view = TargetedRecallView(weakStates: weak)
                        let host = UIHostingController(rootView: view)
                        
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            window.rootViewController = host
                            window.makeKeyAndVisible()
                        }
                    } else {
                        // Optionally show an alert or message indicating no weak words
                        print("No weak words to review.")
                    }
                } label: {
                    Label("Review Weak Words", systemImage: "exclamationmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)


                // MARK: - Weekly Activity Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly Activity")
                        .font(.headline)
                        .padding(.bottom, 4)

                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(weeklyActivity, id: \.date) { entry in
                            VStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(entry.count > 0 ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 22, height: CGFloat(entry.count * 10).clamped(to: 10...140))
                                    .scaleEffect(selectedDay == entry.date ? 1.15 : 1.0)
                                    .shadow(
                                        color: selectedDay == entry.date
                                            ? Color.blue.opacity(0.5)
                                            : .clear,
                                        radius: 6, x: 0, y: 0
                                    )
                                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: selectedDay)
                                    .animation(.easeInOut(duration: 0.4), value: entry.count)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                                            selectedDay = entry.date
                                            selectedCount = entry.count
                                            animatedCount = Double(entry.count)
                                        }
                                    }

                                Text(shortDate(entry.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // 🔹 Display selected day's info
                    if let selectedDay = selectedDay {
                        HStack(spacing: 4) {
                            Text("📆 \(formattedDateLabel(selectedDay)):")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.secondary)

                            // Animated number counter
                            Text("\(Int(animatedCount))")
                                .font(.footnote.bold())
                                .foregroundColor(.primary)
                                .contentTransition(.numericText(value: animatedCount)) // iOS 17+
                                .animation(.easeOut(duration: 0.4), value: animatedCount)

                            Text("words learned")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .scale))
                    }

                }
                .padding()
                .glassCard()

                
                // MARK: - Chapter Breakdown
                chapterBreakdownSection
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Your Progress")
        .onAppear(perform: loadProgressData)
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 16) {
            statCard(title: "Words", value: "\(totalLearnedWords)")
            statCard(title: "Chapters", value: "\(masteredChapters)/\(ChapterList.allCases.count)")
            statCard(title: "Avg Score", value: "\(Int(averageScore * 100))%")
        }
    }

    // MARK: - Activity Section
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)

            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.orange)
                Text("Last active: \(formattedDate(lastActive))")
                    .foregroundColor(.secondary)
            }

            if let pending = manager.nextPendingReview() {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundColor(.blue)
                    Text("Next review: \(pending.chapter.title)")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("No reviews pending")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glassCard()
    }

    // MARK: - Chapter Breakdown
    private var chapterBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters Overview")
                .font(.headline)
                .padding(.bottom, 8)

            ForEach(ChapterList.allCases) { chapter in
                let progress = progressDict[chapter] ?? 0
                let isMastered = manager.isChapterMastered(chapter)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(chapter.title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if isMastered {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                        }
                    }

                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(isMastered ? .yellow : .blue)
                        .scaleEffect(x: 1, y: 2, anchor: .center)
                        .animation(.easeInOut(duration: 0.6), value: progress)

                    Text(isMastered ? "Mastered ✅" :
                         progress >= 0.7 ? "Ready for Final Review" :
                         progress > 0 ? "\(Int(progress * 100))% completed" :
                         "Not started")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .glassCard()
            }
        }
    }

    // MARK: - Helper Views
    private func statCard(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Data Loading
    private func loadProgressData() {
        totalLearnedWords = manager.totalLearnedWords()
        masteredChapters = manager.totalChaptersMastered()
        averageScore = manager.averageScore()
        lastActive = manager.lastActiveDate()

        var dict: [ChapterList: Double] = [:]
        for chapter in ChapterList.allCases {
            dict[chapter] = manager.progress(for: chapter)
        }

        withAnimation(.easeInOut) {
            progressDict = dict
        }
        
        weeklyActivity = manager.fetchWeeklyActivity()
    }
    
    private func shortDate(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateKey) {
            let short = DateFormatter()
            short.dateFormat = "E" // Mon, Tue, etc.
            return short.string(from: date)
        }
        return ""
    }
    
    private func formattedDateLabel(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateKey) {
            let out = DateFormatter()
            out.dateStyle = .medium
            return out.string(from: date)
        }
        return dateKey
    }
    
    private func motivationalMessage(for streak: Int) -> String {
        switch streak {
        case 0:
            return "Start learning today to begin your streak!"
        case 1:
            return "Good start — consistency builds mastery"
        case 2...4:
            return "You’re on your way! Keep up the momentum"
        case 5...9:
            return "Impressive! You’re building a great habit"
        case 10...20:
            return "You’re unstoppable! Your focus is paying off"
        default:
            return "Legendary streak! You’re setting the standard"
        }
    }

}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
