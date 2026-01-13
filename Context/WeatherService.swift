//
//  WeatherService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import Combine

struct WeatherData {
    let temperature: Double
    let condition: String
    let description: String
    let humidity: Int
    let windSpeed: Double
    let icon: String
}

struct HourlyWeatherData {
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
    @Published var isLoading = false
    @Published var error: String?
    
    // Note: You'll need to add your OpenWeatherMap API key
    // Get one free at https://openweathermap.org/api
    private let apiKey = "YOUR_API_KEY_HERE"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    private let forecastURL = "https://api.openweathermap.org/data/2.5/forecast"
    
    func fetchWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        error = nil
        
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
        
        let urlString = "\(baseURL)?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            if let weatherInfo = response.weather.first {
                self.weather = WeatherData(
                    temperature: response.main.temp,
                    condition: weatherInfo.main,
                    description: weatherInfo.description,
                    humidity: response.main.humidity,
                    windSpeed: response.wind.speed,
                    icon: weatherInfo.icon
                )
            }
        } catch {
            self.error = "Failed to fetch weather: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func fetchHourlyForecast(latitude: Double, longitude: Double) async {
        // If no API key is set, use mock data for development
        guard apiKey != "YOUR_API_KEY_HERE" else {
            // Mock hourly forecast data for 24 hours
            try? await Task.sleep(nanoseconds: 500_000_000)
            let now = Date()
            let calendar = Calendar.current
            // Round current time to the hour for "Now"
            let currentHour = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            let roundedNow = calendar.date(from: currentHour) ?? now
            
            // Generate forecast data every 2 hours (12 data points for 24 hours)
            var forecast: [HourlyWeatherData] = []
            let baseTemp = 24.0
            let icons = ["02d", "02d", "01d", "01d", "01d", "02d", "02d", "02d", "02d", "02d", "02d", "02d"]
            let conditions = ["Cloudy", "Cloudy", "Clear", "Clear", "Clear", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy", "Cloudy"]
            
            for hour in stride(from: 0, to: 24, by: 2) {
                guard let hourDate = calendar.date(byAdding: .hour, value: hour, to: roundedNow) else { continue }
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
            return
        }
        
        let urlString = "\(forecastURL)?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(HourlyForecastResponse.self, from: data)
            
            // Get 24 hours of forecast data
            let now = Date()
            let calendar = Calendar.current
            let currentHour = calendar.dateComponents([.year, .month, .day, .hour], from: now)
            guard let roundedNow = calendar.date(from: currentHour) else { return }
            
            // OpenWeatherMap forecast API returns 3-hour intervals, so we need to interpolate or use available data
            // For now, use all available forecast items (typically 40 items = 5 days * 8 per day)
            // Filter to get next 24 hours
            let next24Hours = calendar.date(byAdding: .hour, value: 24, to: roundedNow) ?? now
            
            let forecastItems = response.list.filter { item in
                let itemDate = Date(timeIntervalSince1970: item.dt)
                return itemDate >= roundedNow && itemDate <= next24Hours
            }
            
            // Generate forecast data every 2 hours (12 data points for 24 hours)
            var hourlyForecast: [HourlyWeatherData] = []
            for hour in stride(from: 0, to: 24, by: 2) {
                guard let hourDate = calendar.date(byAdding: .hour, value: hour, to: roundedNow) else { continue }
                
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
        } catch {
            self.error = "Failed to fetch hourly forecast: \(error.localizedDescription)"
        }
    }
}
