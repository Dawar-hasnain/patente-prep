//
//  CompletionView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//
import SwiftUI

struct CompletionView: View {
    let currentChapter: ChapterList
    let totalWords: Int
    var onDismiss: () -> Void
    var onNextChapter: (() -> Void)?

    var body: some View {
        ZStack {
            // 👇 Universal background
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 25) {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                    Text("Chapter Completed!")
                        .font(.largeTitle.bold())
                    Text("You mastered all \(totalWords) words in \(currentChapter.title).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    Button {
                        onDismiss()
                    } label: {
                        Label("Back to Home", systemImage: "house.fill")
                            .font(.headline)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    if let nextAction = onNextChapter {
                        Button {
                            nextAction()
                        } label: {
                            Label("Continue to Next Chapter", systemImage: "arrow.right.circle.fill")
                                .font(.headline)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
            .glassCard()
            .padding(.horizontal, 30)
        }
    }
}
