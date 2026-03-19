//
//  SoftGlassCard.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 23/11/25.
//

import SwiftUI

struct SoftGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            Color.white.opacity(0.08)
                .blur(radius: 0)
                .background(.ultraThinMaterial)
        )
        
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func softGlassCard() -> some View {
        self.modifier(SoftGlassCard())
    }
}

