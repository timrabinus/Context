//
//  ContentView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .top) {
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
            
            DateTimeHeader()
                .padding(.top, -4)
        }
    }
}

struct DateTimeHeader: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        HStack {
//             Date on the left
             Text(currentTime, style: .date)
                .font(.callout)
                 .foregroundColor(.primary)
            
            Spacer()
            
//             Time on the right
             Text(currentTime, style: .time)
                .font(.callout)
                 .monospacedDigit()
        }
        .padding(.horizontal, 40)
        .onAppear {
            currentTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

#Preview {
    ContentView()
}
