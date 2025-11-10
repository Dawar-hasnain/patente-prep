//
//  StreakBadgeView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct StreakBadgeView: View {
    let currentStreak: Int
    let bestStreak: Int
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(currentStreak) Day Streak")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if bestStreak > currentStreak {
                    Text("Best: \(bestStreak) Days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.1), radius: 3, y: 2)
    }
}
