//
//  OutcastApp.swift
//  Outcast
//
//  Created by Eran Dror on 11/28/25.
//

import SwiftUI
import BackgroundTasks

@main
struct OutcastApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnboardingComplete: Bool = false
    @State private var isCheckingOnboarding: Bool = true
    
    init() {
        // Initialize database on launch
        _ = AppDatabase.shared
        
        // Initialize Now Playing manager to register remote commands
        _ = NowPlayingManager.shared
        
        // Register background tasks
        registerBackgroundTasks()
        
        // Start episode tagging background processor
        startEpisodeTagger()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingOnboarding {
                    // Show loading state while checking onboarding status
                    ZStack {
                        Color.black.ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                } else if isOnboardingComplete {
                    ContentView()
                } else {
                    OnboardingCoordinator(onComplete: {
                        isOnboardingComplete = true
                    })
                }
            }
            .preferredColorScheme(.dark)
            .task {
                await checkOnboardingStatus()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func checkOnboardingStatus() async {
        do {
            let isComplete = try await AppDatabase.shared.readAsync { db in
                try ProfileRecord.isOnboardingComplete(db: db)
            }
            await MainActor.run {
                isOnboardingComplete = isComplete
                isCheckingOnboarding = false
            }
        } catch {
            print("Failed to check onboarding status: \(error)")
            // Default to showing onboarding on error
            await MainActor.run {
                isOnboardingComplete = false
                isCheckingOnboarding = false
            }
        }
    }
    
    // MARK: - Episode Tagging
    
    private func startEpisodeTagger() {
        Task {
            let tagger = EpisodeTagger.shared
            await tagger.startBackgroundProcessing()
        }
    }
    
    // MARK: - Scene Phase Handling
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // Refresh if stale (more than 15 minutes since last refresh)
            if let lastRefresh = UserDefaults.lastFeedRefresh {
                let fifteenMinutesAgo = Date().addingTimeInterval(-15 * 60)
                if lastRefresh < fifteenMinutesAgo {
                    Task {
                        do {
                            let refresher = FeedRefresher.shared
                            // Foreground refresh: only top 30 priority podcasts with 2 concurrent requests
                            _ = try await refresher.refreshAll(maxPodcasts: 30, concurrency: 2)
                            print("✓ Auto-refreshed top priority feeds on foreground (stale data)")
                        } catch {
                            print("Auto-refresh failed: \(error)")
                        }
                    }
                }
            } else {
                // First launch or no refresh yet - refresh top priority podcasts
                Task {
                    do {
                        let refresher = FeedRefresher.shared
                        // Foreground refresh: only top 30 priority podcasts with 2 concurrent requests
                        _ = try await refresher.refreshAll(maxPodcasts: 30, concurrency: 2)
                        print("✓ Auto-refreshed top priority feeds on first launch")
                    } catch {
                        print("Auto-refresh failed: \(error)")
                    }
                }
            }
            
        case .background:
            // Save playback position before going to background
            Task { @MainActor in
                try? await PlaybackManager.shared.savePositionForBackground()
            }
            // Schedule background refresh when app goes to background
            Self.scheduleBackgroundRefresh()
            
        case .inactive:
            // Save playback position when becoming inactive (e.g., during interruptions)
            Task { @MainActor in
                try? await PlaybackManager.shared.savePositionForBackground()
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "fyi.outcast.feedRefresh",
            using: nil
        ) { task in
            self.handleFeedRefresh(task: task as! BGAppRefreshTask)
        }
        #endif
    }
    
    #if os(iOS)
    private func handleFeedRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh
        Self.scheduleBackgroundRefresh()
        
        let refreshTask = Task {
            do {
                let refresher = FeedRefresher.shared
                // Background refresh: all podcasts with 4 concurrent requests (no limits)
                _ = try await refresher.refreshAll()
                task.setTaskCompleted(success: true)
            } catch {
                print("Background refresh failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
        
        task.expirationHandler = {
            refreshTask.cancel()
        }
    }
    #endif
    
    // MARK: - Background Refresh Scheduling
    
    /// Schedule background feed refresh task
    static func scheduleBackgroundRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: "fyi.outcast.feedRefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✓ Scheduled background refresh for 15 minutes from now")
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
        #endif
    }
}
