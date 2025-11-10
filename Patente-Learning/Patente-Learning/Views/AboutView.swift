//
//  AboutView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "car.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("Patente Learning")
                .font(.title.bold())
            
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider().padding(.horizontal)
            
            Text("An interactive app to help you master Italian driving theory through smart recall and adaptive review sessions.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.bottom, 20)
        }
        .padding()
    }
}
