//
//  RouteParser.swift
//  Context
//
//  Created by Cursor on 23/01/2026.
//

import Foundation

struct RouteAddresses: Equatable {
    let from: String
    let to: String
}

enum RouteParser {
    static func parse(notes: String?) -> RouteAddresses? {
        guard let notes = notes, !notes.isEmpty else {
            return nil
        }
        
        let normalizedNotes = normalizeICalText(notes)
        
        let markers = extractMarkers(in: normalizedNotes)
        guard let fromRange = markers.first(where: { $0.field == .from })?.range,
              let toRange = markers.first(where: { $0.field == .to })?.range else {
            return nil
        }
        
        let fromValue = extractValue(
            in: normalizedNotes,
            from: fromRange,
            nextMarkerRange: nextMarker(after: fromRange, in: markers)
        )
        let toValue = extractValue(
            in: normalizedNotes,
            from: toRange,
            nextMarkerRange: nextMarker(after: toRange, in: markers)
        )
        
        guard let fromValue, let toValue else {
            return nil
        }
        
        return RouteAddresses(from: fromValue, to: toValue)
    }
    
    static func normalizeICalText(_ text: String) -> String {
        var normalized = text
        
        for _ in 0..<2 {
            let unescaped = unescapeICalText(normalized)
            if unescaped == normalized {
                break
            }
            normalized = unescaped
        }
        
        normalized = normalized
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "↩", with: "\n")
            .replacingOccurrences(of: "↵", with: "\n")
            .replacingOccurrences(of: "⏎", with: "\n")
        
        return normalized
    }

    static func formatAddressLines(_ address: String) -> [String] {
        var normalized = address
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "﹐", with: ",")
            .replacingOccurrences(of: "､", with: ",")
            .replacingOccurrences(of: "،", with: ",")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        normalized = normalized.replacingOccurrences(of: ",", with: "\n")

        return normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private static func unescapeICalText(_ text: String) -> String {
        var result = ""
        var iterator = text.makeIterator()
        
        while let character = iterator.next() {
            if character == "\\" {
                guard let next = iterator.next() else { break }
                switch next {
                case "n", "N":
                    result.append("\n")
                case ",":
                    result.append(",")
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
    
    private static func extractMarkers(in text: String) -> [(field: Field, range: Range<String.Index>)] {
        let lowercased = text.lowercased()
        var markers: [(field: Field, range: Range<String.Index>)] = []
        var searchStart = lowercased.startIndex
        
        while searchStart < lowercased.endIndex {
            let fromRange = lowercased.range(of: "from:", range: searchStart..<lowercased.endIndex)
            let toRange = lowercased.range(of: "to:", range: searchStart..<lowercased.endIndex)
            
            let nextRange = [fromRange, toRange]
                .compactMap { $0 }
                .min(by: { $0.lowerBound < $1.lowerBound })
            
            guard let nextRange else { break }
            
            if nextRange == fromRange {
                markers.append((field: .from, range: nextRange))
            } else if nextRange == toRange {
                markers.append((field: .to, range: nextRange))
            }
            
            searchStart = nextRange.upperBound
        }
        
        return markers
    }
    
    private static func nextMarker(after range: Range<String.Index>,
                                   in markers: [(field: Field, range: Range<String.Index>)]) -> Range<String.Index>? {
        markers
            .map(\.range)
            .filter { $0.lowerBound > range.lowerBound }
            .min(by: { $0.lowerBound < $1.lowerBound })
    }
    
    private static func extractValue(in text: String,
                                     from markerRange: Range<String.Index>,
                                     nextMarkerRange: Range<String.Index>?) -> String? {
        let endIndex = nextMarkerRange?.lowerBound ?? text.endIndex
        guard markerRange.upperBound < endIndex else { return nil }
        
        let raw = text[markerRange.upperBound..<endIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let lines = raw.components(separatedBy: .newlines)
        var collected: [String] = []
        var index = 0
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                var lookaheadIndex = index + 1
                var nextNonEmpty: String?
                while lookaheadIndex < lines.count {
                    let candidate = lines[lookaheadIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidate.isEmpty {
                        nextNonEmpty = candidate
                        break
                    }
                    lookaheadIndex += 1
                }
                
                if let nextNonEmpty,
                   nextNonEmpty.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil ||
                    nextNonEmpty.contains(",") {
                    index += 1
                    continue
                }
                
                break
            }
            
            collected.append(trimmed)
            index += 1
        }
        
        guard !collected.isEmpty else { return nil }
        return collected.joined(separator: "\n")
    }
    
    private enum Field {
        case from
        case to
    }
}
