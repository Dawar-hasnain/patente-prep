//
//  PopupView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 30/11/25.
//

import SwiftUI

struct PopupView: View {
    
    let selected: SentenceWord
    let anchor: CGRect
    let screenSize: CGSize
    let onClose: () -> Void
    
    var body: some View {
        ZStack{
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }
                .transition(.opacity)
            
            VStack (spacing: 14) {
                Text (selected.word)
                    .font(.title3.bold())
                
                Text(selected.translation ?? "No translation")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let position = selected.partOfSpeech {
                    Text (position.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .cornerRadius(8)
                }
                
                Button ("Close")
                {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8))
                    {
                        onClose()
                    }
                }
                .font(.headline)
            }
            .padding(16)
            .background(.ultraThickMaterial)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
            .overlay(
                TrianglePointer()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 22, height: 12)
                    .offset(x: anchor.midX - screenSize.width / 2, y: -8)
                ,
                alignment: .top
            )
            .frame(width: 240)
            .position(
                x: screenSize.width / 2,
                y: max(anchor.midY - 80, 140)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
    
    private func playAudio() {
        HapticsManager.lightTap()
    }
}

struct TrianglePointer: Shape {
    func path (in rect: CGRect) -> Path
    {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}
