//
//  MainTabView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//  Restructured 17/03/26 — Dashboard replaced with Practice tab.
//  Updated 17/03/26 — Streak at Risk interstitial added.
//

import SwiftUI

struct MainTabView: View {
    @State private var showResetAlert     = false
    @State private var showAboutSheet     = false
    @State private var showStreakAtRisk   = false

    var body: some View {
        TabView {

            // ── 1. Home ───────────────────────────────────────────────────
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
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will erase all learned words, progress, and streaks. This action cannot be undone.")
                    }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            // ── 2. Practice ───────────────────────────────────────────────
            NavigationStack {
                PracticeView()
                    .navigationTitle("Practice")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Practice", systemImage: "dumbbell.fill")
            }

            // ── 3. League ────────────────────────────────────────────────
            NavigationStack {
                LeagueView()
                    .navigationTitle("League")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("League", systemImage: "chart.bar.fill")
            }

            // ── 4. Profile ────────────────────────────────────────────────
            NavigationStack {
                UserProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }

            // ── 5. Settings ───────────────────────────────────────────────
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showAboutSheet = true
                            } label: {
                                Image(systemName: "info.circle")
                            }
                            .accessibilityLabel("About App")
                        }
                    }
                    .sheet(isPresented: $showAboutSheet) {
                        AboutView()
                    }
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.accentColor)
        .onAppear(perform: checkStreakAtRisk)
        .fullScreenCover(isPresented: $showStreakAtRisk) {
            StreakAtRiskView(
                onKeepAlive: { showStreakAtRisk = false },
                onDismiss:   { showStreakAtRisk = false }
            )
        }
    }

    // MARK: - Streak at Risk Logic

    private func checkStreakAtRisk() {
        let manager  = ProgressManager.shared
        let streak   = manager.currentStreak()
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        // Must have a streak worth protecting
        guard streak >= 2 else { return }

        // Must not have practiced today
        if let lastActive = manager.lastActiveDate() {
            if calendar.isDateInToday(lastActive) { return }
        }

        // Must not have already shown this screen today
        if let lastShown = defaults.object(forKey: "lastStreakRiskShown") as? Date {
            if calendar.startOfDay(for: lastShown) == today { return }
        }

        // All conditions met — show after UI settles
        defaults.set(Date(), forKey: "lastStreakRiskShown")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showStreakAtRisk = true
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
}
