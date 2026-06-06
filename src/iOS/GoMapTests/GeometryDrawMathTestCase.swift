//
//  GeometryDrawMathTestCase.swift
//  GoMapTests
//

@testable import Go_Map__
import XCTest

final class GeometryDrawMathTestCase: XCTestCase {
	func testRectangleCornersAreRightAngled() {
		let a = OSMPoint(x: 0, y: 0)
		let b = OSMPoint(x: 10, y: 0)
		let hint = OSMPoint(x: 10, y: 7)
		let corners = GeometryDrawMath.rectangleCorners(cornerA: a, cornerB: b, thirdPointHint: hint)
		XCTAssertEqual(corners.count, 4)

		func angle(at i: Int) -> Double {
			let p0 = corners[(i + 3) % 4]
			let p1 = corners[i]
			let p2 = corners[(i + 1) % 4]
			let v1 = Sub(p1, p0).unitVector()
			let v2 = Sub(p2, p1).unitVector()
			return abs(acos(max(-1, min(1, Dot(v1, v2))))) * 180 / .pi
		}
		for i in 0..<4 {
			XCTAssertEqual(angle(at: i), 90, accuracy: 0.01)
		}
	}

	func testRectangleThirdCornerProjectsOntoPerpendicular() {
		let a = OSMPoint(x: 0, y: 0)
		let b = OSMPoint(x: 5, y: 0)
		let hint = OSMPoint(x: 20, y: 4) // off the perpendicular through B
		let corners = GeometryDrawMath.rectangleCorners(cornerA: a, cornerB: b, thirdPointHint: hint)
		XCTAssertEqual(corners[2].x, 5, accuracy: 1e-9)
		XCTAssertEqual(corners[2].y, 4, accuracy: 1e-9)
	}

	func testCircleRingIsClosedAndSymmetric() {
		let a = OSMPoint(x: 0, y: 0)
		let b = OSMPoint(x: 10, y: 0)
		let ring = GeometryDrawMath.circleRing(diameterA: a, diameterB: b, segments: 16)
		XCTAssertEqual(ring.count, 16)
		let center = OSMPoint(x: 5, y: 0)
		let radius = 5.0
		for p in ring {
			XCTAssertEqual(p.distanceToPoint(center), radius, accuracy: 1e-9)
		}
	}

	func testPreviewPolylineIncludesRubberBand() {
		let line = GeometryDrawMath.previewPolyline(fixedPoints: [OSMPoint(x: 1, y: 1)],
		                                            rubberBandEnd: OSMPoint(x: 2, y: 3))
		XCTAssertEqual(line.count, 2)
		XCTAssertEqual(line[1].x, 2)
		XCTAssertEqual(line[1].y, 3)
	}
}
