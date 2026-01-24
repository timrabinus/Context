//
//  WeatherService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import Combine

struct WeatherData: Codable {
    let temperature: Double
    let condition: String
    let description: String
    let humidity: Int
    let windSpeed: Double
    let icon: String
}

struct HourlyWeatherData: Codable {
    let time: Date
    let temperature: Double
    let icon: String
    let condition: String
}

struct WeatherResponse: Codable {
    let main: MainWeather
    let weather: [WeatherInfo]
    let wind: Wind
    let name: String
    
    struct MainWeather: Codable {
        let temp: Double
        let humidity: Int
    }
    
    struct WeatherInfo: Codable {
        let main: String
        let description: String
        let icon: String
    }
    
    struct Wind: Codable {
        let speed: Double
    }
}

struct HourlyForecastResponse: Codable {
    let list: [ForecastItem]
    
    struct ForecastItem: Codable {
        let dt: TimeInterval
        let main: MainWeather
        let weather: [WeatherInfo]
    }
    
    struct MainWeather: Codable {
        let temp: Double
    }
    
    struct WeatherInfo: Codable {
        let main: String
        let icon: String
    }
}

@MainActor
class WeatherService: ObservableObject {
    @Published var weather: WeatherData?
    @Published var hourlyForecast: [HourlyWeatherData] = []
    @Published var dailyForecastIcons: [String: String] = [:]
    @Published var dailyForecastTemps: [String: Double] = [:]
    @Published private(set) var dailyIconCache: [String: String] = [:]
    @Published var isLoading = false
    @Published var error: String?
    
    private struct WeatherCache: Codable {
        let timestamp: Date
        let data: WeatherData
    }
    
    private struct HourlyForecastCache: Codable {
        let timestamp: Date
        let data: [HourlyWeatherData]
        let dailyIcons: [String: String]
        let dailyTemps: [String: Double]
    }
    
    private let apiKey = WeatherService.deobfuscatedApiKey()
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private let forecastURL = "https://api.openweathermap.org/data/2.5/forecast"
    private let dailyIconCacheKey = "dailyForecastIconCache"
    private let weatherCacheKey = "weatherCache"
    private let hourlyForecastCacheKey = "hourlyForecastCache"
    private let dailyCallCountKey = "openWeatherCallCount"
    private let dailyCallDateKey = "openWeatherCallDate"
    private let refreshInterval: TimeInterval = 15 * 60
    private let dailyCallLimit = 1000
    private let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        loadDailyIconCache()
        loadWeatherCache()
        loadHourlyForecastCache()
    }
    
    func fetchWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        error = nil
        
        if let cached = readWeatherCache(), !isRefreshNeeded(since: cached.timestamp) {
            self.weather = cached.data
            self.isLoading = false
            return
        }
        
        // If no API key is set, use mock data for development
        guard apiKey != "YOUR_API_KEY_HERE" else {
            // Mock weather data for development
            try? await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
            self.weather = WeatherData(
                temperature: 72.0,
                condition: "Clear",
                description: "clear sky",
                humidity: 65,
                windSpeed: 8.5,
                icon: "01d"
            )
            self.isLoading = false
            return
        }
        
        guard canMakeNetworkCall() else {
            error = "Daily weather request limit reached"
            logError(error ?? "Daily weather request limit reached")
            if let cached = readWeatherCache() {
                self.weather = cached.data
            }
            isLoading = false
            return
        }
        
        let urlString = "\(baseURL)?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            logError(error ?? "Invalid URL")
            isLoading = false
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                error = "OpenWeather current weather error: HTTP \(httpResponse.statusCode)"
                logError("\(error ?? "OpenWeather current weather error") | \(body)")
                if let cached = readWeatherCache() {
                    self.weather = cached.data
                }
                isLoading = false
                return
            }
            let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            if let weatherInfo = weatherResponse.weather.first {
                let weather = WeatherData(
                    temperature: weatherResponse.main.temp,
                    condition: weatherInfo.main,
                    description: weatherInfo.description,
                    humidity: weatherResponse.main.humidity,
                    windSpeed: weatherResponse.wind.speed,
                    icon: weatherInfo.icon
                )
                self.weather = weather
                writeWeatherCache(weather)
            }
        } catch {
            self.error = "Failed to fetch weather: \(error.localizedDescription)"
            logError(self.error ?? "Failed to fetch weather")
            if let cached = readWeatherCache() {
                self.weather = cached.data
            }
        }
        
        isLoading = false
    }
    
    func fetchHourlyForecast(latitude: Double, longitude: Double) async {
        if let cached = readHourlyForecastCache(), !isRefreshNeeded(since: cached.timestamp) {
            self.hourlyForecast = cached.data
            self.dailyForecastIcons = cached.dailyIcons
            self.dailyForecastTemps = cached.dailyTemps
            return
        }
        
        // If no API key is set, use mock data for development
        guard apiKey != "YOUR_API_KEY_HERE" else {
            // Mock hourly forecast data for 24 hours
            try? await Task.sleep(nanoseconds: 500_000_000)
            let now = Date()
            let calendar = Calendar.current
            // Round current time to the hour for "Now"
            let currentHour = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            let roundedNow = calendar.date(from: currentHour) ?? now
            
            // Generate forecast data for even hours including midnight (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22)
            var forecast: [HourlyWeatherData] = []
            let baseTemp = 24.0
            let icons = ["02d", "02d", "01d", "01d", "01d", "02d", "02d", "02d", "02d", "02d", "02d", "02d"]
            let conditions = ["Cloudy", "Cloudy", "Clear", "Clear", "Clear", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy"]
            
            // Start from midnight (hour 0) of the current day
            let startOfDay = calendar.startOfDay(for: now)
            
            for hour in [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22] {
                guard let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
                // Vary temperature slightly throughout the day (cooler at night, warmer during day)
                let hourOfDay = calendar.component(.hour, from: hourDate)
                let tempVariation: Double
                if hourOfDay >= 6 && hourOfDay <= 18 {
                    // Daytime: warmer
                    tempVariation = Double(hourOfDay - 12) * 0.5
                } else {
                    // Nighttime: cooler
                    tempVariation = -2.0
                }
                let temperature = baseTemp + tempVariation
                
                let iconIndex = hour / 2
                forecast.append(HourlyWeatherData(
                    time: hourDate,
                    temperature: temperature,
                    icon: icons[iconIndex],
                    condition: conditions[iconIndex]
                ))
            }
            
            self.hourlyForecast = forecast
            updateMockDailyForecastIcons(now: now)
            return
        }
        
        guard canMakeNetworkCall() else {
            error = "Daily forecast request limit reached"
            logError(error ?? "Daily forecast request limit reached")
            if let cached = readHourlyForecastCache() {
                self.hourlyForecast = cached.data
                self.dailyForecastIcons = cached.dailyIcons
                self.dailyForecastTemps = cached.dailyTemps
            }
            return
        }
        
        let urlString = "\(forecastURL)?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            logError(error ?? "Invalid URL")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                error = "OpenWeather forecast error: HTTP \(httpResponse.statusCode)"
                logError("\(error ?? "OpenWeather forecast error") | \(body)")
                if let cached = readHourlyForecastCache() {
                    self.hourlyForecast = cached.data
                    self.dailyForecastIcons = cached.dailyIcons
                    self.dailyForecastTemps = cached.dailyTemps
                }
                return
            }
            let forecastResponse = try JSONDecoder().decode(HourlyForecastResponse.self, from: data)
            
            // Get 24 hours of forecast data for timeline
            let now = Date()
            let calendar = Calendar.current
            let currentHour = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            guard let roundedNow = calendar.date(from: currentHour) else { return }
            
            // OpenWeatherMap forecast API returns 3-hour intervals
            // Filter to get next 24 hours for the hourly timeline
            let next24Hours = calendar.date(byAdding: .hour, value: 24, to: roundedNow) ?? now
            
            let forecastItems = forecastResponse.list.filter { item in
                let itemDate = Date(timeIntervalSince1970: item.dt)
                return itemDate >= roundedNow && itemDate <= next24Hours
            }
            
            // Generate forecast data for even hours including midnight (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22)
            var hourlyForecast: [HourlyWeatherData] = []
            let startOfDay = calendar.startOfDay(for: now)
            
            for hour in [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22] {
                guard let hourDate = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
                
                // Find the closest forecast item
                let closestItem = forecastItems.min { item1, item2 in
                    let date1 = Date(timeIntervalSince1970: item1.dt)
                    let date2 = Date(timeIntervalSince1970: item2.dt)
                    return abs(date1.timeIntervalSince(hourDate)) < abs(date2.timeIntervalSince(hourDate))
                }
                
                if let item = closestItem {
                    let weatherInfo = item.weather.first ?? HourlyForecastResponse.WeatherInfo(main: "Clear", icon: "01d")
                    hourlyForecast.append(HourlyWeatherData(
                        time: hourDate,
                        temperature: item.main.temp,
                        icon: weatherInfo.icon,
                        condition: weatherInfo.main
                    ))
                }
            }
            self.hourlyForecast = hourlyForecast
            updateDailyForecastIcons(from: forecastResponse.list, now: now)
            writeHourlyForecastCache(
                hourlyForecast,
                dailyIcons: dailyForecastIcons,
                dailyTemps: dailyForecastTemps
            )
        } catch {
            self.error = "Failed to fetch hourly forecast: \(error.localizedDescription)"
            logError(self.error ?? "Failed to fetch hourly forecast")
            if let cached = readHourlyForecastCache() {
                self.hourlyForecast = cached.data
                self.dailyForecastIcons = cached.dailyIcons
                self.dailyForecastTemps = cached.dailyTemps
            }
        }
    }

    private func updateDailyForecastIcons(from items: [HourlyForecastResponse.ForecastItem], now: Date) {
        let calendar = Calendar.current
        var bestByDay: [String: (icon: String, temp: Double, delta: TimeInterval, date: Date)] = [:]

        for item in items {
            let itemDate = Date(timeIntervalSince1970: item.dt)
            let dayStart = calendar.startOfDay(for: itemDate)
            let dayKey = dayKeyFormatter.string(from: dayStart)
            let midday = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? itemDate
            let delta = abs(itemDate.timeIntervalSince(midday))

            if let existing = bestByDay[dayKey], existing.delta <= delta {
                continue
            }

            let icon = item.weather.first?.icon ?? "01d"
            bestByDay[dayKey] = (icon: icon, temp: item.main.temp, delta: delta, date: dayStart)
        }

        var icons: [String: String] = [:]
        var temps: [String: Double] = [:]
        for (dayKey, entry) in bestByDay {
            let dayDate = entry.date
            if dayDate >= calendar.startOfDay(for: now) {
                icons[dayKey] = entry.icon
                temps[dayKey] = entry.temp
            }
        }

        dailyForecastIcons = icons
        dailyForecastTemps = temps
        mergeDailyIconCache(with: icons)
    }

    private func updateMockDailyForecastIcons(now: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let icons = ["02d", "01d", "03d", "04d", "10d"]
        let temps = [24.0, 26.0, 25.0, 23.0, 22.0]
        var dailyIcons: [String: String] = [:]
        var dailyTemps: [String: Double] = [:]

        for offset in 0..<icons.count {
            guard let dayDate = calendar.date(byAdding: .day, value: offset, to: startOfDay) else { continue }
            let dayKey = dayKeyFormatter.string(from: dayDate)
            dailyIcons[dayKey] = icons[offset]
            dailyTemps[dayKey] = temps[offset]
        }

        dailyForecastIcons = dailyIcons
        dailyForecastTemps = dailyTemps
        mergeDailyIconCache(with: dailyIcons)
    }

    private func mergeDailyIconCache(with newIcons: [String: String]) {
        guard !newIcons.isEmpty else { return }
        var updated = dailyIconCache
        for (key, icon) in newIcons {
            updated[key] = icon
        }
        dailyIconCache = updated
        saveDailyIconCache()
    }

    private func loadDailyIconCache() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: dailyIconCacheKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        dailyIconCache = decoded
    }

    private func saveDailyIconCache() {
        guard let data = try? JSONEncoder().encode(dailyIconCache) else { return }
        UserDefaults.standard.set(data, forKey: dailyIconCacheKey)
    }
    
    private func loadWeatherCache() {
        guard let cached = readWeatherCache() else { return }
        weather = cached.data
    }
    
    private func loadHourlyForecastCache() {
        guard let cached = readHourlyForecastCache() else { return }
        hourlyForecast = cached.data
        dailyForecastIcons = cached.dailyIcons
        dailyForecastTemps = cached.dailyTemps
    }
    
    private func readWeatherCache() -> WeatherCache? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: weatherCacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WeatherCache.self, from: data)
    }
    
    private func writeWeatherCache(_ weather: WeatherData) {
        let cache = WeatherCache(timestamp: Date(), data: weather)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: weatherCacheKey)
    }
    
    private func readHourlyForecastCache() -> HourlyForecastCache? {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: hourlyForecastCacheKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HourlyForecastCache.self, from: data)
    }
    
    private func writeHourlyForecastCache(
        _ forecast: [HourlyWeatherData],
        dailyIcons: [String: String],
        dailyTemps: [String: Double]
    ) {
        let cache = HourlyForecastCache(
            timestamp: Date(),
            data: forecast,
            dailyIcons: dailyIcons,
            dailyTemps: dailyTemps
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: hourlyForecastCacheKey)
    }
    
    private func isRefreshNeeded(since timestamp: Date) -> Bool {
        Date().timeIntervalSince(timestamp) >= refreshInterval
    }
    
    private func canMakeNetworkCall() -> Bool {
        let defaults = UserDefaults.standard
        let today = Calendar.current.startOfDay(for: Date())
        
        let storedDate = defaults.object(forKey: dailyCallDateKey) as? Date
        if storedDate == nil || storedDate != today {
            defaults.set(today, forKey: dailyCallDateKey)
            defaults.set(0, forKey: dailyCallCountKey)
        }
        
        let count = defaults.integer(forKey: dailyCallCountKey)
        guard count < dailyCallLimit else {
            return false
        }
        
        defaults.set(count + 1, forKey: dailyCallCountKey)
        return true
    }
    
    private func logError(_ message: String) {
        print("WeatherService: \(message)")
    }
    
    private static func deobfuscatedApiKey() -> String {
        let mask: UInt8 = 0x5A
        let encoded: [UInt8] = [
            110, 110, 111, 108, 99, 108, 63, 63, 111, 110, 109, 62, 63, 59, 57, 56,
            104, 104, 57, 57, 109, 104, 99, 104, 107, 105, 99, 63, 109, 59, 56, 109
        ]
        let chars = encoded.map { UInt8($0) ^ mask }
        return String(bytes: chars, encoding: .utf8) ?? "YOUR_API_KEY_HERE"
    }
}
