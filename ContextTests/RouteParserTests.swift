//
//  RouteParserTests.swift
//  ContextTests
//
//  Created by Cursor on 23/01/2026.
//

import XCTest
@testable import Context

final class RouteParserTests: XCTestCase {
    func testFromToSameLine() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland
        To: 23 albert st, CBD, auckland
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }
    
    func testFromMultilineToSingleLine() {
        let input = """
        From: 23 esplanade rd, mt eden,
        auckland
        To: 23 albert st, CBD, auckland
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden,\nauckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }
    
    func testToFromOrderReversed() {
        let input = """
        To: 23 albert st, CBD, auckland
        From: 23 esplanade rd, mt eden, auckland
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }
    
    func testFromAtEndWithoutTo() {
        let input = "From: 23 esplanade rd, mt eden, auckland"
        let result = RouteParser.parse(notes: input)
        XCTAssertNil(result)
    }
    
    func testToAtEndWithoutFrom() {
        let input = "To: 23 albert st, CBD, auckland"
        let result = RouteParser.parse(notes: input)
        XCTAssertNil(result)
    }
    
    func testMissingValues() {
        let input = """
        From:
        To: 23 albert st, CBD, auckland
        """
        let result = RouteParser.parse(notes: input)
        XCTAssertNil(result)
    }
    
    func testNotAtEndWithExtraTextIncluded() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland
        To: 23 albert st, CBD, auckland
        Bring umbrella
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland\nBring umbrella")
    }

    func testStopsAtBlankLineAfterTo() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland
        To: 23 albert st, CBD, auckland

        xxx
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }

    func testStopsAtBlankLineAfterFromBeforeTo() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland

        To: 23 albert st, CBD, auckland
        """
        
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }

    func testAllowsBlankLineBeforeCommaContinuation() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland
        To: 23 albert st,

        CBD, auckland
        """

        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st,\nCBD, auckland")
    }

    func testArrowLineBreakNormalization() {
        let input = "From: 23 esplanade rd, mt eden, auckland↩To: 23 albert st, CBD, auckland"
        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }

    func testFormatAddressLinesSplitsOnCommas() {
        let address = "23 albert st, CBD, auckland"
        let lines = RouteParser.formatAddressLines(address)
        XCTAssertEqual(lines, ["23 albert st", "CBD", "auckland"])
    }

    func testFormatAddressLinesSplitsOnNewlines() {
        let address = "23 esplanade rd\nmt eden\nauckland"
        let lines = RouteParser.formatAddressLines(address)
        XCTAssertEqual(lines, ["23 esplanade rd", "mt eden", "auckland"])
    }

    func testProvidedNotesWithTrailingText() {
        let input = """
        From: 23 esplanade rd, mt eden, auckland
        To: 23 albert st, CBD, auckland

        xxx
        """

        let result = RouteParser.parse(notes: input)
        XCTAssertEqual(result?.from, "23 esplanade rd, mt eden, auckland")
        XCTAssertEqual(result?.to, "23 albert st, CBD, auckland")
    }
}
