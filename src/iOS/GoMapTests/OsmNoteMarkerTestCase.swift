//
//  OsmNoteMarkerTestCase.swift
//  GoMapTests
//

@testable import Go_Map__
import KissXML
import XCTest

final class OsmNoteMarkerTestCase: XCTestCase {
	func testDateFromNoteDateString_parsesOSMAPIFormat() {
		let date = OsmNoteMarker.date(fromNoteDateString: "2019-06-15 08:26:04 UTC")
		XCTAssertNotNil(date)

		let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!,
		                                                               from: date!)
		XCTAssertEqual(components.year, 2019)
		XCTAssertEqual(components.month, 6)
		XCTAssertEqual(components.day, 15)
		XCTAssertEqual(components.hour, 8)
		XCTAssertEqual(components.minute, 26)
		XCTAssertEqual(components.second, 4)
	}

	func testShouldHide_recentlyClosedNote_staysVisible() throws {
		let closedAt = Date().addingTimeInterval(-3600)
		let closedAtString = OsmNoteMarker.noteAPIDateFormatter.string(from: closedAt)
		let note = try makeNote(status: "closed", dateClosed: closedAtString)

		XCTAssertTrue(note.isClosed)
		XCTAssertFalse(note.shouldHide())
		XCTAssertTrue(note.isRecentlyClosed)
	}

	func testShouldHide_oldClosedNote_isHidden() throws {
		let closedAt = Date().addingTimeInterval(-(25 * 60 * 60))
		let closedAtString = OsmNoteMarker.noteAPIDateFormatter.string(from: closedAt)
		let note = try makeNote(status: "closed", dateClosed: closedAtString)

		XCTAssertTrue(note.shouldHide())
		XCTAssertFalse(note.isRecentlyClosed)
	}

	func testShouldHide_openNote_isVisible() throws {
		let note = try makeNote(status: "open", dateClosed: nil)

		XCTAssertFalse(note.shouldHide())
		XCTAssertFalse(note.isRecentlyClosed)
	}

	private func makeNote(status: String, dateClosed: String?) throws -> OsmNoteMarker {
		var xml = """
		<note lat="51.0" lon="0.1">
		  <id>123</id>
		  <date_created>2019-06-15 08:26:04 UTC</date_created>
		  <status>\(status)</status>
		"""
		if let dateClosed {
			xml += "\n  <date_closed>\(dateClosed)</date_closed>"
		}
		xml += "\n</note>"

		let doc = try DDXMLDocument(xmlString: xml, options: 0)
		let element = try XCTUnwrap(doc.rootElement())
		return try XCTUnwrap(OsmNoteMarker(noteXml: element))
	}
}
