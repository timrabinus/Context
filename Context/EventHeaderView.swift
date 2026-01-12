//
//  EventHeaderView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventHeaderView: View {
    let event: CalendarEvent?
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let event = event {
                // Title
                Text(event.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Start to End
                if let endDate = event.endDate {
                    Text("\(formatTime(event.startDate)) to \(formatTime(endDate))")
                        .font(.body)
                        .foregroundColor(.secondary)
                } else {
                    Text(formatTime(event.startDate))
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    EventHeaderView(
        event: CalendarEvent(
            id: "1",
            calendarId: "calendar1",
            title: "Sample Event",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
            description: "This is a sample event description.",
            location: nil
        )
    )
}
