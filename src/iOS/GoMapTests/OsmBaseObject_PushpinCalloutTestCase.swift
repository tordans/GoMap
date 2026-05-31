//
//  OsmBaseObject_PushpinCalloutTestCase.swift
//  GoMapTests
//

@testable import Go_Map__
import XCTest

class OsmBaseObject_PushpinCalloutTestCase: XCTestCase {
	func testCalloutTextsAreRedundantIgnoresCaseAndWhitespace() {
		XCTAssertTrue(OsmBaseObject.calloutTextsAreRedundant("  Foo ", "foo"))
		XCTAssertFalse(OsmBaseObject.calloutTextsAreRedundant("Foo", "Bar"))
	}

	func testPushpinCalloutLinesWithPresetAndName() {
		let node = OsmNode(asUserCreated: "")
		node.constructTag("shop", value: "convenience")
		node.constructTag("name", value: "Foo")

		let lines = node.pushpinCalloutLines()

		XCTAssertEqual(lines.secondary, "Foo")
		XCTAssertNotEqual(lines.primary, "Foo")
		if let feature = PresetsDatabase.shared.presetFeatureMatching(
			tags: node.tags,
			geometry: node.geometry(),
			location: AppDelegate.shared.mainView.currentRegion,
			includeNSI: true),
			!feature.isGeneric()
		{
			XCTAssertEqual(lines.primary, feature.friendlyName())
		} else {
			XCTFail("Expected a non-generic preset match for shop=convenience")
		}
	}

	func testPushpinCalloutLinesWithPresetOnly() {
		let node = OsmNode(asUserCreated: "")
		node.constructTag("shop", value: "convenience")

		let lines = node.pushpinCalloutLines()

		XCTAssertNil(lines.secondary)
		XCTAssertFalse(lines.primary.isEmpty)
	}

	func testPushpinCalloutLinesWithNameOnly() {
		let node = OsmNode(asUserCreated: "")
		node.constructTag("name", value: "Only Name")

		let lines = node.pushpinCalloutLines()

		XCTAssertEqual(lines.secondary, "Only Name")
		XCTAssertNotEqual(lines.primary, "Only Name")
	}

	func testPushpinCalloutLinesOmitsRedundantSecondary() {
		let node = OsmNode(asUserCreated: "")
		node.constructTag("shop", value: "convenience")

		let presetLabel = node.pushpinCalloutLines().primary
		node.constructTag("name", value: presetLabel)

		let lines = node.pushpinCalloutLines()

		XCTAssertNil(lines.secondary)
		XCTAssertEqual(lines.primary, presetLabel)
	}

	func testFriendlyDescriptionStillPrefersName() {
		let node = OsmNode(asUserCreated: "")
		node.constructTag("shop", value: "convenience")
		node.constructTag("name", value: "Foo")

		XCTAssertEqual(node.friendlyDescription(), "Foo")
	}
}
