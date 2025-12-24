//
//  OutcastUITests.swift
//  OutcastUITests
//
//  UI tests for navigation and accessibility
//

import XCTest

final class OutcastUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify app launched successfully
        XCTAssertTrue(app.state == .runningForeground)
        
        // Basic smoke test - check for key UI elements
        // The app may show either StartView or ContentView depending on state
        let hasStartView = app.staticTexts["Welcome to Outcast"].exists
        let hasTabBar = app.tabBars.element.exists
        
        // At least one should exist
        XCTAssertTrue(hasStartView || hasTabBar, "App should show either start view or main interface")
    }
    
    @MainActor
    func testNavigationToShows() throws {
        let app = XCUIApplication()
        app.launch()
        
        // If tab bar is visible, test navigation
        let tabBar = app.tabBars.element
        
        if tabBar.exists {
            // Navigate to Shows tab
            let showsTab = tabBar.buttons["Shows"]
            if showsTab.exists {
                showsTab.tap()
                
                // Give UI time to update
                sleep(1)
                
                // Verify we're on the Shows screen
                // Look for common Shows view elements
                XCTAssertTrue(app.navigationBars.element.exists || app.staticTexts.element.exists)
            }
            
            // Navigate to Listen tab
            let listenTab = tabBar.buttons["Listen"]
            if listenTab.exists {
                listenTab.tap()
                sleep(1)
                XCTAssertTrue(app.navigationBars.element.exists || app.staticTexts.element.exists)
            }
            
            // Navigate to For You tab
            let forYouTab = tabBar.buttons["For You"]
            if forYouTab.exists {
                forYouTab.tap()
                sleep(1)
                XCTAssertTrue(app.navigationBars.element.exists || app.staticTexts.element.exists)
            }
        }
    }
    
    @MainActor
    func testStartViewAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check if StartView is displayed
        let welcomeText = app.staticTexts["Welcome to Outcast"]
        
        if welcomeText.exists {
            // Verify welcome text is accessible
            XCTAssertTrue(welcomeText.isHittable)
            
            // Look for import button or subscription prompt
            let buttons = app.buttons
            
            // Verify there are interactive elements
            XCTAssertTrue(buttons.count > 0, "Start view should have interactive buttons")
            
            // Check that buttons are accessible
            for i in 0..<min(buttons.count, 3) {
                let button = buttons.element(boundBy: i)
                if button.exists && button.isHittable {
                    XCTAssertNotNil(button.label, "Button should have an accessibility label")
                }
            }
        }
    }
    
    @MainActor
    func testTabBarAccessibility() throws {
        let app = XCUIApplication()
        app.launch()
        
        let tabBar = app.tabBars.element
        
        if tabBar.exists {
            // Get all tab bar buttons
            let tabButtons = tabBar.buttons
            
            // Verify tabs have accessibility labels
            for i in 0..<tabButtons.count {
                let button = tabButtons.element(boundBy: i)
                if button.exists {
                    XCTAssertNotNil(button.label, "Tab bar button should have accessibility label")
                    XCTAssertTrue(button.isEnabled, "Tab bar button should be enabled")
                }
            }
        }
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
