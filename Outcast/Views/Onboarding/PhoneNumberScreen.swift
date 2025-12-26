//
//  PhoneNumberScreen.swift
//  Outcast
//
//  Phone number input screen for onboarding
//

import SwiftUI

struct PhoneNumberScreen: View {
    @Binding var phoneNumber: String
    @Binding var countryCode: String
    let onContinue: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title
                Text("Your phone number")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                
                Spacer()
                    .frame(height: 60)
                
                // Phone Input Row
                HStack(spacing: 12) {
                    // Country Code Picker
                    CountryCodePicker(selectedCode: $countryCode)
                    
                    // Phone Number Field
                    TextField("Phone number", text: $phoneNumber)
                        .font(.body)
                        .foregroundStyle(.white)
                        .keyboardType(.phonePad)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal, 20)
                
                // Explanation Text
                Text("Outcast identifies you via your phone number to keep your preferences 100% private and secure. We'll never sell your number, call or text you.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                
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
                        .background(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty ? Color.white.opacity(0.3) : Color.white)
                        .cornerRadius(12)
                }
                .disabled(phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty)
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
    PhoneNumberScreen(
        phoneNumber: .constant(""),
        countryCode: .constant("+1"),
        onContinue: {}
    )
}

