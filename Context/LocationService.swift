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
    @Published private(set) var selectedLocationId: String = "piha"
    
    struct LocationOption {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
    }
    
    private static let settingsKey = "selectedLocation"
    private static let locationOptions: [String: LocationOption] = [
        "auckland": LocationOption(
            id: "auckland",
            name: "Auckland, NZ",
            coordinate: CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633)
        ),
        "piha": LocationOption(
            id: "piha",
            name: "Piha, NZ",
            coordinate: CLLocationCoordinate2D(latitude: -36.9545, longitude: 174.4670)
        )
    ]
    
    private let defaultLocationId = "piha"
    private var settingsObserver: NSObjectProtocol?
    
    init() {
        // For tvOS, use a settings-driven location since GPS isn't available
        applyStoredLocation()
        observeSettingsChanges()
    }
    
    deinit {
        if let observer = settingsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func setLocation(latitude: Double, longitude: Double, name: String? = nil) {
        self.location = CLLocation(latitude: latitude, longitude: longitude)
        self.locationName = name ?? "Custom Location"
        self.selectedLocationId = "custom"
    }
    
    var coordinate: CLLocationCoordinate2D {
        location?.coordinate ?? fallbackLocation().coordinate
    }
    
    private func applyStoredLocation() {
        let storedValue = UserDefaults.standard.string(forKey: Self.settingsKey) ?? defaultLocationId
        updateLocation(for: storedValue)
    }
    
    private func observeSettingsChanges() {
        settingsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyStoredLocation()
        }
    }
    
    private func updateLocation(for id: String) {
        let option = Self.locationOptions[id] ?? fallbackLocation()
        location = CLLocation(latitude: option.coordinate.latitude, longitude: option.coordinate.longitude)
        locationName = option.name
        selectedLocationId = option.id
    }
    
    private func fallbackLocation() -> LocationOption {
        Self.locationOptions[defaultLocationId]
            ?? LocationOption(
                id: defaultLocationId,
                name: "Piha, NZ",
                coordinate: CLLocationCoordinate2D(latitude: -36.9545, longitude: 174.4670)
            )
    }
}
