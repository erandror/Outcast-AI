//
//  FullNameScreen.swift
//  Outcast
//
//  Full name input screen for onboarding
//

import SwiftUI

struct FullNameScreen: View {
    @Binding var fullName: String
    let onContinue: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                Text("What's your name?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                Spacer()
                    .frame(height: 60)
                
                // Text Field
                TextField("Full name", text: $fullName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .focused($isTextFieldFocused)
                    .autocorrectionDisabled()
                
                Spacer()
                
                // Continue Button
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(fullName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : Color.white)
                        .cornerRadius(12)
                }
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto-focus the text field
            isTextFieldFocused = true
        }
    }
}

#Preview {
    FullNameScreen(
        fullName: .constant(""),
        onContinue: {}
    )
}

