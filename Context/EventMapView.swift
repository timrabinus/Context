//
//  EventMapView.swift
//  Context
//
//  Created by Martin on 11/01/2026.
//

import SwiftUI
import MapKit

struct EventMapView: View {
    let event: CalendarEvent?
    
    private func unescapeICalText(_ text: String, newlineForEscapedComma: Bool = false) -> String {
        var result = ""
        var iterator = text.makeIterator()
        
        while let character = iterator.next() {
            if character == "\\" {
                guard let next = iterator.next() else { break }
                switch next {
                case "n", "N":
                    result.append("\n")
                case ",":
                    result.append(newlineForEscapedComma ? ",\n" : ",")
                case ";":
                    result.append(";")
                case "\\":
                    result.append("\\")
                default:
                    result.append(next)
                }
            } else {
                result.append(character)
            }
        }
        
        return result
    }
    
    private func normalizeICalText(_ text: String, newlineForEscapedComma: Bool = false) -> String {
        var normalized = text
        
        for _ in 0..<2 {
            let unescaped = unescapeICalText(normalized, newlineForEscapedComma: newlineForEscapedComma)
            if unescaped == normalized {
                break
            }
            normalized = unescaped
        }
        
        normalized = normalized
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: newlineForEscapedComma ? ",\n" : ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
        
        return normalized
    }
    
    private func processLocation(_ location: String) -> String {
        // Log the raw location string to inspect its contents
        print("🔍 [EventMapView] Raw location string:")
        print("🔍 [EventMapView] Length: \(location.count)")
        print("🔍 [EventMapView] String: \(location)")
        print("🔍 [EventMapView] UTF8 bytes: \(location.utf8.map { String(format: "%02x", $0) }.joined(separator: " "))")
        
        let processed = normalizeICalText(location, newlineForEscapedComma: true)
        
        print("🔍 [EventMapView] Processed location:")
        print("🔍 [EventMapView] \(processed)")
        
        return processed
    }
    
    var body: some View {
        let routeAddresses = RouteParser.parse(notes: event?.description)
        let locationText = event?.location
        
        VStack(alignment: .leading, spacing: 20) {
            MapViewWrapper(address: event?.location, routeAddresses: routeAddresses)
                .aspectRatio(16 / 9, contentMode: .fit)
                .focusable(false)
            
            if let routeAddresses = routeAddresses {
                let fromLines = RouteParser.formatAddressLines(routeAddresses.from)
                let toLines = RouteParser.formatAddressLines(routeAddresses.to)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        Text("From:")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 88, alignment: .leading)
                        Text(fromLines.joined(separator: "\n"))
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        Text("To:")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .frame(width: 88, alignment: .leading)
                        Text(toLines.joined(separator: "\n"))
                            .font(.body)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    
                    
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom)
            } else if let locationText, !locationText.isEmpty {
                Text(processLocation(locationText))
                    .font(.body)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom)
            }
        }
    }
}

struct MapViewWrapper: UIViewRepresentable {
    let address: String?
    let routeAddresses: RouteAddresses?
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: UIViewRepresentableContext<MapViewWrapper>) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.isUserInteractionEnabled = false
        mapView.overrideUserInterfaceStyle = .light
        mapView.showsScale = true
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: UIViewRepresentableContext<MapViewWrapper>) {
        if let routeAddresses = routeAddresses {
            displayRoute(from: routeAddresses.from, to: routeAddresses.to, on: mapView)
            return
        }
        
        guard let address = address, !address.isEmpty else {
            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)
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
                mapView.removeOverlays(mapView.overlays)
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
    
    private func displayRoute(from sourceAddress: String, to destinationAddress: String, on mapView: MKMapView) {
        let sourceRequest = MKLocalSearch.Request()
        sourceRequest.naturalLanguageQuery = sourceAddress
        
        let destinationRequest = MKLocalSearch.Request()
        destinationRequest.naturalLanguageQuery = destinationAddress
        
        MKLocalSearch(request: sourceRequest).start { sourceResponse, _ in
            guard let sourceItem = sourceResponse?.mapItems.first else {
                return
            }
            
            MKLocalSearch(request: destinationRequest).start { destinationResponse, _ in
                guard let destinationItem = destinationResponse?.mapItems.first else {
                    return
                }
                
                let request = MKDirections.Request()
                request.source = sourceItem
                request.destination = destinationItem
                request.transportType = .walking
                
                MKDirections(request: request).calculate { response, _ in
                    guard let route = response?.routes.first else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        mapView.removeOverlays(mapView.overlays)
                        mapView.removeAnnotations(mapView.annotations)
                        
                        mapView.addOverlay(route.polyline)
                        
                        let sourceAnnotation = MKPointAnnotation()
                        sourceAnnotation.coordinate = sourceItem.placemark.coordinate
                        sourceAnnotation.title = sourceAddress
                        
                        let destinationAnnotation = MKPointAnnotation()
                        destinationAnnotation.coordinate = destinationItem.placemark.coordinate
                        destinationAnnotation.title = destinationAddress
                        
                        mapView.addAnnotations([sourceAnnotation, destinationAnnotation])
                        
                        mapView.setVisibleMapRect(
                            route.polyline.boundingMapRect,
                            edgePadding: UIEdgeInsets(top: 80, left: 60, bottom: 80, right: 60),
                            animated: true
                        )
                    }
                }
            }
        }
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 6
            return renderer
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
