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
    @StateObject private var calendarService = CalendarService()
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                
                Text(locationService.locationName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)

                // Day graph section
            if !tideService.tides.isEmpty || tideService.isLoading {
                DayGraphView(tides: tideService.tides, isLoading: tideService.isLoading, sunTimes: sunService.sunTimes, moonTimes: moonService.moonTimes, hourlyForecast: weatherService.hourlyForecast, todayEvents: todayEvents)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
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
            CalendarLineView(
                dailyForecastIcons: weatherService.dailyForecastIcons,
                cachedDailyIcons: weatherService.dailyIconCache,
                dailyForecastTemps: weatherService.dailyForecastTemps
            )
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await loadData()
        }
    }
    
    private var todayEvents: [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        return calendarService.events.filter { event in
            event.startDate >= today && event.startDate < tomorrow
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
        
        // Load weather, tides, and calendars concurrently
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
            
            group.addTask {
                await calendarService.fetchCalendars()
            }
        }
    }
}

// struct WeatherCard: View {
//     let weather: WeatherData?
//     let isLoading: Bool
    
//     var body: some View {
//         VStack(alignment: .leading, spacing: 12) {
//             HStack {
//                 Image(systemName: "cloud.sun.fill")
//                     .font(.system(size: 36))
//                     .foregroundColor(.blue)
                
//                 Text("Weather")
//                     .font(.title2)
//                     .fontWeight(.semibold)
//             }
            
//             if isLoading {
//                 ProgressView()
//                     .frame(maxWidth: .infinity, alignment: .center)
//                     .padding(.vertical, 20)
//             } else if let weather = weather {
//                 VStack(alignment: .leading, spacing: 10) {
//                     HStack(alignment: .firstTextBaseline, spacing: 6) {
//                         Text("\(Int(weather.temperature))°")
//                             .font(.system(size: 48, weight: .bold))
                        
//                         Text("F")
//                             .font(.title3)
//                             .foregroundColor(.secondary)
//                     }
                    
//                     Text(weather.condition)
//                         .font(.title3)
//                         .foregroundColor(.secondary)
                    
//                     Text(weather.description.capitalized)
//                         .font(.body)
//                         .foregroundColor(.secondary)
                    
//                     Divider()
//                         .padding(.vertical, 4)
                    
//                     HStack(spacing: 30) {
//                         VStack(alignment: .leading, spacing: 2) {
//                             Text("Humidity")
//                                 .font(.caption)
//                                 .foregroundColor(.secondary)
//                             Text("\(weather.humidity)%")
//                                 .font(.body)
//                         }
                        
//                         VStack(alignment: .leading, spacing: 2) {
//                             Text("Wind")
//                                 .font(.caption)
//                                 .foregroundColor(.secondary)
//                             Text("\(Int(weather.windSpeed)) mph")
//                                 .font(.body)
//                         }
//                     }
//                 }
//             } else {
//                 Text("Unable to load weather")
//                     .foregroundColor(.secondary)
//             }
//         }
//         .padding(24)
//         .background(Color(white: 0.1))
//         .cornerRadius(16)
//     }
// }

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
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 40, height: 40)
                        
                        // Temperature
                        Text("\(Int(item.temperature))°")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .position(x: x, y: weatherY)
                }
                
                // Midnight at the end of the day (24:00)
                if let midnightData = weatherService.hourlyForecast.first {
                    let midnightX = width // Position at the end (24:00)
                    let weatherY = height - 40
                    
                    VStack(spacing: 6) {
                        // Time label - show as "12AM" for midnight at end
                        Text("12AM")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Weather icon
                        Image(systemName: weatherIconName(for: midnightData.icon))
                            .font(.system(size: 32))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 40, height: 40)
                        
                        // Temperature
                        Text("\(Int(midnightData.temperature))°")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .position(x: midnightX, y: weatherY)
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
    

struct WeatherBackgroundView: View {
    let weather: WeatherData?
    let sunTimes: SunTimes?
    
    private var isNight: Bool {
        guard let sunTimes = sunTimes else { return false }
        let now = Date()
        return now < sunTimes.sunrise || now > sunTimes.sunset
    }
    
    private var weatherCondition: String {
        weather?.condition.lowercased() ?? "clear"
    }
    
    private var weatherIcon: String {
        weather?.icon ?? "01d"
    }
    
    var body: some View {
        ZStack {
            // Base gradient based on day/night
            if isNight {
                // Night gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.1, blue: 0.2),
                        Color(red: 0.05, green: 0.05, blue: 0.15)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                // Day gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.4, green: 0.6, blue: 0.9),
                        Color(red: 0.5, green: 0.7, blue: 0.95),
                        Color(red: 0.6, green: 0.8, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            
            // Weather-specific overlays
            if isNight {
                // Night weather effects
                if weatherIcon.contains("09") || weatherIcon.contains("10") || weatherCondition.contains("rain") {
                    // Rain at night
                    NightRainView()
                } else if weatherIcon.contains("11") || weatherCondition.contains("thunder") {
                    // Thunderstorm at night
                    NightThunderView()
                } else if weatherIcon.contains("13") || weatherCondition.contains("snow") {
                    // Snow at night
                    NightSnowView()
                } else {
                    // Clear/starry night
                    StarryNightView()
                }
            } else {
                // Day weather effects
                if weatherIcon.contains("09") || weatherIcon.contains("10") || weatherCondition.contains("rain") {
                    // Rain during day
                    DayRainView()
                } else if weatherIcon.contains("11") || weatherCondition.contains("thunder") {
                    // Thunderstorm during day
                    DayThunderView()
                } else if weatherIcon.contains("13") || weatherCondition.contains("snow") {
                    // Snow during day
                    DaySnowView()
                } else if weatherIcon.contains("02") || weatherIcon.contains("03") || weatherIcon.contains("04") || weatherCondition.contains("cloud") {
                    // Clouds during day
                    DayCloudsView()
                }
                // Clear day - just the gradient
            }
        }
    }
}

struct StarryNightView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50, id: \.self) { _ in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
            }
        }
    }
}

struct NightRainView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<100, id: \.self) { _ in
                Path { path in
                    let x = CGFloat.random(in: 0...geometry.size.width)
                    let y = CGFloat.random(in: 0...geometry.size.height)
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + 20))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

struct NightThunderView: View {
    var body: some View {
        ZStack {
            StarryNightView()
            NightRainView()
            
            // Lightning flashes
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .ignoresSafeArea()
        }
    }
}

struct NightSnowView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<80, id: \.self) { _ in
                Text("❄")
                    .font(.system(size: CGFloat.random(in: 10...20)))
                    .foregroundColor(.white.opacity(0.7))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
            }
        }
    }
}

struct DayRainView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<150, id: \.self) { _ in
                Path { path in
                    let x = CGFloat.random(in: 0...geometry.size.width)
                    let y = CGFloat.random(in: 0...geometry.size.height)
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x, y: y + 25))
                }
                .stroke(Color.blue.opacity(0.4), lineWidth: 1.5)
            }
        }
    }
}

struct DayThunderView: View {
    var body: some View {
        ZStack {
            DayCloudsView()
            DayRainView()
            
            // Lightning
            Rectangle()
                .fill(Color.yellow.opacity(0.15))
                .ignoresSafeArea()
        }
    }
}

struct DaySnowView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<100, id: \.self) { _ in
                Text("❄")
                    .font(.system(size: CGFloat.random(in: 12...24)))
                    .foregroundColor(.white.opacity(0.8))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height)
                    )
            }
        }
    }
}

struct DayCloudsView: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<15, id: \.self) { _ in
                Image(systemName: "cloud.fill")
                    .font(.system(size: CGFloat.random(in: 80...150)))
                    .foregroundColor(.white.opacity(0.3))
                    .position(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: CGFloat.random(in: 0...geometry.size.height * 0.6)
                    )
            }
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

#Preview {
    TodayView()
}
