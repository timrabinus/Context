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
    
    // Default location (San Francisco) - can be configured
    private let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    
    init() {
        // For tvOS, use default location since GPS isn't available
        // In a real app, you might want to allow users to set their location
        self.location = defaultLocation
        self.locationName = "San Francisco, CA"
    }
    
    func setLocation(latitude: Double, longitude: Double, name: String? = nil) {
        self.location = CLLocation(latitude: latitude, longitude: longitude)
        self.locationName = name ?? "Custom Location"
    }
    
    var coordinate: CLLocationCoordinate2D {
        location?.coordinate ?? defaultLocation.coordinate
    }
}
