//
//  BlurScaleTransition.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 27/11/25.
//

import SwiftUI

struct BlurScaleTransition<Content: View>: View {
    let content: Content
    @Binding var isPresented: Bool
    
    // Internal animation state
    @State private var animate = false
    
    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            
            // Background blur
            if isPresented {
                VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                    .opacity(animate ? 1 : 0)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeIn(duration: 0.20)))
            }
            
            // Foreground content (ReviewSessionView)
            if isPresented {
                content
                    .scaleEffect(animate ? 1.0 : 0.88)   // zoom in
                    .opacity(animate ? 1.0 : 0)         // fade in
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.83),
                        value: animate
                    )
                    .onAppear {
                        animate = true
                    }
                    .onDisappear {
                        animate = false
                    }
            }
        }
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { }
}
