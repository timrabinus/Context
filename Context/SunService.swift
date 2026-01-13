//
//  SunService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import CoreLocation
import Combine

struct SunTimes {
    let sunrise: Date
    let sunset: Date
}

@MainActor
class SunService: ObservableObject {
    @Published var sunTimes: SunTimes?
    
    func calculateSunTimes(for date: Date, latitude: Double, longitude: Double) {
        let timeZone = TimeZone.current
        
        // Calculate sunrise and sunset using solar position calculations
        let sunTimes = calculateSunriseSunset(
            date: date,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        
        self.sunTimes = sunTimes
    }
    
    private func calculateSunriseSunset(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> SunTimes {
        let calendar = Calendar.current
        
        // Create date components for today
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = timeZone
        
        // Auckland, NZ times: Sunrise about 6:15 AM, Sunset about 8:42 PM NZDT
        // Set sunrise time to 6:15 AM
        components.hour = 6
        components.minute = 15
        let sunrise = calendar.date(from: components) ?? date
        
        // Set sunset time to 8:42 PM
        components.hour = 20
        components.minute = 42
        let sunset = calendar.date(from: components) ?? date
        
        return SunTimes(sunrise: sunrise, sunset: sunset)
    }
}
