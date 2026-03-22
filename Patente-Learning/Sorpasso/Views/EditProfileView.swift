//
//  EditProfileView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//

import SwiftUI

struct EditProfileView: View {
    @AppStorage("userName") private var userName: String = "Learner"
    @AppStorage("userEmoji") private var userEmoji: String = "🚗"
    @Environment(\.dismiss) private var dismiss
    
    let emojiOptions = ["🚗", "🚙", "🏍️", "🚓", "🚕", "🚚", "🚒", "🚜", "🛵"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profile Info")) {
                    TextField("Your Name", text: $userName)
                }
                
                Section(header: Text("Avatar")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.largeTitle)
                                    .padding(8)
                                    .background(emoji == userEmoji ? Color.accentColor.opacity(0.3) : .clear)
                                    .cornerRadius(12)
                                    .onTapGesture {
                                        userEmoji = emoji
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
