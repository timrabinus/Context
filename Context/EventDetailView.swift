//
//  EventDetailView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent?
    let calendarColor: Color
    let width: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event Header spanning both columns
            EventHeaderView(event: event)
            
            // Notes and Map in columns below
            HStack(spacing: 20) {
                // Notes column
                EventNotesView(event: event)
                    .frame(width: (width - 20) / 2)
                
                // Map View - only show if event has location
                if let selectedEvent = event,
                   let location = selectedEvent.location,
                   !location.isEmpty {
                    EventMapView(event: selectedEvent)
                        .frame(width: (width - 20) / 2)
                        .padding(.trailing, 30)
                } else {
                    // Empty space when no location
                    Color.clear
                        .frame(width: (width - 20) / 2)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: width)
    }
}

struct EventNotesView: View {
    let event: CalendarEvent?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let event = event {
                    // Notes
                    if let description = event.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                    } else {
                        Text("No notes")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    EventDetailView(
        event: CalendarEvent(
            id: "1",
            calendarId: "calendar1",
            title: "Sample Event",
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .hour, value: 2, to: Date()),
            description: "This is a sample event description.",
            location: nil
        ),
        calendarColor: .blue,
        width: 800
    )
}
