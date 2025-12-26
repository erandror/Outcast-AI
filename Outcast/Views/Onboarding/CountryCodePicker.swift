//
//  CountryCodePicker.swift
//  Outcast
//
//  Country code selection component
//

import SwiftUI

struct CountryCode: Identifiable, Sendable {
    let id: String
    let name: String
    let code: String
    let flag: String
    
    static let allCodes: [CountryCode] = [
        CountryCode(id: "US", name: "United States", code: "+1", flag: "🇺🇸"),
        CountryCode(id: "CA", name: "Canada", code: "+1", flag: "🇨🇦"),
        CountryCode(id: "GB", name: "United Kingdom", code: "+44", flag: "🇬🇧"),
        CountryCode(id: "AU", name: "Australia", code: "+61", flag: "🇦🇺"),
        CountryCode(id: "NZ", name: "New Zealand", code: "+64", flag: "🇳🇿"),
        CountryCode(id: "IE", name: "Ireland", code: "+353", flag: "🇮🇪"),
        CountryCode(id: "IN", name: "India", code: "+91", flag: "🇮🇳"),
        CountryCode(id: "DE", name: "Germany", code: "+49", flag: "🇩🇪"),
        CountryCode(id: "FR", name: "France", code: "+33", flag: "🇫🇷"),
        CountryCode(id: "ES", name: "Spain", code: "+34", flag: "🇪🇸"),
        CountryCode(id: "IT", name: "Italy", code: "+39", flag: "🇮🇹"),
        CountryCode(id: "NL", name: "Netherlands", code: "+31", flag: "🇳🇱"),
        CountryCode(id: "SE", name: "Sweden", code: "+46", flag: "🇸🇪"),
        CountryCode(id: "NO", name: "Norway", code: "+47", flag: "🇳🇴"),
        CountryCode(id: "DK", name: "Denmark", code: "+45", flag: "🇩🇰"),
        CountryCode(id: "FI", name: "Finland", code: "+358", flag: "🇫🇮"),
        CountryCode(id: "PL", name: "Poland", code: "+48", flag: "🇵🇱"),
        CountryCode(id: "BR", name: "Brazil", code: "+55", flag: "🇧🇷"),
        CountryCode(id: "MX", name: "Mexico", code: "+52", flag: "🇲🇽"),
        CountryCode(id: "AR", name: "Argentina", code: "+54", flag: "🇦🇷"),
        CountryCode(id: "JP", name: "Japan", code: "+81", flag: "🇯🇵"),
        CountryCode(id: "KR", name: "South Korea", code: "+82", flag: "🇰🇷"),
        CountryCode(id: "CN", name: "China", code: "+86", flag: "🇨🇳"),
        CountryCode(id: "SG", name: "Singapore", code: "+65", flag: "🇸🇬"),
        CountryCode(id: "ZA", name: "South Africa", code: "+27", flag: "🇿🇦"),
    ]
}

struct CountryCodePicker: View {
    @Binding var selectedCode: String
    @State private var showingPicker = false
    
    var selectedCountry: CountryCode {
        CountryCode.allCodes.first { $0.code == selectedCode } ?? CountryCode.allCodes[0]
    }
    
    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 8) {
                Text(selectedCountry.flag)
                    .font(.title3)
                Text(selectedCountry.code)
                    .font(.body)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .sheet(isPresented: $showingPicker) {
            CountryCodePickerSheet(selectedCode: $selectedCode)
        }
    }
}

private struct CountryCodePickerSheet: View {
    @Binding var selectedCode: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(CountryCode.allCodes) { country in
                            Button {
                                selectedCode = country.code
                                dismiss()
                            } label: {
                                HStack {
                                    Text(country.flag)
                                        .font(.title3)
                                    Text(country.name)
                                        .font(.body)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(country.code)
                                        .font(.body)
                                        .foregroundStyle(.white.opacity(0.6))
                                    if selectedCode == country.code {
                                        Image(systemName: "checkmark")
                                            .font(.body)
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                            
                            if country.id != CountryCode.allCodes.last?.id {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Country Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    CountryCodePicker(selectedCode: .constant("+1"))
        .padding()
        .background(Color.black)
}

