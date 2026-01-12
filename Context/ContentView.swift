//
//  ContentView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
            
            EventsView()
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
        }
    }
}

#Preview {
    ContentView()
}