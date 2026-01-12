//
//  CalendarService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import Combine

@MainActor
class CalendarService: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let calendars: [CalendarSource]
    
    init(calendars: [CalendarSource]? = nil) {
        self.calendars = calendars ?? CalendarSource.predefinedCalendars
    }
    
    func fetchCalendars() async {
        isLoading = true
        error = nil
        
        var allEvents: [CalendarEvent] = []
        var errors: [String] = []
        
        // Fetch all calendars concurrently
        await withTaskGroup(of: [CalendarEvent]?.self) { group in
            for calendar in calendars {
                group.addTask {
                    await self.fetchCalendar(calendar: calendar)
                }
            }
            
            for await calendarEvents in group {
                if let events = calendarEvents {
                    allEvents.append(contentsOf: events)
                } else {
                    errors.append("Failed to fetch calendar")
                }
            }
        }
        
        // Sort all events by date
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let futureDate = calendar.date(byAdding: .day, value: 14, to: today) ?? today
        events = allEvents
            .filter { $0.startDate >= today && $0.startDate <= futureDate }
            .sorted { $0.startDate < $1.startDate }
        
        if !errors.isEmpty && events.isEmpty {
            error = errors.joined(separator: "; ")
        }
        
        isLoading = false
    }
    
    private func fetchCalendar(calendar: CalendarSource) async -> [CalendarEvent]? {
        // Convert webcal:// to https://
        let httpsURL = calendar.url.replacingOccurrences(of: "webcal://", with: "https://")
        
        guard let url = URL(string: httpsURL) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let icalString = String(data: data, encoding: .utf8) {
                return parseICalendar(icalString, calendarId: calendar.id)
            }
        } catch {
            // Silently fail individual calendars
            return nil
        }
        
        return nil
    }
    
    private func parseICalendar(_ icalString: String, calendarId: String) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        var currentEvent: [String: String] = [:]
        
        let lines = icalString.components(separatedBy: .newlines)
        var inEvent = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                currentEvent = [:]
            } else if trimmed == "END:VEVENT" {
                if let event = createEvent(from: currentEvent, calendarId: calendarId) {
                    events.append(event)
                }
                inEvent = false
            } else if inEvent && !trimmed.isEmpty {
                // Handle property parameters (e.g., DTSTART;VALUE=DATE:20240101)
                let colonIndex = trimmed.firstIndex(of: ":")
                guard let colonIndex = colonIndex else { continue }
                
                let propertyPart = String(trimmed[..<colonIndex])
                let valuePart = String(trimmed[trimmed.index(after: colonIndex)...])
                
                // Extract the property name (before semicolon if present)
                let propertyName = propertyPart.components(separatedBy: ";").first ?? propertyPart
                currentEvent[propertyName] = valuePart
            }
        }
        
        return events
    }
    
    private func createEvent(from dictionary: [String: String], calendarId: String) -> CalendarEvent? {
        guard let dtStart = dictionary["DTSTART"] else {
            return nil
        }
        
        let uid = dictionary["UID"] ?? dtStart
        let title = dictionary["SUMMARY"] ?? "Untitled Event"
        let description = dictionary["DESCRIPTION"]
        let location = dictionary["LOCATION"]
        
        // Log location field if present
        if let location = location {
            print("🔍 [CalendarService] Raw LOCATION field from iCal:")
            print("🔍 [CalendarService] Length: \(location.count)")
            print("🔍 [CalendarService] String: \(location)")
            print("🔍 [CalendarService] UTF8 bytes: \(location.utf8.map { String(format: "%02x", $0) }.joined(separator: " "))")
        }
        
        let dtEnd = dictionary["DTEND"]
        
        let startDate = parseDate(from: dtStart)
        let endDate = dtEnd != nil ? parseDate(from: dtEnd!) : nil
        
        return CalendarEvent(
            id: "\(calendarId)-\(uid)",
            calendarId: calendarId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            description: description,
            location: location
        )
    }
    
    private func parseDate(from dateString: String) -> Date {
        // Handle both date-only (YYYYMMDD) and date-time (YYYYMMDDTHHMMSS) formats
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        
        // Try date-time format first (with T separator)
        if dateString.contains("T") {
            // Remove timezone suffix if present
            let cleanDateString = dateString
                .replacingOccurrences(of: "T", with: "")
                .replacingOccurrences(of: "Z", with: "")
            let trimmed = String(cleanDateString.prefix(15)) // YYYYMMDDHHMMSS
            
            formatter.dateFormat = "yyyyMMddHHmmss"
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        // Try date-only format
        let cleanDateString = dateString.prefix(8) // YYYYMMDD
        formatter.dateFormat = "yyyyMMdd"
        if let date = formatter.date(from: String(cleanDateString)) {
            return date
        }
        
        // Fallback to current date
        return Date()
    }
}
