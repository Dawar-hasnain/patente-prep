//
//  SmoothFullScreenTransition.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 27/11/25.
//

import SwiftUI

struct SmoothFullScreenTransition<Content: View>: View {
    let content: Content
    @Binding var isPresented: Bool

    @State private var animate = false

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Dimmed Background
            if isPresented {
                Color.black.opacity(animate ? 0.32 : 0)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: animate)
            }

            // Main sheet content
            if isPresented {
                content
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 40)
                    .scaleEffect(animate ? 1 : 0.96)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.82),
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
