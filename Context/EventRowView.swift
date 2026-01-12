//
//  EventRowView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventRowView: View {
    let event: CalendarEvent
    let calendarColor: Color
    let formatTime: (Date) -> String
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(formatTime(event.startDate))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)
                
                Rectangle()
                    .fill(calendarColor)
                    .frame(width: 4)
                
                Text(event.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EventRowView(
        event: CalendarEvent(
            id: "1",
            calendarId: "calendar1",
            title: "Sample Event",
            startDate: Date(),
            endDate: nil,
            description: nil,
            location: nil
        ),
        calendarColor: .blue,
        formatTime: { date in
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        },
        onSelect: {}
    )
}
