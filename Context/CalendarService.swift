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
        
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)
        let monthStart = monthInterval?.start ?? date
        let monthEnd = monthInterval?.end ?? date
        
        // Fetch all calendars concurrently
        await withTaskGroup(of: [CalendarEvent]?.self) { group in
            for calendar in calendars {
                group.addTask {
                    await self.fetchCalendar(calendar: calendar, monthStart: monthStart, monthEnd: monthEnd)
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
        let monthEvents = allEvents
            .filter { eventOverlapsRange($0, start: monthStart, end: monthEnd) }
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
    
    private func fetchCalendar(calendar: CalendarSource, monthStart: Date, monthEnd: Date) async -> [CalendarEvent]? {
        // Convert webcal:// to https://
        let httpsURL = calendar.url.replacingOccurrences(of: "webcal://", with: "https://")
        
        guard let url = URL(string: httpsURL) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let icalString = String(data: data, encoding: .utf8) {
                return parseICalendar(icalString, calendarId: calendar.id, monthStart: monthStart, monthEnd: monthEnd)
            }
        } catch {
            // Silently fail individual calendars
            return nil
        }
        
        return nil
    }
    
    private func parseICalendar(_ icalString: String, calendarId: String, monthStart: Date, monthEnd: Date) -> [CalendarEvent] {
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
            "LOCATION",
            "RRULE"
        ]
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed == "BEGIN:VEVENT" {
                inEvent = true
                currentEvent = [:]
            } else if trimmed == "END:VEVENT" {
                let createdEvents = createEvents(from: currentEvent, calendarId: calendarId, monthStart: monthStart, monthEnd: monthEnd)
                events.append(contentsOf: createdEvents)
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
    
    private func createEvents(from dictionary: [String: String], calendarId: String, monthStart: Date, monthEnd: Date) -> [CalendarEvent] {
        guard let dtStart = dictionary["DTSTART"] else {
            return []
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
        
        let baseEvent = CalendarEvent(
            id: "\(calendarId)-\(uid)",
            calendarId: calendarId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            description: description,
            location: location
        )
        
        guard let rrule = dictionary["RRULE"] else {
            return [baseEvent]
        }
        
        return expandRecurringEvents(
            baseEvent: baseEvent,
            rrule: rrule,
            monthStart: monthStart,
            monthEnd: monthEnd
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

    // Recurrence gaps:
    // - EXDATE/EXRULE and RDATE are not applied.
    // - BYSETPOS, BYWEEKNO, BYYEARDAY are not supported.
    // - BYHOUR/BYMINUTE/BYSECOND are not supported (event time from DTSTART).
    // - WKST is ignored (uses the system calendar week start).
    private func expandRecurringEvents(
        baseEvent: CalendarEvent,
        rrule: String,
        monthStart: Date,
        monthEnd: Date
    ) -> [CalendarEvent] {
        let rule = parseRRule(rrule)
        let calendar = Calendar.current
        let startDate = baseEvent.startDate
        let duration = baseEvent.endDate.map { $0.timeIntervalSince(startDate) } ?? 0
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: startDate)
        let interval = max(rule.interval, 1)
        var occurrences: [CalendarEvent] = []
        var remainingCount = rule.count ?? Int.max
        
        func addOccurrence(_ occurrenceStart: Date) {
            if remainingCount <= 0 { return }
            if occurrenceStart < startDate { return }
            if let until = rule.until, occurrenceStart > until { return }
            
            let occurrenceEnd = duration > 0 ? occurrenceStart.addingTimeInterval(duration) : baseEvent.endDate
            if !occurrenceOverlaps(occurrenceStart: occurrenceStart, occurrenceEnd: occurrenceEnd, monthStart: monthStart, monthEnd: monthEnd) {
                return
            }
            
            let occurrenceId = "\(baseEvent.id)-\(dayKey(for: occurrenceStart))"
            let occurrence = CalendarEvent(
                id: occurrenceId,
                calendarId: baseEvent.calendarId,
                title: baseEvent.title,
                startDate: occurrenceStart,
                endDate: occurrenceEnd,
                description: baseEvent.description,
                location: baseEvent.location
            )
            
            occurrences.append(occurrence)
            remainingCount -= 1
        }
        
        switch rule.frequency {
        case "DAILY":
            let daysBetween = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: monthStart)).day ?? 0
            let offset = max(0, daysBetween)
            let remainder = offset % interval
            let firstOffset = remainder == 0 ? offset : offset + (interval - remainder)
            
            var current = calendar.date(byAdding: .day, value: firstOffset, to: startDate) ?? startDate
            while current < monthEnd && remainingCount > 0 {
                addOccurrence(current)
                current = calendar.date(byAdding: .day, value: interval, to: current) ?? current.addingTimeInterval(86400)
            }
            
        case "WEEKLY":
            let byDays = rule.byDays.isEmpty
                ? [calendar.component(.weekday, from: startDate)]
                : rule.byDays
            
            let startWeek = calendar.dateInterval(of: .weekOfYear, for: startDate)?.start ?? startDate
            let targetWeek = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
            let weeksBetween = calendar.dateComponents([.weekOfYear], from: startWeek, to: targetWeek).weekOfYear ?? 0
            let startOffset = max(0, weeksBetween)
            let remainder = startOffset % interval
            var weekOffset = remainder == 0 ? startOffset : startOffset + (interval - remainder)
            
            while remainingCount > 0 {
                guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startWeek) else {
                    break
                }
                
                if weekStart >= monthEnd {
                    break
                }
                
                if let until = rule.until, weekStart > until {
                    break
                }
                
                for weekday in byDays {
                    let dayOffset = (weekday - calendar.firstWeekday + 7) % 7
                    guard let occurrenceDay = calendar.date(byAdding: .day, value: dayOffset, to: weekStart),
                          let occurrenceStart = calendar.date(
                            bySettingHour: timeComponents.hour ?? 0,
                            minute: timeComponents.minute ?? 0,
                            second: timeComponents.second ?? 0,
                            of: occurrenceDay
                          ) else {
                        continue
                    }
                    
                    addOccurrence(occurrenceStart)
                    if remainingCount <= 0 {
                        break
                    }
                }
                
                weekOffset += interval
            }
            
        case "MONTHLY":
            let byMonthDays = rule.byMonthDays
            let byDays = rule.byDays
            let byDayOrdinals = rule.byDayOrdinals
            
            let startMonth = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate
            let targetMonth = calendar.dateInterval(of: .month, for: monthStart)?.start ?? monthStart
            let monthsBetween = calendar.dateComponents([.month], from: startMonth, to: targetMonth).month ?? 0
            let startOffset = max(0, monthsBetween)
            let remainder = startOffset % interval
            var monthOffset = remainder == 0 ? startOffset : startOffset + (interval - remainder)
            
            while remainingCount > 0 {
                guard let monthStartDate = calendar.date(byAdding: .month, value: monthOffset, to: startMonth) else {
                    break
                }
                
                if monthStartDate >= monthEnd {
                    break
                }
                
                if let until = rule.until, monthStartDate > until {
                    break
                }
                
                let monthRange = calendar.range(of: .day, in: .month, for: monthStartDate) ?? 1..<1
                var candidateDays: [Int] = []
                
                if !byMonthDays.isEmpty {
                    candidateDays = resolveMonthDays(byMonthDays, monthRange: monthRange)
                } else if !byDayOrdinals.isEmpty {
                    candidateDays = resolveOrdinalWeekdays(byDayOrdinals, in: monthStartDate, monthRange: monthRange)
                } else if !byDays.isEmpty {
                    candidateDays = resolveWeekdays(byDays, in: monthStartDate, monthRange: monthRange)
                } else {
                    candidateDays = [calendar.component(.day, from: startDate)].filter { monthRange.contains($0) }
                }
                
                for day in candidateDays.sorted() {
                    guard let occurrenceDay = calendar.date(byAdding: .day, value: day - 1, to: monthStartDate),
                          let occurrenceStart = calendar.date(
                            bySettingHour: timeComponents.hour ?? 0,
                            minute: timeComponents.minute ?? 0,
                            second: timeComponents.second ?? 0,
                            of: occurrenceDay
                          ) else {
                        continue
                    }
                    
                    addOccurrence(occurrenceStart)
                    if remainingCount <= 0 {
                        break
                    }
                }
                
                monthOffset += interval
            }
            
        case "YEARLY":
            let byMonths = rule.byMonths
            let byMonthDays = rule.byMonthDays
            let byDays = rule.byDays
            let byDayOrdinals = rule.byDayOrdinals
            
            let startYear = calendar.dateInterval(of: .year, for: startDate)?.start ?? startDate
            let targetYear = calendar.dateInterval(of: .year, for: monthStart)?.start ?? monthStart
            let yearsBetween = calendar.dateComponents([.year], from: startYear, to: targetYear).year ?? 0
            let startOffset = max(0, yearsBetween)
            let remainder = startOffset % interval
            var yearOffset = remainder == 0 ? startOffset : startOffset + (interval - remainder)
            
            while remainingCount > 0 {
                guard let yearStart = calendar.date(byAdding: .year, value: yearOffset, to: startYear) else {
                    break
                }
                
                if yearStart >= monthEnd {
                    break
                }
                
                if let until = rule.until, yearStart > until {
                    break
                }
                
                let months = byMonths.isEmpty ? [calendar.component(.month, from: startDate)] : byMonths
                
                for month in months.sorted() {
                    var components = calendar.dateComponents([.year], from: yearStart)
                    components.month = month
                    components.day = 1
                    guard let monthStartDate = calendar.date(from: components) else { continue }
                    let monthRange = calendar.range(of: .day, in: .month, for: monthStartDate) ?? 1..<1
                    var candidateDays: [Int] = []
                    
                    if !byMonthDays.isEmpty {
                        candidateDays = resolveMonthDays(byMonthDays, monthRange: monthRange)
                    } else if !byDayOrdinals.isEmpty {
                        candidateDays = resolveOrdinalWeekdays(byDayOrdinals, in: monthStartDate, monthRange: monthRange)
                    } else if !byDays.isEmpty {
                        candidateDays = resolveWeekdays(byDays, in: monthStartDate, monthRange: monthRange)
                    } else {
                        candidateDays = [calendar.component(.day, from: startDate)].filter { monthRange.contains($0) }
                    }
                    
                    for day in candidateDays.sorted() {
                        guard let occurrenceDay = calendar.date(byAdding: .day, value: day - 1, to: monthStartDate),
                              let occurrenceStart = calendar.date(
                                bySettingHour: timeComponents.hour ?? 0,
                                minute: timeComponents.minute ?? 0,
                                second: timeComponents.second ?? 0,
                                of: occurrenceDay
                              ) else {
                            continue
                        }
                        
                        addOccurrence(occurrenceStart)
                        if remainingCount <= 0 {
                            break
                        }
                    }
                    
                    if remainingCount <= 0 {
                        break
                    }
                }
                
                yearOffset += interval
            }
            
        default:
            return [baseEvent]
        }
        
        return occurrences.isEmpty ? [baseEvent] : occurrences
    }
    
    private func occurrenceOverlaps(
        occurrenceStart: Date,
        occurrenceEnd: Date?,
        monthStart: Date,
        monthEnd: Date
    ) -> Bool {
        if let occurrenceEnd {
            return occurrenceStart < monthEnd && occurrenceEnd > monthStart
        }
        
        return occurrenceStart >= monthStart && occurrenceStart < monthEnd
    }

    private func eventOverlapsRange(_ event: CalendarEvent, start: Date, end: Date) -> Bool {
        if let endDate = event.endDate {
            return event.startDate < end && endDate > start
        }
        
        return event.startDate >= start && event.startDate < end
    }
    
    private func parseRRule(_ rrule: String) -> RecurrenceRule {
        let parts = rrule.split(separator: ";")
        var frequency: String?
        var interval = 1
        var byDays: [Int] = []
        var byDayOrdinals: [(weekday: Int, ordinal: Int?)] = []
        var byMonthDays: [Int] = []
        var byMonths: [Int] = []
        var count: Int?
        var until: Date?
        
        for part in parts {
            let components = part.split(separator: "=", maxSplits: 1)
            guard components.count == 2 else { continue }
            let key = components[0].uppercased()
            let value = String(components[1])
            
            switch key {
            case "FREQ":
                frequency = value.uppercased()
            case "INTERVAL":
                interval = Int(value) ?? 1
            case "BYDAY":
                let entries = value.split(separator: ",")
                for entry in entries {
                    let token = String(entry)
                    if let parsed = parseOrdinalWeekday(token) {
                        byDayOrdinals.append(parsed)
                        if parsed.ordinal == nil {
                            byDays.append(parsed.weekday)
                        }
                    } else if let weekday = weekdayFromRRule(token) {
                        byDays.append(weekday)
                        byDayOrdinals.append((weekday: weekday, ordinal: nil))
                    }
                }
            case "BYMONTHDAY":
                byMonthDays = value
                    .split(separator: ",")
                    .compactMap { Int($0) }
            case "BYMONTH":
                byMonths = value
                    .split(separator: ",")
                    .compactMap { Int($0) }
            case "COUNT":
                count = Int(value)
            case "UNTIL":
                until = parseDate(from: value)
            default:
                break
            }
        }
        
        return RecurrenceRule(
            frequency: frequency ?? "",
            interval: interval,
            byDays: byDays,
            byDayOrdinals: byDayOrdinals,
            byMonthDays: byMonthDays,
            byMonths: byMonths,
            count: count,
            until: until
        )
    }
    
    private func weekdayFromRRule(_ value: String) -> Int? {
        switch value.uppercased() {
        case "SU": return 1
        case "MO": return 2
        case "TU": return 3
        case "WE": return 4
        case "TH": return 5
        case "FR": return 6
        case "SA": return 7
        default: return nil
        }
    }
    
    private func parseOrdinalWeekday(_ value: String) -> (weekday: Int, ordinal: Int?)? {
        let upper = value.uppercased()
        let weekdayCode = String(upper.suffix(2))
        guard let weekday = weekdayFromRRule(weekdayCode) else { return nil }
        let prefix = String(upper.dropLast(2))
        if prefix.isEmpty {
            return (weekday: weekday, ordinal: nil)
        }
        if let ordinal = Int(prefix) {
            return (weekday: weekday, ordinal: ordinal)
        }
        return nil
    }
    
    private struct RecurrenceRule {
        let frequency: String
        let interval: Int
        let byDays: [Int]
        let byDayOrdinals: [(weekday: Int, ordinal: Int?)]
        let byMonthDays: [Int]
        let byMonths: [Int]
        let count: Int?
        let until: Date?
    }

    private func resolveMonthDays(_ byMonthDays: [Int], monthRange: Range<Int>) -> [Int] {
        let lastDay = monthRange.count
        var resolved: [Int] = []
        for day in byMonthDays {
            if day > 0 {
                if monthRange.contains(day) {
                    resolved.append(day)
                }
            } else if day < 0 {
                let computed = lastDay + day + 1
                if monthRange.contains(computed) {
                    resolved.append(computed)
                }
            }
        }
        return resolved
    }
    
    private func resolveWeekdays(_ byDays: [Int], in monthStartDate: Date, monthRange: Range<Int>) -> [Int] {
        let calendar = Calendar.current
        var days: [Int] = []
        for day in monthRange {
            guard let candidateDate = calendar.date(byAdding: .day, value: day - 1, to: monthStartDate) else { continue }
            let weekday = calendar.component(.weekday, from: candidateDate)
            if byDays.contains(weekday) {
                days.append(day)
            }
        }
        return days
    }
    
    private func resolveOrdinalWeekdays(
        _ ordinals: [(weekday: Int, ordinal: Int?)],
        in monthStartDate: Date,
        monthRange: Range<Int>
    ) -> [Int] {
        let calendar = Calendar.current
        var days: [Int] = []
        let lastDay = monthRange.count
        
        for entry in ordinals {
            guard let ordinal = entry.ordinal else { continue }
            let weekday = entry.weekday
            if ordinal > 0 {
                var count = 0
                for day in monthRange {
                    guard let candidateDate = calendar.date(byAdding: .day, value: day - 1, to: monthStartDate) else { continue }
                    if calendar.component(.weekday, from: candidateDate) == weekday {
                        count += 1
                        if count == ordinal {
                            days.append(day)
                            break
                        }
                    }
                }
            } else if ordinal < 0 {
                var count = 0
                var day = lastDay
                while day >= monthRange.lowerBound {
                    guard let candidateDate = calendar.date(byAdding: .day, value: day - 1, to: monthStartDate) else {
                        day -= 1
                        continue
                    }
                    if calendar.component(.weekday, from: candidateDate) == weekday {
                        count += 1
                        if count == abs(ordinal) {
                            days.append(day)
                            break
                        }
                    }
                    day -= 1
                }
            }
        }
        
        return days.sorted()
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
