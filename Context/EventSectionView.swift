//
//  EventSectionView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventSectionView: View {
    let dateGroup: (date: Date, events: [CalendarEvent])
    let formatDate: (Date) -> String
    let formatTime: (Date) -> String
    let colorForCalendar: (String) -> Color
    let onEventSelect: (CalendarEvent) -> Void
    
    var body: some View {
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

#Preview {
    List {
        EventSectionView(
            dateGroup: (
                date: Date(),
                events: [
                    CalendarEvent(
                        id: "1",
                        calendarId: "calendar1",
                        title: "Sample Event",
                        startDate: Date(),
                        endDate: nil,
                        description: nil,
                        location: nil
                    )
                ]
            ),
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
}
