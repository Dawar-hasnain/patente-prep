//
//  MainTabView.swift
//  Patente-Learning
//
//  The root tab shell shown after authentication (any state).
//
//  New in this version:
//    • Receives AuthManager as @EnvironmentObject (injected from RootView).
//    • Hosts a MilestoneTracker that fires SaveProgressPromptView as a bottom sheet
//      for guest users after meaningful learning events.
//    • A guest indicator badge in the Profile tab nudges users to sign in.
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Environment
    @EnvironmentObject private var auth: AuthManager

    // MARK: - State
    @State private var showResetAlert        = false
    @State private var showAboutSheet        = false
    @State private var showEditProfile       = false
    @State private var showShareSheet        = false
    @State private var exportFileURL: URL?
    @State private var showSavePrompt        = false
    @State private var showStreakAtRisk      = false

    // Prevent showing the streak alert more than once per calendar day
    @AppStorage("lastStreakAlertDate") private var lastStreakAlertDate = ""

    // MilestoneTracker decides when to surface the save-progress sheet
    @StateObject private var milestoneTracker = MilestoneTracker()

    var body: some View {
        TabView {

            // ── 🏠 Home ──────────────────────────────────────────────────────
            NavigationStack {
                ChapterPathView()
                    .navigationTitle("Home")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showResetAlert = true
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .accessibilityLabel("Reset Progress")
                        }
                    }
                    .alert("Reset All Progress?", isPresented: $showResetAlert) {
                        Button("Reset", role: .destructive) {
                            ProgressManager.shared.resetAllProgress()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will erase all learned words, progress, and streaks. This action cannot be undone.")
                    }
            }
            .tabItem { Label("Home", systemImage: "house.fill") }

            // ── 🏆 League ────────────────────────────────────────────────────
            NavigationStack {
                LeagueView()
                    .navigationTitle("League")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("League", systemImage: "trophy.fill") }

            // ── 🧠 Practice ──────────────────────────────────────────────────
            NavigationStack {
                PracticeView()
            }
            .tabItem { Label("Practice", systemImage: "brain.head.profile") }

            // ── 📊 Dashboard ─────────────────────────────────────────────────
            NavigationStack {
                ProgressDashboardView()
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { exportUserSummary() } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export Summary")
                        }
                    }
                    .sheet(isPresented: $showShareSheet) {
                        if let url = exportFileURL {
                            ActivityView(activityItems: [url])
                        }
                    }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

            // ── 👤 Profile ───────────────────────────────────────────────────
            NavigationStack {
                UserProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showEditProfile = true } label: {
                                Image(systemName: "pencil")
                            }
                            .accessibilityLabel("Edit Profile")
                        }
                    }
                    .sheet(isPresented: $showEditProfile) {
                        EditProfileView()
                    }
            }
            .tabItem {
                // Show a badge dot on Profile when user is a guest
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .badge(auth.isGuest ? "!" : nil)

            // ── ⚙️ Settings ──────────────────────────────────────────────────
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showAboutSheet = true } label: {
                                Image(systemName: "info.circle")
                            }
                            .accessibilityLabel("About App")
                        }
                    }
                    .sheet(isPresented: $showAboutSheet) {
                        AboutView()
                    }
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
        // ── Streak-at-risk full-screen overlay ───────────────────────────────
        .fullScreenCover(isPresented: $showStreakAtRisk) {
            StreakAtRiskView(
                onKeepAlive: { showStreakAtRisk = false },
                onDismiss:   { showStreakAtRisk = false },
                onFreezeUsed: { showStreakAtRisk = false }
            )
        }
        // ── Save-Progress prompt (bottom sheet for guests) ───────────────────
        .sheet(isPresented: $showSavePrompt) {
            SaveProgressPromptView(isPresented: $showSavePrompt)
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)   // we draw our own handle
        }
        // ── Milestone check on appear and after any learning event ───────────
        .onAppear {
            checkMilestone()
            checkStreakAtRisk()
        }
        // Re-check whenever authState changes (e.g. after coming back from background)
        .onChange(of: auth.authState) { _ in checkMilestone() }
        // Notification posted by WordLearningView after markAsLearned()
        .onReceive(NotificationCenter.default.publisher(for: .didLearnWord)) { _ in
            checkMilestone()
        }
    }

    // MARK: - Streak-at-risk check

    private func checkStreakAtRisk() {
        let streak = ProgressManager.shared.currentStreak()
        guard streak >= 2 else { return }

        // Has the user already practiced today?
        let calendar  = Calendar.current
        let lastActive = ProgressManager.shared.lastActiveDate()
        let practicedToday = lastActive.map { calendar.isDateInToday($0) } ?? false
        guard !practicedToday else { return }

        // Only show once per calendar day
        let today = {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        guard lastStreakAlertDate != today else { return }

        lastStreakAlertDate = today
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showStreakAtRisk = true
        }
    }

    // MARK: - Milestone check

    private func checkMilestone() {
        guard milestoneTracker.shouldShow(authState: auth.authState) else { return }
        // Brief delay so it doesn't clash with any in-progress animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSavePrompt = true
        }
    }

    // MARK: - Export

    private func exportUserSummary() {
        let manager = ProgressManager.shared
        let summary = """
        📊 Sorpasso Summary
        ---------------------------
        Total Words Learned:     \(manager.totalLearnedWords())
        Average Recall Accuracy: \(Int(manager.averageRecallAccuracy() * 100))%
        Current Streak:          \(manager.currentStreak()) days
        Best Streak:             \(manager.bestStreak()) days
        Chapters Completed:      \(ChapterList.allCases.filter { manager.progress(for: $0) >= 1.0 }.count)
        """

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SorpassoSummary.txt")
        try? summary.write(to: fileURL, atomically: true, encoding: .utf8)
        exportFileURL = fileURL
        showShareSheet = true
    }
}

// MARK: - Notification name

extension Notification.Name {
    /// Posted by WordLearningView whenever a word is marked as learned.
    /// MainTabView listens to this to re-evaluate milestones without tight coupling.
    static let didLearnWord = Notification.Name("didLearnWord")
}
