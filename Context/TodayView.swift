//
//  TodayView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI
import CoreLocation

struct TodayView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var weatherService = WeatherService()
    @StateObject private var sunService = SunService()
    @StateObject private var moonService = MoonService()
    @StateObject private var tideService = TideService()
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Tides Section
            if !tideService.tides.isEmpty || tideService.isLoading {
                TidesCard(tides: tideService.tides, isLoading: tideService.isLoading, sunTimes: sunService.sunTimes, moonTimes: moonService.moonTimes, hourlyForecast: weatherService.hourlyForecast)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
            }
            WeatherTimelineView()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 40)   

//            // Main content in a grid
//            HStack(spacing: 40) {
//                // Weather Section
//                WeatherCard(weather: weatherService.weather, isLoading: weatherService.isLoading)
//                    .frame(maxWidth: .infinity)
//                
//                // Sun Times Section
//                SunCard(sunTimes: sunService.sunTimes)
//                    .frame(maxWidth: .infinity)
//                
//                // Moon Times Section
//                MoonCard(moonTimes: moonService.moonTimes)
//                    .frame(maxWidth: .infinity)
//            }
//            .padding(.horizontal, 40)
            
            Spacer()
            
            // Calendar line
            CalendarLineView()
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        let coordinate = locationService.coordinate
        
        // Calculate sun and moon times synchronously (they're not async)
        sunService.calculateSunTimes(
            for: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        moonService.calculateMoonTimes(
            for: Date(),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        // Load weather and tides concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await weatherService.fetchWeather(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
            
            group.addTask {
                await weatherService.fetchHourlyForecast(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
            
            group.addTask {
                await tideService.fetchTides(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        }
    }
}

struct WeatherCard: View {
    let weather: WeatherData?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
                
                Text("Weather")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if let weather = weather {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(weather.temperature))°")
                            .font(.system(size: 48, weight: .bold))
                        
                        Text("F")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(weather.condition)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    Text(weather.description.capitalized)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 30) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Humidity")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(weather.humidity)%")
                                .font(.body)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Wind")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(weather.windSpeed)) mph")
                                .font(.body)
                        }
                    }
                }
            } else {
                Text("Unable to load weather")
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }
}

struct SunCard: View {
    let sunTimes: SunTimes?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)
                
                Text("Sun")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let sunTimes = sunTimes {
                VStack(alignment: .leading, spacing: 16) {
                    SunTimeRow(
                        icon: "sunrise.fill",
                        label: "Sunrise",
                        time: sunTimes.sunrise,
                        color: .orange
                    )
                    
                    SunTimeRow(
                        icon: "sunset.fill",
                        label: "Sunset",
                        time: sunTimes.sunset,
                        color: .red
                    )
                }
            } else {
                Text("Calculating...")
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }
}

struct SunTimeRow: View {
    let icon: String
    let label: String
    let time: Date
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(time, style: .time)
                    .font(.title3)
            }
        }
    }
}

struct MoonCard: View {
    let moonTimes: MoonTimes?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(white: 0.7))
                
                Text("Moon")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let moonTimes = moonTimes {
                VStack(alignment: .leading, spacing: 16) {
                    SunTimeRow(
                        icon: "moon.stars.fill",
                        label: "Moonrise",
                        time: moonTimes.moonrise,
                        color: Color(white: 0.7)
                    )
                    
                    SunTimeRow(
                        icon: "moon.fill",
                        label: "Moonset",
                        time: moonTimes.moonset,
                        color: Color(white: 0.6)
                    )
                }
            } else {
                Text("Calculating...")
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }
}

struct TidesCard: View {
    let tides: [TideEvent]
    let isLoading: Bool
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let hourlyForecast: [HourlyWeatherData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "water.waves")
                    .font(.system(size: 36))
                    .foregroundColor(.cyan)
                Image(systemName: "moon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(white: 0.7))
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.yellow)
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
                TideWaveView(tides: tides, sunTimes: sunTimes, moonTimes: moonTimes, hourlyForecast: hourlyForecast)
                    .frame(height: 360)
            }
        }
        .padding(24)
        .background(Color(white: 0.1))
        .cornerRadius(16)
    }
}

struct TideWaveView: View {
    let tides: [TideEvent]
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let hourlyForecast: [HourlyWeatherData]
    
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
                TideWaveContent(
                    width: geometry.size.width,
                    height: geometry.size.height,
                    tides: tides,
                    sunTimes: sunTimes,
                    moonTimes: moonTimes,
                    phaseOffset: phaseOffset,
                    hourPosition: hourPosition,
                    hourlyForecast: hourlyForecast
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

struct TideWaveContent: View {
    let width: CGFloat
    let height: CGFloat
    let tides: [TideEvent]
    let sunTimes: SunTimes?
    let moonTimes: MoonTimes?
    let phaseOffset: Double
    let hourPosition: (Date) -> CGFloat
    let hourlyForecast: [HourlyWeatherData]
    
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
            
            // Draw center line (day line)
            Path { path in
                path.move(to: CGPoint(x: 0, y: centerY))
                path.addLine(to: CGPoint(x: width, y: centerY))
            }
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            
            // Current time dot
            CurrentTimeDot(
                width: width,
                centerY: centerY,
                hourPosition: hourPosition
            )
            
            // Draw tick marks at 6am, 12pm, 6pm
            Group {
                // 6am tick
                let sixAMX = (6.0 / 24.0) * width
                Path { path in
                    path.move(to: CGPoint(x: sixAMX, y: centerY - 8))
                    path.addLine(to: CGPoint(x: sixAMX, y: centerY + 8))
                }
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                
                // 12pm tick
                let noonTickX = (12.0 / 24.0) * width
                Path { path in
                    path.move(to: CGPoint(x: noonTickX, y: centerY - 8))
                    path.addLine(to: CGPoint(x: noonTickX, y: centerY + 8))
                }
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                
                // 6pm tick
                let sixPMX = (18.0 / 24.0) * width
                Path { path in
                    path.move(to: CGPoint(x: sixPMX, y: centerY - 8))
                    path.addLine(to: CGPoint(x: sixPMX, y: centerY + 8))
                }
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
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
            
            // Draw drop lines at sunrise, midday, and sunset
            if let sunTimes = sunTimes {
                // Sunrise drop line
                if let sunriseX = sunriseX {
                    Path { path in
                        path.move(to: CGPoint(x: sunriseX, y: 0))
                        path.addLine(to: CGPoint(x: sunriseX, y: height))
                    }
                    .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    
                    // Sunrise icon (sun up)
                    Image(systemName: "sunrise.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .position(x: sunriseX, y: 8)
                    
                    // Sunrise time label
                    Text(sunTimes.sunrise, style: .time)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .position(x: sunriseX, y: height - 15)
                }
                
                // Midday drop line
                if let noonX = noonX {
                    Path { path in
                        path.move(to: CGPoint(x: noonX, y: 0))
                        path.addLine(to: CGPoint(x: noonX, y: height))
                    }
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                }
                
                // Sunset drop line
                if let sunsetX = sunsetX {
                    Path { path in
                        path.move(to: CGPoint(x: sunsetX, y: 0))
                        path.addLine(to: CGPoint(x: sunsetX, y: height))
                    }
                    .stroke(Color.red.opacity(0.6), lineWidth: 1)
                    
                    // Sunset icon (sun down)
                    Image(systemName: "sunset.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .position(x: sunsetX, y: 8)
                    
                    // Sunset time label
                    Text(sunTimes.sunset, style: .time)
                        .font(.caption)
                        .foregroundColor(.red)
                        .position(x: sunsetX, y: height - 15)
                }
            }
            
        }
    }
}


struct WeatherTimelineView: View {
    @StateObject private var weatherService = WeatherService()
    @StateObject private var locationService = LocationService()
    
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
            let width = geometry.size.width
            let height: CGFloat = 100
            
            ZStack {
                // Hourly weather items positioned below timeline
                ForEach(Array(weatherService.hourlyForecast.enumerated()), id: \.offset) { index, item in
                    let x = hourPosition(item.time) * width
                    let weatherY = height - 40
                    
                    VStack(spacing: 6) {
                        // Time label
                        Text(formatWeatherTime(item.time))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Weather icon
                        Image(systemName: weatherIconName(for: item.icon))
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                        
                        // Temperature
                        Text("\(Int(item.temperature))°")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .position(x: x, y: weatherY)
                }
            }
        }
        .frame(height: 100)
        .task {
            let coordinate = locationService.coordinate
            await weatherService.fetchHourlyForecast(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }
    
    private func formatWeatherTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        // If it's within the current hour, show "Now"
        if calendar.isDate(date, equalTo: now, toGranularity: .hour) {
            return "Now"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date)
    }
    
    private func weatherIconName(for iconCode: String) -> String {
        // Map OpenWeatherMap icon codes to SF Symbols
        switch iconCode {
        case "01d", "01n": return "sun.max.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "cloud.fill"
        case "09d", "09n": return "cloud.rain.fill"
        case "10d", "10n": return "cloud.sun.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}
    

struct ClockView: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(currentTime, style: .time)
                .font(.system(size: 48, weight: .medium, design: .rounded))
                .monospacedDigit()
            
            Text(currentTime, style: .date)
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .onAppear {
            // Update immediately
            currentTime = Date()
            
            // Set up timer to update every second
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
}

struct CalendarLineView: View {
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
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let dayWidth = totalWidth / CGFloat(daysInMonth)
            
            HStack(spacing: 0) {
                ForEach(1...daysInMonth, id: \.self) { day in
                    VStack(spacing: 6) {
                        // Day of week letter
                        Text(dayOfWeekLetter(for: day))
                            .font(.system(size: day == today ? 20 : 16, weight: day == today ? .bold : .regular))
                            .foregroundColor(day == today ? .primary : .secondary)
                        
                        // Date number
                        Text("\(day)")
                            .font(.system(size: day == today ? 32 : 24, weight: day == today ? .bold : .regular))
                            .foregroundColor(day == today ? .primary : .secondary)
                        
                        if day == today {
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(width: dayWidth)
                }
            }
        }
        .frame(height: 80)
    }
}

#Preview {
    TodayView()
}
