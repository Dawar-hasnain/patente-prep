//
//  ChapterMasteryView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct ChapterMasteryView: View {
    let chapter: ChapterList
    let score: Double
    var onRetake: (() -> Void)? = nil   // supplied by FinalChapterReviewView

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 25) {
                Spacer()

                Image(systemName: "star.circle.fill")
                    .resizable()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.yellow)
                    .shadow(radius: 6)
                    .padding(.bottom, 10)

                Text("Chapter Mastered!")
                    .font(.largeTitle.bold())

                Text("You scored \(Int(score * 100))% on \(chapter.title).")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "house.fill")
                            Text("Return to Home")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    if score < 0.8, let retake = onRetake {
                        Button {
                            retake()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Retake Final Review")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    ChapterMasteryView(chapter: .la_strada, score: 0.75)
}
