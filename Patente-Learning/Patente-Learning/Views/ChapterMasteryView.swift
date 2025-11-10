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

    var body: some View {
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

            Button(action: returnHome) {
                HStack {
                    Image(systemName: "house.fill")
                    Text("Return to Home")
                }
                .font(.headline)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            
            if score < 0.8 {
                Button(action: retakeReview) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Retake Final Review")
                    }
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }


            Spacer()
        }
        .padding()
        .background(Color.appBackground.ignoresSafeArea())
    }

    private func returnHome() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let root = UIHostingController(rootView: ChapterPathView())
            window.rootViewController = root
            window.makeKeyAndVisible()
        }
    }
    
    private func retakeReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            let root = UIHostingController(
                rootView: FinalChapterReviewView(chapter: chapter)
            )
            window.rootViewController = root
            window.makeKeyAndVisible()
        }
    }

}
