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
    let calendarName: String?
    let width: CGFloat
    
    var body: some View {
        let hasRouteInNotes = event?.description?
            .lowercased()
            .contains("from:") == true &&
            event?.description?
            .lowercased()
            .contains("to:") == true
        let shouldShowMap = (event?.location?.isEmpty == false) || hasRouteInNotes
        
        VStack(alignment: .leading, spacing: 0) {
            // Event Header spanning both columns
            EventHeaderView(
                event: event,
                calendarName: calendarName,
                calendarColor: calendarColor
            )
            
            // Notes and Map in columns below
            HStack(alignment: .top, spacing: 20) {
                // Notes column
                EventNotesView(event: event)
                    .frame(width: (width - 20) / 2)
                
                // Map View - show when location or From/To notes exist
                if let selectedEvent = event, shouldShowMap {
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
    
    private func notesWithoutDirections(_ notes: String?) -> String? {
        guard let notes, !notes.isEmpty else {
            return nil
        }
        
        let pattern = "(?is)(^|\\n)\\s*(from|to)\\s*:\\s*.*?(?=\\n\\s*(from|to)\\s*:|\\n\\s*\\n|$)"
        let range = NSRange(notes.startIndex..<notes.endIndex, in: notes)
        let stripped = (try? NSRegularExpression(pattern: pattern))?
            .stringByReplacingMatches(in: notes, range: range, withTemplate: "") ?? notes
        
        let joined = stripped
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return joined.isEmpty ? nil : joined
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let event = event {
                    // Notes
                    if let description = notesWithoutDirections(event.description) {
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
        calendarName: "Family",
        width: 800
    )
}
