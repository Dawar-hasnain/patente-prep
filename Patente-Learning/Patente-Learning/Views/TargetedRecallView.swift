//
//  TargetedRecallView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 11/11/25.
//

import SwiftUI

struct TargetedRecallView: View {
    @State var weakStates: [WordMemoryState]
    @State private var index = 0
    @State private var showAnswer = false
    @State private var score = 0
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Weak Words Practice")
                    .font(.title2.bold())
                
                if index < weakStates.count {
                    VStack(spacing: 14) {
                        Text(weakStates[index].word)
                            .font(.largeTitle.weight(.bold))
                            .padding()
                            .glassCard()
                        
                        if showAnswer {
                            Text(ProgressManager.shared.translation(for: weakStates[index].word) ?? "—")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 10)
                        }
                        
                        HStack {
                            Button("Show Answer") {
                                withAnimation { showAnswer.toggle() }
                            }
                            Button("Remembered ✅") {
                                ProgressManager.shared.updateMemoryState(for: weakStates[index].word, correct: true)
                                score += 1
                                nextWord()
                            }
                            .tint(.green)
                            Button("Forgot ❌") {
                                ProgressManager.shared.updateMemoryState(for: weakStates[index].word, correct: false)
                                nextWord()
                            }
                            .tint(.red)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Session Complete 🎯")
                            .font(.title.bold())
                        Text("Score: \(score)/\(weakStates.count)")
                            .font(.headline)
                        Button("Back to Dashboard") {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                window.rootViewController = UIHostingController(rootView: MainTabView())
                                window.makeKeyAndVisible()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                Spacer()
            }
            .padding()
        }
    }
    
    private func nextWord() {
        withAnimation {
            showAnswer = false
            index += 1
        }
    }
}
