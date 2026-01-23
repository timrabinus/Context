import SwiftUI

struct DayGraphView: View {
    let tides: [TideEvent]
    let isLoading: Bool
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let hourlyForecast: [HourlyWeatherData]
    let todayEvents: [CalendarEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                
                Spacer()
                
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(white: 0.7))
                Image(systemName: "water.waves")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)
                Image(systemName: "thermometer")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if tides.isEmpty {
                Text("No tide data available")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
            } else {
                DayGraphWaveView(
                    tides: tides,
                    sunTimes: sunTimes,
                    moonTimes: moonTimes,
                    hourlyForecast: hourlyForecast,
                    todayEvents: todayEvents
                )
                .frame(height: 360)
            }
        }
        .padding(24)
        .background(Color(white: 0.75).opacity(0.25))
        .cornerRadius(16)
    }
}

struct DayGraphWaveView: View {
    let tides: [TideEvent]
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let hourlyForecast: [HourlyWeatherData]
    let todayEvents: [CalendarEvent]
    
    private var phaseOffset: Double {
        // Find the first high tide to determine phase
        guard let firstHighTide = tides.first(where: { $0.type == .high }) else {
            // If no high tide, use first tide
            guard let firstTide = tides.first else { return 0 }
            let calendar = Calendar.current
            let components = calendar.dateComponents([.hour, .minute], from: firstTide.time)
            let hours = Double(components.hour ?? 0)
            let minutes = Double(components.minute ?? 0)
            let totalHours = hours + minutes / 60.0
            // For low tide, we want it at the bottom, so phase should put it at -π/2
            return -Double.pi / 2 - (totalHours / 24.0 * 2 * Double.pi) + Double.pi
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: firstHighTide.time)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0)
        let totalHours = hours + minutes / 60.0
        
        // Convert time to phase offset
        // We want sin(2π * timeRatio + phase) = 1 (peak) when timeRatio = totalHours/24
        // sin(π/2) = 1, so: 2π * totalHours/24 + phase = π/2
        // Therefore: phase = π/2 - 2π * totalHours/24
        let phase = Double.pi / 2 - (totalHours / 24.0 * 2 * Double.pi)
        return phase
    }
    
    private func hourPosition(_ date: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0)
        let totalHours = hours + minutes / 60.0
        return CGFloat(totalHours / 24.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DayGraphContent(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    tides: tides,
                    sunTimes: sunTimes,
                    moonTimes: moonTimes,
                    phaseOffset: phaseOffset,
                    hourPosition: hourPosition,
                    hourlyForecast: hourlyForecast,
                    todayEvents: todayEvents
                )
            }
        }
    }
}

struct CurrentTimeDot: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    let width: CGFloat
    let centerY: CGFloat
    let hourPosition: (Date) -> CGFloat
    
    var body: some View {
        let x = hourPosition(currentTime) * width
        
        VStack(spacing: 4) {
            Circle()
                .fill(Color.primary)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            Text(currentTime, style: .time)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .position(x: x, y: centerY + 15)
        .onAppear {
            currentTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

struct DayGraphContent: View {
    let width: CGFloat
    let height: CGFloat
    let tides: [TideEvent]
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let phaseOffset: Double
    let hourPosition: (Date) -> CGFloat
    let hourlyForecast: [HourlyWeatherData]
    let todayEvents: [CalendarEvent]
    
    private var calendarColorMap: [String: Color] {
        Dictionary(uniqueKeysWithValues: CalendarSource.predefinedCalendars.map { ($0.id, $0.color) })
    }
    
    private func color(for calendarId: String) -> Color {
        calendarColorMap[calendarId] ?? .gray
    }
    
    private var wakeTime: Date {
        let defaults = UserDefaults.standard
        let wakeSeconds = defaults.double(forKey: "wakeTime")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .second, value: Int(wakeSeconds), to: startOfDay) ?? startOfDay
    }
    
    private var sleepTime: Date {
        let defaults = UserDefaults.standard
        let sleepSeconds = defaults.double(forKey: "sleepTime")
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .second, value: Int(sleepSeconds), to: startOfDay) ?? startOfDay
    }
    
    private var wakeX: CGFloat {
        hourPosition(wakeTime) * width
    }
    
    private var sleepX: CGFloat {
        hourPosition(sleepTime) * width
    }
    
    private var centerY: CGFloat {
        height / 2
    }
    
    private var amplitude: CGFloat {
        height * 0.35
    }
    
    private var sunriseX: CGFloat? {
        guard let sunTimes = sunTimes else { return nil }
        return hourPosition(sunTimes.sunrise) * width
    }
    
    private var sunsetX: CGFloat? {
        guard let sunTimes = sunTimes else { return nil }
        return hourPosition(sunTimes.sunset) * width
    }
    
    private var noonX: CGFloat? {
        guard let sunTimes = sunTimes else { return nil }
        let calendar = Calendar.current
        var noonComponents = calendar.dateComponents([.year, .month, .day], from: sunTimes.sunrise)
        noonComponents.hour = 12
        noonComponents.minute = 0
        guard let noon = calendar.date(from: noonComponents) else { return nil }
        return hourPosition(noon) * width
    }
    
    private var moonriseX: CGFloat? {
        guard let moonTimes = moonTimes else { return nil }
        return hourPosition(moonTimes.moonrise) * width
    }
    
    private var moonsetX: CGFloat? {
        guard let moonTimes = moonTimes else { return nil }
        return hourPosition(moonTimes.moonset) * width
    }
    
    private var moonPeakX: CGFloat? {
        guard let moonTimes = moonTimes else { return nil }
        // Calculate midpoint between moonrise and moonset
        let calendar = Calendar.current
        let moonriseHour = Double(calendar.component(.hour, from: moonTimes.moonrise))
        let moonriseMinute = Double(calendar.component(.minute, from: moonTimes.moonrise))
        let moonsetHour = Double(calendar.component(.hour, from: moonTimes.moonset))
        let moonsetMinute = Double(calendar.component(.minute, from: moonTimes.moonset))
        
        let moonriseTotal = moonriseHour + moonriseMinute / 60.0
        let moonsetTotal = moonsetHour + moonsetMinute / 60.0
        
        // Calculate total duration (handling midnight crossing)
        let totalHours: Double
        if moonsetTotal < moonriseTotal {
            // Crosses midnight
            totalHours = (24.0 - moonriseTotal) + moonsetTotal
        } else {
            totalHours = moonsetTotal - moonriseTotal
        }
        
        // Midpoint from moonrise
        let midpointHours = totalHours / 2.0
        let peakHour = (moonriseTotal + midpointHours).truncatingRemainder(dividingBy: 24.0)
        
        return (peakHour / 24.0) * width
    }
    
    private func temperaturePoints() -> [CGPoint] {
        guard hourlyForecast.count >= 2 else { return [] }
        
        let minTemp: Double = 0
        let maxTemp: Double = 30
        let range = max(maxTemp - minTemp, 1.0)
        let topPadding: CGFloat = 2
        let bottomPadding: CGFloat = 28
        let sensitivity: CGFloat = 1.0
        let tempLineYOffset: CGFloat = -24
        let availableHeight = max(height - topPadding - bottomPadding, 1)
        
        var points: [CGPoint] = hourlyForecast.map { item in
            let x = hourPosition(item.time) * width
            let normalized = (item.temperature - minTemp) / range
            let centered = (CGFloat(normalized) - 0.5) * sensitivity + 0.5
            let clamped = min(max(centered, 0), 1)
            let y = topPadding + (1 - clamped) * availableHeight
            return CGPoint(x: x, y: y)
        }
        
        if let last = hourlyForecast.last {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: last.time)
            if let _ = calendar.date(byAdding: .day, value: 1, to: startOfDay) {
                let normalized = (last.temperature - minTemp) / range
                let centered = (CGFloat(normalized) - 0.5) * sensitivity + 0.5
                let clamped = min(max(centered, 0), 1)
                let y = topPadding + (1 - clamped) * availableHeight
                points.append(CGPoint(x: width, y: y))
            }
        }
        
        if let firstPoint = points.first {
            let offset = centerY - firstPoint.y + tempLineYOffset
            points = points.map { CGPoint(x: $0.x, y: $0.y + offset) }
        }
        
        return points
    }
    
    private func smoothedTemperaturePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        
        path.move(to: points[0])
        for index in 0..<(points.count - 1) {
            let p0 = index > 0 ? points[index - 1] : points[index]
            let p1 = points[index]
            let p2 = points[index + 1]
            let p3 = index + 2 < points.count ? points[index + 2] : p2
            
            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            
            path.addCurve(to: p2, control1: control1, control2: control2)
        }
        
        return path
    }
    
    var body: some View {
        ZStack {
            // Draw the sine wave (approximately 2.1 cycles per day for two high/low tides)
            Path { path in
                let startX: CGFloat = 0
                let endX = width
                let step: CGFloat = 2
                
                // Tides have approximately 2.1 cycles per day (lunar day is ~24h 50min)
                let cyclesPerDay = 2.1
                
                var firstPoint = true
                for x in stride(from: startX, to: endX, by: step) {
                    // Map x position to time (0-24 hours)
                    let timeRatio = Double(x / width)
                    // Multiply by cyclesPerDay to get approximately 2.1 cycles per 24 hours
                    let timeInRadians = timeRatio * 2 * Double.pi * cyclesPerDay
                    
                    // Calculate y position using sine wave with phase offset
                    let y = centerY + CGFloat(sin(timeInRadians + phaseOffset)) * amplitude
                    
                    if firstPoint {
                        path.move(to: CGPoint(x: x, y: y))
                        firstPoint = false
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.cyan, lineWidth: 3)
            
            // Draw center line (day line) - green between wake and sleep times, darker green during sleep
            ZStack {
                // Default line for the full width
                Path { path in
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: width, y: centerY))
                }
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                
                if sleepX > wakeX {
                    // Normal case: wake before sleep (7am to 11pm)
                    // Green segment during wake time (7am to 11pm)
                    Path { path in
                        path.move(to: CGPoint(x: wakeX, y: centerY))
                        path.addLine(to: CGPoint(x: sleepX, y: centerY))
                    }
                    .stroke(Color.green, lineWidth: 8)
                    
                    // Darker green segment during sleep time (11pm to 7am)
                    // From sleep to end of day
                    Path { path in
                        path.move(to: CGPoint(x: sleepX, y: centerY))
                        path.addLine(to: CGPoint(x: width, y: centerY))
                    }
                    .stroke(Color(red: 0.0, green: 0.5, blue: 0.0), lineWidth: 8)
                    
                    // From start of day to wake
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: centerY))
                        path.addLine(to: CGPoint(x: wakeX, y: centerY))
                    }
                    .stroke(Color(red: 0.0, green: 0.5, blue: 0.0), lineWidth: 8)
                } else {
                    // Sleep time is before wake time (crosses midnight)
                    // Darker green from sleep to wake (sleep time)
                    Path { path in
                        path.move(to: CGPoint(x: sleepX, y: centerY))
                        path.addLine(to: CGPoint(x: wakeX, y: centerY))
                    }
                    .stroke(Color(red: 0.0, green: 0.5, blue: 0.0), lineWidth: 8)
                    
                    // Green from wake to end of day (wake time)
                    Path { path in
                        path.move(to: CGPoint(x: wakeX, y: centerY))
                        path.addLine(to: CGPoint(x: width, y: centerY))
                    }
                    .stroke(Color.green, lineWidth: 8)
                    
                    // Green from start of day to sleep (wake time)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: centerY))
                        path.addLine(to: CGPoint(x: sleepX, y: centerY))
                    }
                    .stroke(Color.green, lineWidth: 8)
                }
            }
            
            let tempPoints = temperaturePoints()
            if tempPoints.count >= 2 {
                smoothedTemperaturePath(points: tempPoints)
                    .stroke(Color.orange.opacity(0.85), lineWidth: 3)
                    .shadow(color: Color.orange.opacity(0.25), radius: 4, x: 0, y: 2)
            }
            
            // Current time dot
            CurrentTimeDot(
                width: width,
                centerY: centerY,
                hourPosition: hourPosition
            )
            
            // Draw bolder tick marks at even hours (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22)
            Group {
                ForEach([0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22], id: \.self) { hour in
                    let tickX = (Double(hour) / 24.0) * width
                    Path { path in
                        path.move(to: CGPoint(x: tickX, y: centerY - 10))
                        path.addLine(to: CGPoint(x: tickX, y: centerY + 10))
                    }
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                }
            }
            
            // Draw sun path curve (sine wave arc) from sunrise to sunset
            if let sunTimes = sunTimes, let sunriseX = sunriseX, let sunsetX = sunsetX {
                Path { path in
                    let sunPathWidth = sunsetX - sunriseX
                    let peakY: CGFloat = 10
                    let amplitude = centerY - peakY
                    
                    // Draw the positive half of a sine wave from sunrise to sunset
                    let startX = sunriseX
                    let endX = sunsetX
                    let step: CGFloat = 2
                    
                    var firstPoint = true
                    for x in stride(from: startX, through: endX, by: step) {
                        // Map x position from sunrise to sunset to sine wave parameter (0 to π)
                        let xRatio = (x - sunriseX) / sunPathWidth
                        let sineParameter = xRatio * Double.pi
                        
                        // Calculate y position using sine wave (positive half: 0 to π)
                        // sin(0) = 0, sin(π/2) = 1, sin(π) = 0
                        let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                        
                        if firstPoint {
                            path.move(to: CGPoint(x: x, y: y))
                            firstPoint = false
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.yellow.opacity(0.8), lineWidth: 5)
            }
            
            // Draw moon path curve as two separate chords (PM and AM)
            // Peak is at the midpoint between moonrise and moonset
            if let moonTimes = moonTimes, let moonriseX = moonriseX, let moonsetX = moonsetX, let peakX = moonPeakX {
                let peakY: CGFloat = 10
                let amplitude = centerY - peakY
                let step: CGFloat = 2
                let midnightX = width
                
                // Check if moonset is before moonrise (crosses midnight)
                let crossesMidnight = moonsetX < moonriseX
                
                if crossesMidnight {
                    // Determine if peak is in AM (0 to moonsetX) or PM (moonriseX to width)
                    let peakIsInAM = peakX < moonsetX
                    
                    if peakIsInAM {
                        // Peak is in AM: PM chord rises only, AM chord rises and falls
                        
                        // Calculate what value the PM chord should reach at midnight
                        let totalHours = (24.0 - (moonriseX / width * 24.0)) + (moonsetX / width * 24.0)
                        let hoursToMidnight = 24.0 - (moonriseX / width * 24.0)
                        let midnightRatio = hoursToMidnight / totalHours
                        // At midnight, we're at this ratio of the full sine wave (0 to π)
                        let midnightSineValue = midnightRatio * Double.pi
                        
                        // PM chord: From moonrise to midnight (rising only, 0 to midnightSineValue)
                        Path { path in
                            let pmWidth = midnightX - moonriseX
                            var firstPoint = true
                            
                            for x in stride(from: moonriseX, through: midnightX, by: step) {
                                let xRatio = (x - moonriseX) / pmWidth
                                // Map to sine wave from 0 to midnightSineValue (rising only)
                                let sineParameter = xRatio * midnightSineValue
                                let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.9), lineWidth: 3)
                        
                        // AM chord: From midnight to moonset (starts at midnightY, full sine wave)
                        // Calculate the sine value range for AM chord
                        // AM chord should go from midnightSineValue to π
                        let amSineStart = midnightSineValue
                        let amSineEnd = Double.pi
                        let amSineRange = amSineEnd - amSineStart
                        
                        Path { path in
                            let amWidth = moonsetX
                            var firstPoint = true
                            
                            for x in stride(from: 0, through: moonsetX, by: step) {
                                let xRatio = x / amWidth
                                // Map to sine wave from midnightSineValue to π (continuing from PM chord)
                                let sineParameter = amSineStart + (xRatio * amSineRange)
                                let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.9), lineWidth: 3)
                    } else {
                        // Peak is in PM: PM chord rises and falls, AM chord falls only
                        
                        // Calculate what value the PM chord reaches at midnight
                        let totalHours = (24.0 - (moonriseX / width * 24.0)) + (moonsetX / width * 24.0)
                        let hoursToMidnight = 24.0 - (moonriseX / width * 24.0)
                        let midnightRatio = hoursToMidnight / totalHours
                        // At midnight, we're at this ratio of the full sine wave (0 to π)
                        let midnightSineValue = midnightRatio * Double.pi
                        
                        // PM chord: From moonrise to midnight (full sine wave, 0 to π)
                        Path { path in
                            let pmWidth = midnightX - moonriseX
                            var firstPoint = true
                            
                            for x in stride(from: moonriseX, through: midnightX, by: step) {
                                let xRatio = (x - moonriseX) / pmWidth
                                // Map to sine wave from 0 to π (rising to peak, then falling)
                                let sineParameter = xRatio * Double.pi
                                let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.9), lineWidth: 3)
                        
                        // AM chord: From midnight to moonset (starts at midnightY, falling only)
                        // Calculate the sine value range for AM chord
                        // AM chord should go from midnightSineValue to π
                        let amSineStart = midnightSineValue
                        let amSineEnd = Double.pi
                        let amSineRange = amSineEnd - amSineStart
                        
                        Path { path in
                            let amWidth = moonsetX
                            var firstPoint = true
                            
                            for x in stride(from: 0, through: moonsetX, by: step) {
                                let xRatio = x / amWidth
                                // Map to sine wave from midnightSineValue to π (continuing from PM chord, falling)
                                let sineParameter = amSineStart + (xRatio * amSineRange)
                                let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.9), lineWidth: 3)
                    }
                } else {
                    // Normal case: moonrise to moonset in same day
                    let moonPathWidth = moonsetX - moonriseX
                    if moonPathWidth > 0 {
                        Path { path in
                            var firstPoint = true
                            for x in stride(from: moonriseX, through: moonsetX, by: step) {
                                let xRatio = (x - moonriseX) / moonPathWidth
                                let sineParameter = xRatio * Double.pi
                                let y = centerY - CGFloat(sin(sineParameter)) * amplitude
                                
                                if firstPoint {
                                    path.move(to: CGPoint(x: x, y: y))
                                    firstPoint = false
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color(red: 0.8, green: 0.8, blue: 0.9), lineWidth: 3)
                    }
                }
            }
            
            
            // Today's events on the timeline
            ForEach(todayEvents) { event in
                let x = hourPosition(event.startDate) * width
                let eventY = centerY
                let eventColor = color(for: event.calendarId)
                
                VStack(spacing: 6) {
                    Image(systemName: "calendar.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(eventColor)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(1.0))
                                .frame(width: 56, height: 56)
                        )
                    
                    Text(event.startDate, style: .time)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .position(x: x, y: eventY)
            }
        }
    }
}
