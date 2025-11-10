//
//  ChapterRow.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import SwiftUI

struct ChapterRow: View {
    let chapter: ChapterList
    @State private var progress: Double = 0.0
    
    var body: some View {
        HStack(spacing: 15) {
            // 📘 Icon
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 50)
            
            // 🧠 Title & Subtitle
            VStack(alignment: .leading, spacing: 5) {
                Text(chapter.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 🔹 Progress Circle
            ZStack {
                Circle()
                    .stroke(lineWidth: 6)
                    .opacity(0.2)
                    .foregroundColor(.blue)
                    .frame(width: 38, height: 38)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: progress)
                    .frame(width: 38, height: 38)
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .glassCard()
        .padding(.horizontal)
        .onAppear {
            progress = ProgressManager.shared.progress(for: chapter)
        }
    }
    
    // MARK: - Icon & Subtitle
    private var iconName: String {
        switch chapter {
        case .la_strada: return "road.lanes"
        case .segnaletica_stradale: return "signpost.right"
        case .norme_di_comportamento: return "figure.walk"
        case .il_veicolo_a_motore: return "car.fill"
        case .i_veicoli: return "truck.box"
        case .equipaggiamento_dei_veicoli: return "wrench.and.screwdriver"
        case .sicurezza_e_inquinamento: return "leaf.fill"
        case .incidenti_e_assicurazione: return "car.rear.waves.up"
        case .primo_soccorso: return "cross.case.fill"
        case .documenti: return "doc.text"
        }
    }
    
    private var subtitle: String {
        switch chapter {
        case .la_strada: return "Basic road and environment terms"
        case .segnaletica_stradale: return "Learn road and traffic signs"
        case .norme_di_comportamento: return "Behavior and driving norms"
        case .il_veicolo_a_motore: return "Vehicle components and mechanics"
        case .i_veicoli: return "Types of vehicles"
        case .equipaggiamento_dei_veicoli: return "Vehicle equipment and accessories"
        case .sicurezza_e_inquinamento: return "Safety and environmental rules"
        case .incidenti_e_assicurazione: return "Accidents and insurance basics"
        case .primo_soccorso: return "First aid at the scene"
        case .documenti: return "Documents and regulations"
        }
    }
}
