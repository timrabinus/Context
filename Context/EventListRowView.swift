//
//  EventListRowView.swift
//  Context
//
//  Created by Martin on 24/01/2026.
//

import SwiftUI

struct EventListRowView: View {
    let event: CalendarEvent
    let calendarColor: Color
    let timeText: String
    var timeWidth: CGFloat = 110
    var onSelect: (() -> Void)?
    
    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 12) {
            Text(timeText)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: timeWidth, alignment: .trailing)
                .lineLimit(1)
            
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
    
    var body: some View {
        if let onSelect {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }
}

#Preview {
    EventListRowView(
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
        timeText: "09:00"
    )
}
