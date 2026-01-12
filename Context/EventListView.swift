//
//  EventListView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventListView: View {
    let groupedEvents: [(date: Date, events: [CalendarEvent])]
    let formatDate: (Date) -> String
    let formatTime: (Date) -> String
    let colorForCalendar: (String) -> Color
    let onEventSelect: (CalendarEvent) -> Void
    
    var body: some View {
        List {
            ForEach(groupedEvents, id: \.date) { dateGroup in
                Section(header: Text(formatDate(dateGroup.date))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .textCase(nil)
                    .padding(.top, 8)
                    .padding(.bottom, 12)) {
                    ForEach(dateGroup.events) { event in
                        EventRowView(
                            event: event,
                            calendarColor: colorForCalendar(event.calendarId),
                            formatTime: formatTime,
                            onSelect: {
                                onEventSelect(event)
                            }
                        )
                    }
                }
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
    }
}

#Preview {
    EventListView(
        groupedEvents: [
            (date: Date(), events: [
                CalendarEvent(
                    id: "1",
                    calendarId: "calendar1",
                    title: "Sample Event",
                    startDate: Date(),
                    endDate: nil,
                    description: nil,
                    location: nil
                )
            ])
        ],
        formatDate: { date in
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            return formatter.string(from: date)
        },
        formatTime: { date in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        },
        colorForCalendar: { _ in .blue },
        onEventSelect: { _ in }
    )
}
