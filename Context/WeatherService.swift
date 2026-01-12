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

@MainActor
class WeatherService: ObservableObject {
    @Published var weather: WeatherData?
    @Published var isLoading = false
    @Published var error: String?
    
    // Note: You'll need to add your OpenWeatherMap API key
    // Get one free at https://openweathermap.org/api
    private let apiKey = "YOUR_API_KEY_HERE"
    private let baseURL = "https://api.openweathermap.org/data/2.5/weather"
    
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
}
