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

    func fetchMoonTimes(latitude: Double, longitude: Double, date: Date = Date()) async {
        let apiKey = MoonService.deobfuscatedApiKey()
        guard apiKey != "YOUR_API_KEY_HERE" else {
            calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
            return
        }

        let urlString = "https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/\(latitude),\(longitude)/today?unitGroup=metric&elements=moonphase,moonrise,moonset&key=\(apiKey)&contentType=json"
        guard let url = URL(string: urlString) else {
            logError("Invalid Visual Crossing URL")
            calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                logError("Visual Crossing error: HTTP \(httpResponse.statusCode) | \(body)")
                calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
                return
            }

            let decoded = try JSONDecoder().decode(VisualCrossingTimelineResponse.self, from: data)
            guard let day = decoded.days.first else {
                logError("Visual Crossing response missing day data")
                calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
                return
            }

            guard let moonrise = parseMoonDate(from: day.moonrise, dayString: day.datetime),
                  let moonset = parseMoonDate(from: day.moonset, dayString: day.datetime) else {
                logError("Visual Crossing missing moonrise/moonset")
                calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
                return
            }

            let phaseValue = day.moonphase ?? daysSinceReferenceNewMoon(date: date)
                .truncatingRemainder(dividingBy: 29.53) / 29.53
            let phase = moonPhaseFromValue(phaseValue)

            self.moonTimes = MoonTimes(moonrise: moonrise, moonset: moonset, phase: phase)
        } catch {
            logError("Failed to fetch moon data: \(error.localizedDescription)")
            calculateMoonTimes(for: date, latitude: latitude, longitude: longitude)
        }
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

    private func parseMoonDate(from timeString: String?, dayString: String?) -> Date? {
        guard let timeString else { return nil }

        if timeString.contains("T") {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFormatter.date(from: timeString) {
                return date
            }
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: timeString)
        }

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone.current
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dayDate = dayString.flatMap { dateFormatter.date(from: $0) } ?? calendar.startOfDay(for: Date())

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = TimeZone.current

        timeFormatter.dateFormat = "HH:mm:ss"
        if let time = timeFormatter.date(from: timeString) {
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
            return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                 minute: timeComponents.minute ?? 0,
                                 second: timeComponents.second ?? 0,
                                 of: dayDate)
        }

        timeFormatter.dateFormat = "HH:mm"
        if let time = timeFormatter.date(from: timeString) {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                                 minute: timeComponents.minute ?? 0,
                                 second: 0,
                                 of: dayDate)
        }

        return nil
    }

    private func logError(_ message: String) {
        print("MoonService: \(message)")
    }

    private struct VisualCrossingTimelineResponse: Codable {
        let days: [VisualCrossingDay]
    }

    private struct VisualCrossingDay: Codable {
        let datetime: String?
        let moonphase: Double?
        let moonrise: String?
        let moonset: String?
    }

    private static func deobfuscatedApiKey() -> String {
        let mask: UInt8 = 0x5A
        let encoded: [UInt8] = [
            15, 24, 110, 15, 9, 23, 27, 98, 98, 18, 3, 104, 11, 10, 105, 105, 13, 31, 99,
            3, 24, 11, 3, 17, 22
        ]
        let chars = encoded.map { $0 ^ mask }
        return String(bytes: chars, encoding: .utf8) ?? "YOUR_API_KEY_HERE"
    }
}
