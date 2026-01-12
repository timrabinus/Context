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
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // Convert latitude to radians
        let latRad = latitude * .pi / 180.0
        
        // Calculate the declination of the sun
        let declination = 23.45 * sin((360.0 / 365.0) * (284.0 + Double(dayOfYear)) * .pi / 180.0)
        let declRad = declination * .pi / 180.0
        
        // Calculate the hour angle
        let hourAngle = acos(-tan(latRad) * tan(declRad))
        
        // Convert hour angle to time
        let sunriseHour = 12.0 - (hourAngle * 12.0 / .pi)
        let sunsetHour = 12.0 + (hourAngle * 12.0 / .pi)
        
        // Adjust for longitude (time zone correction)
        let timeCorrection = (longitude / 15.0) - Double(timeZone.secondsFromGMT()) / 3600.0
        let sunriseLocal = sunriseHour + timeCorrection
        let sunsetLocal = sunsetHour + timeCorrection
        
        // Create date components for today
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = timeZone
        
        // Set sunrise time
        let sunriseHourInt = Int(sunriseLocal)
        let sunriseMinute = Int((sunriseLocal - Double(sunriseHourInt)) * 60.0)
        components.hour = sunriseHourInt
        components.minute = sunriseMinute
        let sunrise = calendar.date(from: components) ?? date
        
        // Set sunset time
        let sunsetHourInt = Int(sunsetLocal)
        let sunsetMinute = Int((sunsetLocal - Double(sunsetHourInt)) * 60.0)
        components.hour = sunsetHourInt
        components.minute = sunsetMinute
        let sunset = calendar.date(from: components) ?? date
        
        return SunTimes(sunrise: sunrise, sunset: sunset)
    }
}
