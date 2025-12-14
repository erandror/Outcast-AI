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
            ContentView()
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
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
                            _ = try await refresher.refreshAll()
                            print("✓ Auto-refreshed feeds on foreground (stale data)")
                        } catch {
                            print("Auto-refresh failed: \(error)")
                        }
                    }
                }
            } else {
                // First launch or no refresh yet - refresh immediately
                Task {
                    do {
                        let refresher = FeedRefresher.shared
                        _ = try await refresher.refreshAll()
                        print("✓ Auto-refreshed feeds on first launch")
                    } catch {
                        print("Auto-refresh failed: \(error)")
                    }
                }
            }
            
        case .background:
            // Schedule background refresh when app goes to background
            Self.scheduleBackgroundRefresh()
            
        case .inactive:
            break
            
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
