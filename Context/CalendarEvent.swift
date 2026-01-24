//
//  CalendarEvent.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation

struct CalendarEvent: Identifiable, Equatable, Codable {
    let id: String
    let calendarId: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let description: String?
    let location: String?
    
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
    
    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if let endDate = endDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return formatter.string(from: startDate)
        }
    }
}
