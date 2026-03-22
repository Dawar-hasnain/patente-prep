//
//  AboutView.swift
//  Sorpasso
//
//  Presented as a sheet from SettingsView.
//  Follows HIG: navigation bar with a trailing "Done" button,
//  swipe-to-dismiss always available.
//

import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "car.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(.accentColor)

                VStack(spacing: 6) {
                    Text("Sorpasso")
                        .font(.title.bold())

                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.horizontal, 40)

                Text("An interactive app to help you master Italian driving theory through smart recall and adaptive review sessions.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding()
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    AboutView()
}
