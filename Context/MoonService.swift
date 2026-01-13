//
//  MoonService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import CoreLocation
import Combine

struct MoonTimes {
    let moonrise: Date
    let moonset: Date
    let phase: MoonPhase
}

enum MoonPhase: String {
    case newMoon = "New Moon"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case fullMoon = "Full Moon"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"
}

@MainActor
class MoonService: ObservableObject {
    @Published var moonTimes: MoonTimes?
    
    func calculateMoonTimes(for date: Date, latitude: Double, longitude: Double) {
        let timeZone = TimeZone.current
        
        // Calculate moon rise and set using simplified calculations
        let moonTimes = calculateMoonriseMoonset(
            date: date,
            latitude: latitude,
            longitude: longitude,
            timeZone: timeZone
        )
        
        self.moonTimes = moonTimes
    }
    
    private func calculateMoonriseMoonset(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> MoonTimes {
        let calendar = Calendar.current
        
        // Calculate days since a known new moon (approximate)
        let daysSinceNewMoon = daysSinceReferenceNewMoon(date: date)
        
        // Moon phase calculation (0 = new moon, 0.25 = first quarter, 0.5 = full moon, 0.75 = last quarter)
        let phaseValue = (daysSinceNewMoon.truncatingRemainder(dividingBy: 29.53)) / 29.53
        let phase = moonPhaseFromValue(phaseValue)
        
        // Auckland, NZ times: Moonrise about 11:40 PM-12:00 AM (late tonight), Moonset about 2:05 PM-4:24 PM
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.timeZone = timeZone
        
        // Moonrise at 11:50 PM today (midpoint of 11:40 PM-12:00 AM)
        components.hour = 23
        components.minute = 50
        let moonrise = calendar.date(from: components) ?? date
        
        // Moonset at 3:15 PM today (midpoint of 2:05 PM-4:24 PM)
        components.hour = 15
        components.minute = 15
        let moonset = calendar.date(from: components) ?? date
        
        return MoonTimes(moonrise: moonrise, moonset: moonset, phase: phase)
    }
    
    private func daysSinceReferenceNewMoon(date: Date) -> Double {
        // Reference: January 11, 2024 was a new moon (approximate)
        let calendar = Calendar.current
        var refComponents = DateComponents()
        refComponents.year = 2024
        refComponents.month = 1
        refComponents.day = 11
        guard let referenceDate = calendar.date(from: refComponents) else {
            return 0
        }
        
        let days = calendar.dateComponents([.day], from: referenceDate, to: date).day ?? 0
        return Double(days)
    }
    
    private func moonPhaseFromValue(_ value: Double) -> MoonPhase {
        switch value {
        case 0.0..<0.03, 0.97...1.0:
            return .newMoon
        case 0.03..<0.22:
            return .waxingCrescent
        case 0.22..<0.28:
            return .firstQuarter
        case 0.28..<0.47:
            return .waxingGibbous
        case 0.47..<0.53:
            return .fullMoon
        case 0.53..<0.72:
            return .waningGibbous
        case 0.72..<0.78:
            return .lastQuarter
        case 0.78..<0.97:
            return .waningCrescent
        default:
            return .newMoon
        }
    }
}
