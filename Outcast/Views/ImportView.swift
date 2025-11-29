//
//  ImportView.swift
//  Outcast
//
//  UI for importing OPML files and subscribing to podcasts
//

import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var isImporting = false
    @State private var isLoading = false
    @State private var feedURL = ""
    @State private var importResult: ImportResult?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // OPML Import Section
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Import OPML", systemImage: "doc.badge.plus")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Import your podcast subscriptions from another app using an OPML file.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Button {
                                isImporting = true
                            } label: {
                                HStack {
                                    Image(systemName: "folder")
                                    Text("Choose OPML File")
                                }
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                            Text("OR")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 1)
                        }
                        
                        // Subscribe by URL Section
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Subscribe by URL", systemImage: "link")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            Text("Enter a podcast RSS feed URL to subscribe.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            TextField("https://example.com/feed.xml", text: $feedURL)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                                .foregroundStyle(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                            
                            Button {
                                Task {
                                    await subscribeToFeed()
                                }
                            } label: {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.black)
                                    } else {
                                        Image(systemName: "plus.circle")
                                        Text("Subscribe")
                                    }
                                }
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(feedURL.isEmpty ? Color.gray : Color.white)
                                .cornerRadius(12)
                            }
                            .disabled(feedURL.isEmpty || isLoading)
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Add Podcasts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.opml, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result)
            }
        }
        .alert("Import Complete", isPresented: .init(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("OK") {
                if importResult?.success == true {
                    dismiss()
                }
                importResult = nil
            }
        } message: {
            if let result = importResult {
                Text(result.message)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Need to start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file"
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let podcasts = try await OPMLParser.importOPML(from: url, database: AppDatabase.shared)
                
                if podcasts.isEmpty {
                    importResult = ImportResult(
                        success: true,
                        message: "No new podcasts to import. You may already be subscribed to all podcasts in this file."
                    )
                } else {
                    // Refresh the newly imported podcasts to get episodes
                    let refresher = FeedRefresher.shared
                    var totalEpisodes = 0
                    for podcast in podcasts {
                        do {
                            totalEpisodes += try await refresher.refresh(podcast: podcast)
                        } catch {
                            print("Failed to refresh \(podcast.title): \(error)")
                        }
                    }
                    
                    importResult = ImportResult(
                        success: true,
                        message: "Successfully imported \(podcasts.count) podcast\(podcasts.count == 1 ? "" : "s") with \(totalEpisodes) episode\(totalEpisodes == 1 ? "" : "s")."
                    )
                }
            } catch {
                importResult = ImportResult(
                    success: false,
                    message: error.localizedDescription
                )
            }
            
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func subscribeToFeed() async {
        guard !feedURL.isEmpty else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let refresher = FeedRefresher.shared
            let podcast = try await refresher.subscribe(to: feedURL)
            
            importResult = ImportResult(
                success: true,
                message: "Successfully subscribed to \"\(podcast.title)\"!"
            )
            feedURL = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct ImportResult {
    let success: Bool
    let message: String
}

// MARK: - OPML UTType

extension UTType {
    static let opml = UTType(filenameExtension: "opml") ?? .xml
}

#Preview {
    ImportView()
}
