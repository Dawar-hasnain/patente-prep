//
//  GlassStyle.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 08/11/25.
//

import SwiftUI

struct GlassStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func glassCard() -> some View {
        self.modifier(GlassStyle())
    }
}
