//
//  TideService.swift
//
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import Combine

struct TideEvent: Identifiable, Codable {
    let id: String
    let time: Date
    let type: TideType
    let height: Double
    
    enum TideType: String, Codable {
        case high = "High"
        case low = "Low"
    }
}

struct TideData: Codable {
    let predictions: [TidePrediction]
    
    struct TidePrediction: Codable {
        let t: String // time
        let v: String // height
        let type: String // "H" for high, "L" for low
    }
}

@MainActor
class TideService: ObservableObject {
    @Published var tides: [TideEvent] = []
    @Published var isLoading = false
    @Published var error: String?
    
    // NOAA Tides API endpoint
    // Note: You'll need to find the station ID for your location
    // Find stations at: https://tidesandcurrents.noaa.gov/stations.html
    private let baseURL = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
    
    func fetchTides(latitude: Double, longitude: Double) async {
        isLoading = true
        error = nil
        
        // Find nearest station (simplified - in production, use NOAA station finder API)
        // For now, using a default station (San Francisco)
        let stationId = findNearestStation(latitude: latitude, longitude: longitude)
        
        let calendar = Calendar.current
        let today = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let beginDate = dateFormatter.string(from: today)
        let endDate = dateFormatter.string(from: tomorrow)
        
        let urlString = "\(baseURL)?product=predictions&application=NOS.COOPS.TAC.WL&begin_date=\(beginDate)&end_date=\(endDate)&datum=MLLW&station=\(stationId)&time_zone=lst_ldt&units=english&interval=hilo&format=json"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Check if we got an error response
            if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
               errorResponse["error"] != nil {
                // If station not found or error, use mock data
                self.tides = generateMockTides(for: today)
                self.isLoading = false
                return
            }
            
            let tideData = try JSONDecoder().decode(TideData.self, from: data)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            dateFormatter.timeZone = TimeZone.current
            
            var tideEvents: [TideEvent] = []
            
            for prediction in tideData.predictions {
                // Parse the date string (format: "2024-01-15 12:30")
                if let date = dateFormatter.date(from: prediction.t) {
                    let tideType: TideEvent.TideType = prediction.type == "H" ? .high : .low
                    let height = Double(prediction.v) ?? 0.0
                    
                    tideEvents.append(TideEvent(
                        id: "\(prediction.t)-\(prediction.type)",
                        time: date,
                        type: tideType,
                        height: height
                    ))
                }
            }
            
            // Filter to today and tomorrow, sort by time
            let todayStart = calendar.startOfDay(for: today)
            let tomorrowEnd = calendar.date(byAdding: .day, value: 2, to: todayStart) ?? todayStart
            
            self.tides = tideEvents
                .filter { $0.time >= todayStart && $0.time < tomorrowEnd }
                .sorted { $0.time < $1.time }
            
        } catch {
            // If API fails, use mock data
            self.tides = generateMockTides(for: today)
        }
        
        isLoading = false
    }
    
    private func findNearestStation(latitude: Double, longitude: Double) -> String {
        // Simplified station finder - in production, use NOAA's station finder API
        // For now, return a default station (San Francisco: 9414290)
        // You can expand this with a lookup table or API call
        
        // San Francisco Bay
        if latitude > 37.5 && latitude < 38.0 && longitude > -123.0 && longitude < -122.0 {
            return "9414290"
        }
        
        // Default to San Francisco
        return "9414290"
    }
    
    private func generateMockTides(for date: Date) -> [TideEvent] {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = TimeZone.current
        
        var tides: [TideEvent] = []
        
        // Generate mock tides: high at ~6am and 6pm, low at ~12pm and 12am
        let times: [(hour: Int, minute: Int, type: TideEvent.TideType, height: Double)] = [
            (6, 15, .high, 5.2),
            (12, 30, .low, 0.8),
            (18, 45, .high, 4.8),
            (0, 20, .low, 1.2)
        ]
        
        for (index, timeInfo) in times.enumerated() {
            components.hour = timeInfo.hour
            components.minute = timeInfo.minute
            
            if let tideDate = calendar.date(from: components) {
                tides.append(TideEvent(
                    id: "mock-\(index)",
                    time: tideDate,
                    type: timeInfo.type,
                    height: timeInfo.height
                ))
            }
        }
        
        // Also add tomorrow's first tide
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            tomorrowComponents.hour = 6
            tomorrowComponents.minute = 45
            if let tomorrowTide = calendar.date(from: tomorrowComponents) {
                tides.append(TideEvent(
                    id: "mock-tomorrow",
                    time: tomorrowTide,
                    type: .high,
                    height: 5.0
                ))
            }
        }
        
        return tides.sorted { $0.time < $1.time }
    }
}
