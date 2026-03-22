//
//  ParallaxTiltModifier.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 23/11/25.
//

import SwiftUI

struct ParallaxTiltModifier: ViewModifier {
    @State private var tiltX: CGFloat = 0
    @State private var tiltY: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(tiltX * 0.8),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(-tiltY * 0.8),
                axis: (x: 0, y: 1, z: 0)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged{ value in
                        withAnimation(.easeOut(duration: 0.15))
                        {
                            tiltX = value.translation.height / 40
                            tiltY = value.translation.width / 40
                        }
                    }
                    .onEnded{ _ in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)){
                            tiltX = 0
                            tiltY = 0
                        }
                    }
            )
    }
}

extension View {
    func parallaxTiltModifier() -> some View {
        self.modifier(ParallaxTiltModifier())
    }
}
