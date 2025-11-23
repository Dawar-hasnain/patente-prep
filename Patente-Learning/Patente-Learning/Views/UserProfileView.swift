//
//  UserProfileView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct UserProfileView: View {
    @State private var totalWords = 0
    @State private var recallAccuracy = 0.0
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var showUnlockAlert = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    
                    // MARK: - Header
                    VStack(spacing: 8) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 90, height: 90)
                            .foregroundColor(.accentColor.opacity(0.8))
                        
                        Text("Your Profile")
                            .font(.title2.bold())
                        
                        Text("Patente Learning Journey")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Streak Badge (shared)
                    StreakBadgeView(currentStreak: currentStreak, bestStreak: bestStreak)
                        .padding(.horizontal)
                    
                    // MARK: - Recall Accuracy
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                        
                        Text("Recall Accuracy")
                            .font(.headline)
                        Text("\(Int(recallAccuracy * 100))%")
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .padding(.horizontal)
                    
                    // MARK: - Achievements / Milestones
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Achievements")
                            .font(.headline)
                            .padding(.leading, 4)
                        
                        HStack(spacing: 24) {
                            if totalWords >= 50 {
                                VStack(spacing: 6) {
                                    Image(systemName: "rosette")
                                        .foregroundColor(.accentColor)
                                    Text("50+ Words")
                                        .font(.caption)
                                }
                            }
                            if totalWords >= 100 {
                                VStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text("100 Words")
                                        .font(.caption)
                                }
                            }
                            if bestStreak >= 3 {
                                VStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(.orange)
                                    Text("3-Day Streak")
                                        .font(.caption)
                                }
                            }
                            if bestStreak >= 7 {
                                VStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.purple)
                                    Text("7-Day Streak")
                                        .font(.caption)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    .padding(.horizontal)

                        // MARK: - Actions
                        VStack(spacing: 12) {
                            Button(role: .destructive) {
                                ProgressManager.shared.resetAllProgress()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    reloadData()
                                }
                            } label: {
                                Label("Reset All Progress", systemImage: "arrow.counterclockwise.circle")
                            }

                            Button {
                                showUnlockAlert = true
                            } label: {
                                Label("Unlock All Chapters", systemImage: "lock.open.fill")
                            }
                            .tint(.green)
                            .alert("Unlock All Chapters?", isPresented: $showUnlockAlert) {
                                Button("Unlock", role: .none) {
                                    ProgressManager.shared.unlockAllChaptersForTesting()
                                    withAnimation(.spring()) {
                                        reloadData()
                                    }
                                    HapticsManager.success()
                                }
                                Button("Cancel", role: .cancel) { }
                            } message: {
                                Text("This will mark all chapters and words as learned for testing purposes.")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .padding(.bottom, 30)
                }
                .padding(.horizontal)
            }
        }
        .onAppear(perform: reloadData)
        .navigationBarHidden(true)
    }
    
    // MARK: - Helpers
    private func reloadData() {
        let manager = ProgressManager.shared
        totalWords = manager.totalLearnedWords()
        recallAccuracy = manager.averageRecallAccuracy()
        currentStreak = manager.currentStreak()
        bestStreak = manager.bestStreak()
    }
}

