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
