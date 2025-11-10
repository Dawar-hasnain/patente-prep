//
//  MainTabView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//
import SwiftUI

struct MainTabView: View {
    // MARK: - State
    @State private var showResetAlert = false
    @State private var showAboutSheet = false
    @State private var showEditProfile = false
    @State private var showShareSheet = false
    @State private var exportFileURL: URL?
    
    var body: some View {
        TabView {
            
            // 🏠 Home
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
                    // Confirmation Alert for Reset
                    .alert("Reset All Progress?",
                           isPresented: $showResetAlert) {
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
            
            // 📊 Dashboard
            NavigationStack {
                ProgressDashboardView()
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                exportUserSummary()
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Export Summary")
                        }
                    }
                    // Share Sheet
                    .sheet(isPresented: $showShareSheet) {
                        if let exportFileURL = exportFileURL {
                            ActivityView(activityItems: [exportFileURL])
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar.fill")
            }
            
            // 👤 Profile
            NavigationStack {
                UserProfileView()
                    .navigationTitle("Profile")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showEditProfile = true
                            } label: {
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
                Label("Profile", systemImage: "person.crop.circle.fill")
            }
            
            // ⚙️ Settings
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
    }
    
    // MARK: - Export Functionality
    private func exportUserSummary() {
        let manager = ProgressManager.shared
        let summary = """
        📊 Patente Learning Summary
        ---------------------------
        Total Words Learned: \(manager.totalLearnedWords())
        Average Recall Accuracy: \(Int(manager.averageRecallAccuracy() * 100))%
        Current Streak: \(manager.currentStreak()) days
        Best Streak: \(manager.bestStreak()) days
        Chapters Completed: \(ChapterList.allCases.filter { manager.progress(for: $0) >= 1.0 }.count)
        """
        
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("PatenteSummary.txt")
        try? summary.write(to: fileURL, atomically: true, encoding: .utf8)
        exportFileURL = fileURL
        showShareSheet = true
    }
}
