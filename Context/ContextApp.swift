//
//  ContextApp.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

@main
struct ContextApp: App {
    @StateObject private var calendarService = CalendarService()
    
    init() {
        // Register default values for settings
        let defaults = UserDefaults.standard
        // 7am = 7 * 3600 = 25200 seconds
        // 11pm = 23 * 3600 = 82800 seconds
        defaults.register(defaults: [
            "wakeTime": 25200.0,   // 7:00 AM
            "sleepTime": 82800.0   // 11:00 PM (23:00)
        ])
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(calendarService)
                .task {
                    await calendarService.fetchCalendars()
                }
        }
    }
}
