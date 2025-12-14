//
//  ContentView.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import GRDB

struct ContentView: View {
    private enum MainTab {
        case listen
        case history
        case profile
    }
    
    @State private var episodes: [EpisodeWithPodcast] = []
    @State private var selectedEpisodeForPlayer: EpisodeWithPodcast?
    @State private var selectedEpisodeForDetail: EpisodeWithPodcast?
    @State private var showPlayer = false
    @State private var showImport = false
    @State private var isRefreshing = false
    @State private var lastRefreshDate: Date?
    @State private var showDownloads = false
    @State private var selectedFilter: ForYouFilter = .latest
    @State private var importProgress: ImportCoordinator.ImportProgress?
    @State private var selectedTab: MainTab = .listen
    @ObservedObject private var playbackManager = PlaybackManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Persistent top area
                    topBarArea
                    
                    // Tab content fills remaining space
                    tabContent
                    
                    // Bottom overlay: mini player (when active) + nav
                    bottomOverlay
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showDownloads) {
            NavigationStack {
                DownloadsListView()
            }
        }
        .task {
            await loadEpisodes()
            // Start monitoring import progress
            await monitorImportProgress()
        }
        .onChange(of: selectedFilter) {
            Task {
                await loadEpisodes()
            }
        }
        .onChange(of: importProgress) { _, newProgress in
            // Reload episodes when import completes
            if let progress = newProgress, progress.isComplete {
                Task {
                    await loadEpisodes()
                    // Clear progress after a brief delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    importProgress = nil
                }
            }
        }
        .fullScreenCover(item: $selectedEpisodeForPlayer) { episode in
            if let index = episodes.firstIndex(where: { $0.id == episode.id }) {
                PlayerView(episodes: episodes, startIndex: index)
            }
        }
        .fullScreenCover(item: $selectedEpisodeForDetail) { episode in
            if let index = episodes.firstIndex(where: { $0.id == episode.id }) {
                EpisodeView(episodes: episodes, startIndex: index)
            }
        }
        .sheet(isPresented: $showImport) {
            ImportView()
                .onDisappear {
                    Task {
                        await loadEpisodes()
                    }
                }
        }
    }
    
    private var topBarArea: some View {
        VStack(spacing: 0) {
            headerView
            
            if let progress = importProgress {
                ImportProgressBanner(progress: progress)
            }
            
            ForYouFilterBar(selectedFilter: $selectedFilter)
        }
        .background(Color.black)
    }
    
    private var headerView: some View {
        HStack {
            Text("For You")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            Spacer()
            
            Button {
                showDownloads = true
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            Button {
                showImport = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
    
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .listen:
                listenContent
            case .history:
                placeholderView(title: "History", message: "Your recently played episodes will appear here.")
            case .profile:
                placeholderView(title: "Profile", message: "Profile settings and preferences coming soon.")
            }
        }
    }
    
    private var listenContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if episodes.isEmpty && !isRefreshing {
                    emptyStateView
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(episodes) { episode in
                            EpisodeListRow(
                                episode: episode,
                                onPlay: {
                                    selectedEpisodeForPlayer = episode
                                    showPlayer = true
                                },
                                onTapEpisode: {
                                    selectedEpisodeForDetail = episode
                                }
                            )
                            
                            // Divider
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        }
        .refreshable {
            await refreshFeeds()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "headphones.circle")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.3))
            
            Text("No Podcasts Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("Import your podcasts from another app or subscribe to a new one.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showImport = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Podcasts")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(30)
            }
            .padding(.top, 8)
        }
    }
    
    private func placeholderView(title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, 40)
    }
    
    private var bottomOverlay: some View {
        VStack(spacing: 0) {
            MiniPlayer()
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            bottomNavBar
        }
        .background(Color.black)
    }
    
    private var bottomNavBar: some View {
        HStack(spacing: 32) {
            navButton(
                icon: "play.circle",
                label: "Listen",
                tab: .listen
            )
            
            navButton(
                icon: "clock.arrow.circlepath",
                label: "History",
                tab: .history
            )
            
            navButton(
                icon: "person.crop.circle",
                label: "Profile",
                tab: .profile
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }
    
    private func navButton(icon: String, label: String, tab: MainTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.6))
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selectedTab == tab ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func loadEpisodes() async {
        do {
            let filter = selectedFilter // Capture filter before async
            let loaded = try await AppDatabase.shared.readAsync { db in
                try EpisodeWithPodcast.fetchFiltered(filter: filter, limit: 100, db: db)
            }
            await MainActor.run {
                episodes = loaded
            }
        } catch {
            print("Failed to load episodes: \(error)")
        }
    }
    
    private func refreshFeeds() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let refresher = FeedRefresher.shared
            _ = try await refresher.refreshAll()
            await loadEpisodes()
            lastRefreshDate = Date()
        } catch {
            print("Failed to refresh: \(error)")
        }
    }
    
    private func monitorImportProgress() async {
        // Poll import progress every 0.5 seconds
        while true {
            let coordinator = ImportCoordinator.shared
            if let progress = await coordinator.getCurrentProgress() {
                await MainActor.run {
                    importProgress = progress
                }
            } else if importProgress != nil {
                // Import completed
                await MainActor.run {
                    importProgress = nil
                }
            }
            
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
}

// MARK: - Episode with Podcast Info

struct EpisodeWithPodcast: Identifiable, Sendable {
    let episode: EpisodeRecord
    let podcast: PodcastRecord
    
    var id: String { episode.uuid }
    
    static func fetchLatest(limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        let request = EpisodeRecord
            .including(required: EpisodeRecord.podcast)
            .order(Column("publishedDate").desc)
            .limit(limit)
        
        return try Row.fetchAll(db, request).map { row in
            EpisodeWithPodcast(
                episode: try EpisodeRecord(row: row),
                podcast: try PodcastRecord(row: row.scopes["podcast"]!)
            )
        }
    }
    
    static func fetchFiltered(filter: ForYouFilter, limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        switch filter {
        case .upNext:
            return try fetchUpNext(limit: limit, db: db)
        case .latest:
            return try fetchLatest(limit: limit, db: db)
        case .short:
            return try fetchShort(limit: limit, db: db)
        case .friendly, .funny, .interesting, .captivating, .conversations, .timely:
            return try fetchByKeywordsAndCategories(filter: filter, limit: limit, db: db)
        }
    }
    
    // MARK: - Up Next (unplayed from most listened shows)
    
    private static func fetchUpNext(limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        // Fetch unplayed episodes sorted by publish date
        let request = EpisodeRecord
            .filter(Column("playingStatus") == "notPlayed")
            .including(required: EpisodeRecord.podcast)
            .order(Column("publishedDate").desc)
            .limit(limit)
        
        return try Row.fetchAll(db, request).map { row in
            EpisodeWithPodcast(
                episode: try EpisodeRecord(row: row),
                podcast: try PodcastRecord(row: row.scopes["podcast"]!)
            )
        }
    }
    
    // MARK: - Short (under 25 minutes)
    
    private static func fetchShort(limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        let request = EpisodeRecord
            .filter(Column("duration") < 1500) // 25 minutes in seconds
            .filter(Column("duration") > 0) // Exclude episodes with no duration
            .including(required: EpisodeRecord.podcast)
            .order(Column("publishedDate").desc)
            .limit(limit)
        
        return try Row.fetchAll(db, request).map { row in
            EpisodeWithPodcast(
                episode: try EpisodeRecord(row: row),
                podcast: try PodcastRecord(row: row.scopes["podcast"]!)
            )
        }
    }
    
    // MARK: - Category & Keyword Based Filters
    
    // Episode column names for manual row parsing
    // IMPORTANT: Must include ALL episode columns including id and needsTagging
    private static let episodeColumnNames: Set<String> = [
        "id",  // Primary key - was missing!
        "uuid", "podcastId", "guid", "title", "episodeDescription", "audioURL",
        "audioMimeType", "fileSize", "duration", "publishedDate", "imageURL",
        "episodeNumber", "seasonNumber", "episodeType", "link", "explicit",
        "subtitle", "author", "contentHTML", "chaptersURL", "transcripts",
        "playedUpTo", "playingStatus", "isDownloaded", "downloadedPath",
        "downloadStatus", "downloadProgress", "localFilePath", "downloadedFileSize",
        "downloadTaskIdentifier", "downloadError", "autoDownloadStatus",
        "needsTagging"  // Added in v6 migration - was missing!
    ]
    
    // Helper function to parse a flattened row into EpisodeWithPodcast
    private static func parseEpisodeWithPodcast(from row: Row) throws -> EpisodeWithPodcast {
        var episodeData: [String: DatabaseValue] = [:]
        var podcastData: [String: DatabaseValue] = [:]
        
        // Separate episode and podcast columns
        for column in row.columnNames {
            if episodeColumnNames.contains(column) {
                episodeData[column] = row[column]
            } else {
                podcastData[column] = row[column]
            }
        }
        
        // Create rows from the separated data
        let episodeRow = Row(episodeData)
        let podcastRow = Row(podcastData)
        
        // Parse and return
        return EpisodeWithPodcast(
            episode: try EpisodeRecord(row: episodeRow),
            podcast: try PodcastRecord(row: podcastRow)
        )
    }
    
    private static func fetchByKeywordsAndCategories(filter: ForYouFilter, limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        // Check if this filter uses mood tags
        if let moodTagName = filter.moodTagName {
            return try fetchByMoodTag(moodTagName: moodTagName, limit: limit, db: db)
        }
        
        // Otherwise, use the legacy keyword/category matching
        var conditions: [String] = []
        var arguments: [DatabaseValueConvertible] = []
        
        // Build category matching (OR logic for each category)
        if !filter.categories.isEmpty {
            let categoryConditions = filter.categories.map { _ in
                "podcast.categories LIKE ?"
            }.joined(separator: " OR ")
            conditions.append("(\(categoryConditions))")
            
            // Add arguments for category LIKE queries
            for category in filter.categories {
                arguments.append("%\"\(category)\"%")
            }
        }
        
        // Build keyword matching (OR logic across title, description, author for both episode and podcast)
        if !filter.keywords.isEmpty {
            let keywordConditions = filter.keywords.flatMap { _ in
                [
                    "LOWER(episode.title) LIKE ?",
                    "LOWER(episode.episodeDescription) LIKE ?",
                    "LOWER(episode.author) LIKE ?",
                    "LOWER(podcast.title) LIKE ?",
                    "LOWER(podcast.podcastDescription) LIKE ?",
                    "LOWER(podcast.author) LIKE ?"
                ]
            }.joined(separator: " OR ")
            conditions.append("(\(keywordConditions))")
            
            // Add arguments for keyword LIKE queries
            for keyword in filter.keywords {
                let pattern = "%\(keyword.lowercased())%"
                // Episode fields
                arguments.append(pattern)
                arguments.append(pattern)
                arguments.append(pattern)
                // Podcast fields
                arguments.append(pattern)
                arguments.append(pattern)
                arguments.append(pattern)
            }
        }
        
        // Special condition: serial showType for Captivating
        if filter.requiresSerial {
            conditions.append("podcast.showType = 'serial'")
        }
        
        // Special condition: episode author populated for Conversations
        if filter.requiresEpisodeAuthor {
            conditions.append("episode.author IS NOT NULL AND episode.author != ''")
        }
        
        // Build exclude keywords (Interesting filter excludes news)
        if !filter.excludeKeywords.isEmpty {
            let excludeConditions = filter.excludeKeywords.flatMap { _ in
                [
                    "LOWER(episode.title) NOT LIKE ?",
                    "LOWER(episode.episodeDescription) NOT LIKE ?",
                    "LOWER(podcast.title) NOT LIKE ?",
                    "LOWER(podcast.podcastDescription) NOT LIKE ?"
                ]
            }.joined(separator: " AND ")
            conditions.append("(\(excludeConditions))")
            
            // Add arguments for exclude keyword queries
            for keyword in filter.excludeKeywords {
                let pattern = "%\(keyword.lowercased())%"
                arguments.append(pattern)
                arguments.append(pattern)
                arguments.append(pattern)
                arguments.append(pattern)
            }
        }
        
        // Combine all conditions with OR (any match qualifies)
        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " OR ")
        
        let sql = """
            SELECT episode.*, podcast.*
            FROM episode
            INNER JOIN podcast ON episode.podcastID = podcast.uuid
            \(whereClause)
            ORDER BY episode.publishedDate DESC
            LIMIT ?
            """
        
        arguments.append(limit)
        
        let statement = try db.makeStatement(sql: sql)
        let rows = try Row.fetchAll(statement, arguments: StatementArguments(arguments))
        
        // Use the helper function to parse each row
        return try rows.map { try parseEpisodeWithPodcast(from: $0) }
    }
    
    // MARK: - Mood Tag Based Filtering
    
    private static func fetchByMoodTag(moodTagName: String, limit: Int, db: Database) throws -> [EpisodeWithPodcast] {
        print("[TAGGER] 🔍 Querying episodes for mood tag: '\(moodTagName)'")
        
        // Get episode IDs that have the mood tag
        let episodeIdsSql = """
            SELECT episode_tag.episodeId
            FROM episode_tag
            INNER JOIN system_tag ON episode_tag.tagId = system_tag.id
            WHERE system_tag.type = 'mood' AND LOWER(system_tag.name) = LOWER(?)
            """
        let episodeIds = try Int64.fetchAll(db, sql: episodeIdsSql, arguments: [moodTagName])
        
        guard !episodeIds.isEmpty else {
            print("[TAGGER] 📊 Found 0 episodes for mood '\(moodTagName)'")
            return []
        }
        
        // Use GRDB's association system to fetch episodes with podcasts
        // This properly namespaces columns to avoid conflicts
        let request = EpisodeRecord
            .filter(keys: episodeIds)
            .including(required: EpisodeRecord.podcast)
            .order(Column("publishedDate").desc)
            .limit(limit)
        
        let rows = try Row.fetchAll(db, request)
        
        print("[TAGGER] 📊 Found \(rows.count) episodes for mood '\(moodTagName)'")
        
        // Parse using GRDB's scoped rows (properly handles column namespacing)
        return try rows.map { row in
            EpisodeWithPodcast(
                episode: try EpisodeRecord(row: row),
                podcast: try PodcastRecord(row: row.scopes["podcast"]!)
            )
        }
    }
}

#Preview {
    ContentView()
}
