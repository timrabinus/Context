//
//  EventsView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI

struct EventsView: View {
    @EnvironmentObject private var calendarService: CalendarService
    @State private var selectedEvent: CalendarEvent?
    @FocusState private var focusedEventId: String?
    
    private var calendarColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: CalendarSource.predefinedCalendars.map { ($0.id, $0.color) })
    }
    
    private var calendarNameMap: [String: String] {
        Dictionary(uniqueKeysWithValues: CalendarSource.predefinedCalendars.map { ($0.id, $0.name) })
    }
    
    private func color(for calendarId: String) -> Color {
        calendarColorMap[calendarId] ?? .gray
    }
    
    private func name(for calendarId: String) -> String? {
        calendarNameMap[calendarId]
    }
    
    private var groupedEvents: [(date: Date, events: [CalendarEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: calendarService.events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        
        return grouped.sorted { $0.key < $1.key }
            .map { (date: $0.key, events: $0.value.sorted { $0.startDate < $1.startDate }) }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        if hour == 0 && minute == 0 {
            return "All Day"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Event List
                VStack(alignment: .leading, spacing: 0) {
                    if calendarService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if let error = calendarService.error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else if calendarService.events.isEmpty {
                        Text("No upcoming events")
                            .padding()
                    } else {
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
                                            calendarColor: color(for: event.calendarId),
                                            formatTime: formatTime,
                                            onSelect: {
                                                selectedEvent = event
                                            }
                                        )
                                        .focused($focusedEventId, equals: event.id)
                                    }
                                }
                            }
                        }
                        .padding(.leading, 20)
                        .padding(.trailing, 20)
                        .onChange(of: focusedEventId) { newValue in
                            if let newValue = newValue {
                                selectedEvent = calendarService.events.first { $0.id == newValue }
                            }
                        }
                        .onChange(of: calendarService.events) { newValue in
                            // Set focus on first event when events are loaded
                            if !newValue.isEmpty && focusedEventId == nil {
                                focusedEventId = newValue.first?.id
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width / 3 - 30)
                .padding(.leading, 30)
                .padding(.trailing, 30)
                
                // Spacer between columns
                Spacer()
                    .frame(width: 60)
                
                // Event Detail Panel
                GeometryReader { detailGeometry in
                    EventDetailView(
                        event: selectedEvent,
                        calendarColor: selectedEvent.map { color(for: $0.calendarId) } ?? .gray,
                        calendarName: selectedEvent.flatMap { name(for: $0.calendarId) },
                        width: detailGeometry.size.width - 30
                    )
                    .padding(.trailing, 30)
                }
            }
        }
    }
}

#Preview {
    EventsView()
        .environmentObject(CalendarService())
}
