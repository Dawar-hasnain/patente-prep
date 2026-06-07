//
//  MainTabView.swift
//  Patente-Learning
//
//  The root tab shell shown after authentication (any state).
//
//  Exam-prep flow:
//    • Study     → browse chapters/Blocchi → ConceptCard → True/False practice
//    • Practice  → Mock Exam + targeted weak-question review
//    • Profile   → readiness + exam stats
//    • Settings  → preferences
//
//  Hosts a MilestoneTracker that fires SaveProgressPromptView as a bottom sheet
//  for guest users after meaningful practice.
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Environment
    @EnvironmentObject private var auth: AuthManager

    // MARK: - State
    @State private var showSavePrompt = false

    // MilestoneTracker decides when to surface the save-progress sheet
    @StateObject private var milestoneTracker = MilestoneTracker()

    var body: some View {
        TabView {

            // ── 📚 Study ─────────────────────────────────────────────────────
            NavigationStack {
                ExamPrepHomeView()
            }
            .tabItem { Label("Study", systemImage: "books.vertical.fill") }

            // ── 🧠 Practice ──────────────────────────────────────────────────
            NavigationStack {
                PracticeView()
            }
            .tabItem { Label("Practice", systemImage: "brain.head.profile") }

            // ── 👤 Profile ───────────────────────────────────────────────────
            NavigationStack {
                UserProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            .badge(auth.isGuest ? "!" : nil)

            // ── ⚙️ Settings ──────────────────────────────────────────────────
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.accentColor)
        // ── Save-Progress prompt (bottom sheet for guests) ───────────────────
        .sheet(isPresented: $showSavePrompt) {
            SaveProgressPromptView(isPresented: $showSavePrompt)
                .environmentObject(auth)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)   // we draw our own handle
        }
        // ── Milestone check on appear and when auth state changes ────────────
        .onAppear { checkMilestone() }
        .onChange(of: auth.authState) { _ in checkMilestone() }
    }

    // MARK: - Milestone check

    private func checkMilestone() {
        guard milestoneTracker.shouldShow(authState: auth.authState) else { return }
        // Brief delay so it doesn't clash with any in-progress animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSavePrompt = true
        }
    }
}
