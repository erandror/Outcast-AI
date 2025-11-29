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
    
    init() {
        // Initialize database on launch
        _ = AppDatabase.shared
        
        // Register background tasks
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
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
        scheduleNextRefresh()
        
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
    
    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "fyi.outcast.feedRefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    #endif
}

// MARK: - Scene Phase Handler

extension OutcastApp {
    
    /// Call this when app enters background to schedule refresh
    static func scheduleBackgroundRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: "fyi.outcast.feedRefresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
        #endif
    }
}
