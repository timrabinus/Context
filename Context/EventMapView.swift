//
//  EventMapView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI
import MapKit
import UIKit

struct EventMapView: View {
    let event: CalendarEvent?
    
    private func processLocation(_ location: String) -> String {
        // Log the raw location string to inspect its contents
        print("🔍 [EventMapView] Raw location string:")
        print("🔍 [EventMapView] Length: \(location.count)")
        print("🔍 [EventMapView] String: \(location)")
        print("🔍 [EventMapView] UTF8 bytes: \(location.utf8.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        // First replace \, with comma + newline
        var processed = location.components(separatedBy: "\\,").joined(separator: ",\n")
        
        // Then replace \n with actual newlines
        processed = processed.components(separatedBy: "\\n").joined(separator: "\n")
        
        print("🔍 [EventMapView] Processed location:")
        print("🔍 [EventMapView] \(processed)")
        
        return processed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let location = event?.location, !location.isEmpty {
                Text(processLocation(location))
                    .font(.headline)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .padding(.top)
                    .frame(maxHeight: 150, alignment: .topLeading)
            }
            
            Spacer(minLength: 0)
            
            MapViewWrapper(address: event?.location)
                .frame(minHeight: 0)
                .focusable(false)
        }
    }
}

struct MapViewWrapper: UIViewRepresentable {
    let address: String?
    
    func makeUIView(context: UIViewRepresentableContext<MapViewWrapper>) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.isUserInteractionEnabled = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: UIViewRepresentableContext<MapViewWrapper>) {
        guard let address = address, !address.isEmpty else {
            return
        }
        
        // Use MKLocalSearch instead of deprecated CLGeocoder
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response,
                  let item = response.mapItems.first else {
                return
            }
            
            // Use placemark.location for coordinate, but handle potential nil
            guard let location = item.placemark.location else {
                return
            }
            
            let coordinate = location.coordinate
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0075)
            )
            
            DispatchQueue.main.async {
                mapView.setRegion(region, animated: true)
                
                // Remove existing annotations
                mapView.removeAnnotations(mapView.annotations)
                
                // Add annotation
                let annotation = MKPointAnnotation()
                annotation.coordinate = coordinate
                annotation.title = address
                mapView.addAnnotation(annotation)
            }
        }
    }
}

#Preview {
    EventMapView(
        event: CalendarEvent(
            id: "1",
            calendarId: "calendar1",
            title: "Sample Event",
            startDate: Date(),
            endDate: nil,
            description: "Sample description",
            location: "1600 Amphitheatre Parkway, Mountain View, CA"
        )
    )
}
