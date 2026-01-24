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
    @Published private(set) var cachedEventsByDay: [String: [CalendarEvent]] = [:]
    @Published var isLoading = false
    @Published var error: String?
    
    private let calendars: [CalendarSource]
    private var cachedMonthKey: String?
    private var isRefreshing = false
    private let cacheKey = "calendarEventCache.v1"
    
    init(calendars: [CalendarSource]? = nil) {
        self.calendars = calendars ?? CalendarSource.predefinedCalendars
        loadCache()
    }
    
    func fetchCalendars(for date: Date = Date()) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        isLoading = true
        error = nil
        
        defer {
            isRefreshing = false
            isLoading = false
        }
        
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
        let monthInterval = calendar.dateInterval(of: .month, for: date)
        let monthStart = monthInterval?.start ?? date
        let monthEnd = monthInterval?.end ?? date
        let monthEvents = allEvents
            .filter { $0.startDate >= monthStart && $0.startDate < monthEnd }
            .sorted { $0.startDate < $1.startDate }
        
        events = monthEvents
        cache(events: monthEvents, monthKey: monthKey(for: date))
        
        if !errors.isEmpty && events.isEmpty {
            error = errors.joined(separator: "; ")
        }
    }
    
    func eventsForDay(_ date: Date) -> [CalendarEvent] {
        let key = dayKey(for: date)
        if let cached = cachedEventsByDay[key] {
            return cached
        }
        
        return events
            .filter { eventOccurs($0, on: date) }
            .sorted { eventSort($0, $1, on: date) }
    }
    
    func refreshIfNeeded(for date: Date) {
        let key = monthKey(for: date)
        guard cachedMonthKey != key else { return }
        guard !isRefreshing else { return }
        Task {
            await fetchCalendars(for: date)
        }
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
        
        let rawLines = icalString.components(separatedBy: .newlines)
        let lines = unfoldLines(rawLines)
        var inEvent = false
        var lastPropertyName: String?
        let knownProperties: Set<String> = [
            "DTSTART",
            "DTEND",
            "UID",
            "SUMMARY",
            "DESCRIPTION",
            "LOCATION"
        ]
        
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
                lastPropertyName = nil
            } else if inEvent && !trimmed.isEmpty {
                if trimmed.firstIndex(of: ":") == nil {
                    if lastPropertyName == "DESCRIPTION",
                       let existing = currentEvent["DESCRIPTION"] {
                        currentEvent["DESCRIPTION"] = existing + "\n" + trimmed
                    }
                    continue
                }
                
                // Handle property parameters (e.g., DTSTART;VALUE=DATE:20240101)
                let colonIndex = trimmed.firstIndex(of: ":")
                guard let colonIndex = colonIndex else { continue }
                
                let propertyPart = String(trimmed[..<colonIndex])
                let valuePart = String(trimmed[trimmed.index(after: colonIndex)...])
                
                // Extract the property name (before semicolon if present)
                let propertyName = propertyPart.components(separatedBy: ";").first ?? propertyPart
                if lastPropertyName == "DESCRIPTION",
                   !knownProperties.contains(propertyName) {
                    let appendedLine = "\(propertyName):\(valuePart)"
                    if let existing = currentEvent["DESCRIPTION"] {
                        currentEvent["DESCRIPTION"] = existing + "\n" + appendedLine
                    } else {
                        currentEvent["DESCRIPTION"] = appendedLine
                    }
                    continue
                }
                
                currentEvent[propertyName] = valuePart
                lastPropertyName = propertyName
            }
        }
        
        return events
    }
    
    private func unfoldLines(_ lines: [String]) -> [String] {
        var unfolded: [String] = []
        
        for line in lines {
            if let last = unfolded.last, line.hasPrefix(" ") || line.hasPrefix("\t") {
                unfolded[unfolded.count - 1] = last + line.dropFirst()
            } else {
                unfolded.append(line)
            }
        }
        
        return unfolded
    }
    
    private func unescapeICalText(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        
        while let character = iterator.next() {
            if character == "\\" {
                guard let next = iterator.next() else { break }
                switch next {
                case "n", "N":
                    result.append("\n")
                case ",":
                    result.append(",")
                case ";":
                    result.append(";")
                case "\\":
                    result.append("\\")
                default:
                    result.append(next)
                }
            } else {
                result.append(character)
            }
        }
        
        return result
    }
    
    private func normalizeICalText(_ text: String) -> String {
        var normalized = text
        
        for _ in 0..<2 {
            let unescaped = unescapeICalText(normalized)
            if unescaped == normalized {
                break
            }
            normalized = unescaped
        }
        
        normalized = normalized
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
        
        return normalized
    }
    
    private func createEvent(from dictionary: [String: String], calendarId: String) -> CalendarEvent? {
        guard let dtStart = dictionary["DTSTART"] else {
            return nil
        }
        
        let uid = dictionary["UID"] ?? dtStart
        let title = dictionary["SUMMARY"] ?? "Untitled Event"
        let description = dictionary["DESCRIPTION"].map { normalizeICalText($0) }
        let location = dictionary["LOCATION"].map { normalizeICalText($0) }
        
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
    
    private func cache(events: [CalendarEvent], monthKey: String) {
        var grouped: [String: [CalendarEvent]] = [:]
        for event in events {
            for day in coveredDays(for: event) {
                let key = dayKey(for: day)
                grouped[key, default: []].append(event)
            }
        }
        
        for (key, value) in grouped {
            if let day = Self.dayKeyFormatter.date(from: key) {
                grouped[key] = value.sorted { eventSort($0, $1, on: day) }
            } else {
                grouped[key] = value.sorted { $0.startDate < $1.startDate }
            }
        }
        
        cachedEventsByDay = grouped
        cachedMonthKey = monthKey
        
        let cache = CalendarEventCache(monthKey: monthKey, eventsByDay: grouped)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    private func loadCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let cache = try? decoder.decode(CalendarEventCache.self, from: data) else {
            return
        }
        
        let currentMonthKey = monthKey(for: Date())
        guard cache.monthKey == currentMonthKey else {
            return
        }
        
        cachedEventsByDay = cache.eventsByDay
        cachedMonthKey = cache.monthKey
        events = cache.eventsByDay.values
            .flatMap { $0 }
            .sorted { $0.startDate < $1.startDate }
    }
    
    private func dayKey(for date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
    }
    
    private func monthKey(for date: Date) -> String {
        Self.monthKeyFormatter.string(from: date)
    }
    
    private struct CalendarEventCache: Codable {
        let monthKey: String
        let eventsByDay: [String: [CalendarEvent]]
    }
    
    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
    
    private func eventOccurs(_ event: CalendarEvent, on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        if let endDate = event.endDate {
            return event.startDate < nextDay && endDate > dayStart
        }
        
        return calendar.isDate(event.startDate, inSameDayAs: date)
    }
    
    private func coveredDays(for event: CalendarEvent) -> [Date] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: event.startDate)
        
        guard let endDate = event.endDate else {
            return [startDay]
        }
        
        let endDay = calendar.startOfDay(for: endDate)
        let lastIncludedDay: Date
        
        if endDate == endDay {
            lastIncludedDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? startDay
        } else {
            lastIncludedDay = endDay
        }
        
        if lastIncludedDay < startDay {
            return [startDay]
        }
        
        var days: [Date] = []
        var current = startDay
        while current <= lastIncludedDay {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            if current == days.last {
                break
            }
        }
        
        return days
    }

    private func eventSort(_ lhs: CalendarEvent, _ rhs: CalendarEvent, on date: Date) -> Bool {
        let lhsTiming = timingForDisplay(lhs, on: date)
        let rhsTiming = timingForDisplay(rhs, on: date)
        
        if lhsTiming.isAllDay != rhsTiming.isAllDay {
            return lhsTiming.isAllDay
        }
        
        if lhsTiming.time != rhsTiming.time {
            return lhsTiming.time < rhsTiming.time
        }
        
        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
    
    private func isAllDay(_ event: CalendarEvent) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: event.startDate)
        return (components.hour ?? 0) == 0 && (components.minute ?? 0) == 0
    }

    private func timingForDisplay(_ event: CalendarEvent, on date: Date) -> (isAllDay: Bool, time: Date) {
        if isAllDay(event) {
            return (true, event.startDate)
        }
        
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        
        guard let endDate = event.endDate else {
            return (false, event.startDate)
        }
        
        let startDay = calendar.startOfDay(for: event.startDate)
        let endDay = calendar.startOfDay(for: endDate)
        let lastIncludedDay: Date
        
        if endDate == endDay {
            lastIncludedDay = calendar.date(byAdding: .day, value: -1, to: endDay) ?? startDay
        } else {
            lastIncludedDay = endDay
        }
        
        if dayStart > startDay && dayStart < lastIncludedDay {
            return (true, event.startDate)
        }
        
        if calendar.isDate(event.startDate, inSameDayAs: date) {
            return (false, event.startDate)
        }
        
        if calendar.isDate(endDate, inSameDayAs: date) {
            return (false, endDate)
        }
        
        return (false, event.startDate)
    }
    
    func displayTime(for event: CalendarEvent, on date: Date) -> String {
        let timing = timingForDisplay(event, on: date)
        if timing.isAllDay {
            return "All Day"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: timing.time)
    }
}
