//
//  LocationService.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: ObservableObject {
    @Published var location: CLLocation?
    @Published var locationName: String = "Unknown Location"
    
    // Default location (Piha, New Zealand) - can be configured
    private let defaultLocation = CLLocation(latitude: -36.9545, longitude: 174.4670)
    
    init() {
        // For tvOS, use default location since GPS isn't available
        // In a real app, you might want to allow users to set their location
        self.location = defaultLocation
        self.locationName = "Piha, New Zealand"
    }
    
    func setLocation(latitude: Double, longitude: Double, name: String? = nil) {
        self.location = CLLocation(latitude: latitude, longitude: longitude)
        self.locationName = name ?? "Custom Location"
    }
    
    var coordinate: CLLocationCoordinate2D {
        location?.coordinate ?? defaultLocation.coordinate
    }
}
