//
//  PresetKindLabelTestCase.swift
//  GoMapTests
//

@testable import Go_Map__
import XCTest

final class PresetKindLabelTestCase: XCTestCase {
	override func setUp() {
		super.setUp()
		try? PresetTranslations.shared.setLanguage("de")
	}

	func testPlaygroundExcavatorUsesFieldOptionLabel() {
		guard let feature = PresetsDatabase.shared.presetFeatureForFeatureID("playground") else {
			XCTFail("playground preset missing")
			return
		}
		let label = feature.localizedKindLabel(for: ["playground": "excavator"])
		XCTAssertEqual(label, "Spielbagger")
	}

	func testPlaygroundWithoutTagValueFallsBackToNil() {
		guard let feature = PresetsDatabase.shared.presetFeatureForFeatureID("playground") else {
			XCTFail("playground preset missing")
			return
		}
		XCTAssertNil(feature.localizedKindLabel(for: [:]))
	}

	func testNodeFriendlyDescriptionUsesKindLabel() {
		let mapData = OsmMapData()
		let node = mapData.createNode(atLocation: LatLon(lon: 8.0, lat: 50.0))
		mapData.setTags(["playground": "excavator"], for: node)
		XCTAssertEqual(node.friendlyDescription(), "Spielbagger")
	}
}
