//
//  CalendarView.swift
//  Context
//
//  Created by Martin on 24/01/2026.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var calendarService: CalendarService
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @FocusState private var focusedDay: Date?
    @State private var headerHeight: CGFloat = 0
    
    private let headerSpacing: CGFloat = 18
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        return calendar
    }
    
    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: selectedDate) ?? DateInterval(start: selectedDate, end: selectedDate)
    }

    private var monthEndDate: Date {
        calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }
    
    private var gridDates: [Date?] {
        let start = monthInterval.start
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<1
        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingBlankCount = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        return Array(repeating: nil, count: leadingBlankCount) + days
    }
    
    private var calendarColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: CalendarSource.predefinedCalendars.map { ($0.id, $0.color) })
    }
    
    private func color(for calendarId: String) -> Color {
        calendarColorMap[calendarId] ?? .gray
    }
    
    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
    
    private func isSameMonth(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, equalTo: rhs, toGranularity: .month)
    }

    private func gridIndex(for date: Date) -> Int? {
        gridDates.firstIndex { candidate in
            guard let candidate else { return false }
            return isSameDay(candidate, date)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        if hour == 0 && minute == 0 {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func updateSelection(to date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: headerSpacing) {
                    VStack(alignment: .leading, spacing: headerSpacing) {
                        Text(monthTitle)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 0) {
                            ForEach(weekdaySymbols, id: \.self) { symbol in
                                Text(symbol.uppercased())
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: CalendarHeaderHeightKey.self, value: proxy.size.height)
                        }
                    )
                    
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(gridDates.indices, id: \.self) { index in
                            if let date = gridDates[index] {
                                let column = index % 7
                                let isSelected = isSameDay(date, selectedDate)
                                Button {
                                    updateSelection(to: date)
                                } label: {
                                    Text("\(calendar.component(.day, from: date))")
                                        .font(.title3.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 54)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(isSelected ? .white : .primary)
                                .focusable(true)
                                .focused($focusedDay, equals: date)
                                .onMoveCommand { direction in
                                    switch direction {
                                    case .left where isSameDay(date, monthInterval.start):
                                        if let previous = calendar.date(byAdding: .day, value: -1, to: date) {
                                            updateSelection(to: previous)
                                            focusedDay = calendar.startOfDay(for: previous)
                                        }
                                    case .right where isSameDay(date, monthEndDate):
                                        if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                                            updateSelection(to: next)
                                            focusedDay = calendar.startOfDay(for: next)
                                        }
                                    case .left where column == 0:
                                        if let previous = calendar.date(byAdding: .day, value: -1, to: date) {
                                            updateSelection(to: previous)
                                            focusedDay = calendar.startOfDay(for: previous)
                                        }
                                    case .right where column == 6:
                                        if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                                            updateSelection(to: next)
                                            focusedDay = calendar.startOfDay(for: next)
                                        }
                                    case .up:
                                        if let previousWeek = calendar.date(byAdding: .day, value: -7, to: date),
                                           !isSameMonth(previousWeek, date) {
                                            updateSelection(to: previousWeek)
                                            focusedDay = calendar.startOfDay(for: previousWeek)
                                        }
                                    case .down:
                                        if let nextWeek = calendar.date(byAdding: .day, value: 7, to: date),
                                           !isSameMonth(nextWeek, date) {
                                            updateSelection(to: nextWeek)
                                            focusedDay = calendar.startOfDay(for: nextWeek)
                                        }
                                    default:
                                        break
                                    }
                                }
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, minHeight: 54)
                                    .focusable(false)
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.55, alignment: .topLeading)
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(selectedDate, style: .date)
                            .font(.title3.weight(.semibold))
                        Spacer()
                    }
                    .frame(height: headerHeight + headerSpacing, alignment: .topLeading)
                    
                    let dayEvents = calendarService.eventsForDay(selectedDate)
                    if dayEvents.isEmpty && calendarService.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let error = calendarService.error, dayEvents.isEmpty {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                    } else if dayEvents.isEmpty {
                        Text("No events")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(dayEvents) { event in
                                    EventListRowView(
                                        event: event,
                                        calendarColor: color(for: event.calendarId),
                                        timeText: calendarService.displayTime(for: event, on: selectedDate)
                                    )
                                    .padding(.horizontal, 6)
                                }
                            }
                        }
                    }
                }
                .frame(width: geometry.size.width * 0.35, alignment: .topLeading)
            }
            .padding(.horizontal, 40)
            .padding(.top, 30)
            .padding(.bottom, 20)
            .onPreferenceChange(CalendarHeaderHeightKey.self) { value in
                headerHeight = value
            }
            .onChange(of: focusedDay) { newValue in
                if let newValue {
                    updateSelection(to: newValue)
                }
            }
            .onChange(of: selectedDate) { newValue in
                calendarService.refreshIfNeeded(for: newValue)
            }
            .task {
                calendarService.refreshIfNeeded(for: selectedDate)
                focusedDay = calendar.startOfDay(for: selectedDate)
            }
        }
    }
}

#Preview {
    CalendarView()
        .environmentObject(CalendarService())
}

private struct CalendarHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
import SwiftUI

struct CalendarLineView: View {
    let dailyForecastIcons: [String: String]
    let cachedDailyIcons: [String: String]
    let dailyForecastTemps: [String: Double]

    private var daysInMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let range = calendar.range(of: .day, in: .month, for: now)!
        return range.count
    }
    
    private var today: Int {
        let calendar = Calendar.current
        return calendar.component(.day, from: Date())
    }
    
    private func dayOfWeekLetter(for day: Int) -> String {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        guard let date = calendar.date(from: components) else { return "" }
        let weekday = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let letters = ["S", "M", "T", "W", "T", "F", "S"]
        return letters[weekday - 1]
    }

    private func isWeekend(day: Int) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        guard let date = calendar.date(from: components) else { return false }
        return calendar.isDateInWeekend(date)
    }

    private func dayTextColor(for day: Int) -> Color {
        if day == today {
            return .primary
        }
        return isWeekend(day: day) ? Color(red: 0.50, green: 0.60, blue: 0.78) : Color(white: 0.75)
    }

    private func dayOfWeekColor(for day: Int) -> Color {
        if day == today {
            return .primary
        }
        return dayOfWeekLetter(for: day) == "M" ? Color.white : dayTextColor(for: day)
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func dayDate(for day: Int) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        return calendar.date(from: components)
    }

    private func dayKey(for day: Int) -> String? {
        guard let date = dayDate(for: day) else { return nil }
        return Self.dayKeyFormatter.string(from: date)
    }

    private func iconCode(for day: Int) -> String? {
        guard let date = dayDate(for: day) else { return nil }
        let calendar = Calendar.current
        let key = dayKey(for: day)

        if date < calendar.startOfDay(for: Date()) {
            if let key, let cached = cachedDailyIcons[key] {
                return cached
            }
            return nil
        }

        if let key, let forecast = dailyForecastIcons[key] {
            return forecast
        }

        if let key, let cached = cachedDailyIcons[key] {
            return cached
        }

        return nil
    }

    private func forecastTemp(for day: Int) -> Double? {
        guard let date = dayDate(for: day) else { return nil }
        let calendar = Calendar.current
        let key = dayKey(for: day)

        if date < calendar.startOfDay(for: Date()) {
            return nil
        }

        if let key, let temp = dailyForecastTemps[key] {
            return temp
        }

        return nil
    }

    private func weatherIconName(for iconCode: String) -> String {
        // Map OpenWeatherMap icon codes to SF Symbols
        switch iconCode {
        case "01d", "01n": return "sun.max.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "cloud.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.rain.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.sun.fill"
        }
    }

    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dayWidth = totalWidth / CGFloat(daysInMonth)
            
            HStack(spacing: 0) {
                ForEach(1...daysInMonth, id: \.self) { day in
                    VStack(spacing: 4) {
                        if day == today {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)
                        }

                        // Day of week letter
                        Text(dayOfWeekLetter(for: day))
                            .font(.system(size: day == today ? 20 : 16, weight: day == today ? .bold : .regular))
                            .foregroundColor(dayOfWeekColor(for: day))
                        
                        // Date number
                        Text("\(day)")
                            .font(.system(size: day == today ? 32 : 24, weight: day == today ? .bold : .regular))
                            .foregroundColor(dayTextColor(for: day))

                        Spacer().frame(height: 6)

                        // Weather forecast icon (or dash when missing)
                        if let iconCode = iconCode(for: day) {
                            let iconSize: CGFloat = day == today ? 24 : 20
                            let iconRowHeight: CGFloat = 28
                            let iconName = weatherIconName(for: iconCode)
                            Image(systemName: iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconSize, height: iconSize)
                                .symbolRenderingMode(.multicolor)
                                .opacity(day == today ? 1.0 : 0.65)
                                .frame(height: iconRowHeight, alignment: .top)
                                .offset(y: day == today ? -10 : 0)
                        } else {
                            let iconRowHeight: CGFloat = 28
                            Text("-")
                                .font(.system(size: day == today ? 20 : 16, weight: .regular))
                                .foregroundColor(.secondary)
                                .frame(height: iconRowHeight, alignment: .top)
                        }
                        
                        let tempRowHeight: CGFloat = 18
                        if let temp = forecastTemp(for: day) {
                            Text("\(Int(temp))°")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(day == today ? .secondary : .tertiary)
                                .frame(height: tempRowHeight, alignment: .center)
                        } else {
                            Color.clear
                                .frame(height: tempRowHeight)
                        }
                    }
                    .frame(width: dayWidth)
                }
            }
        }
        .frame(height: 110)
    }
}
