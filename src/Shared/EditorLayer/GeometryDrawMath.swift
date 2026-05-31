//
//  GeometryDrawMath.swift
//  Go Map!!
//
//  Pure geometry helpers for map drawing tools (rectangle, circle).
//

import CoreGraphics
import Foundation

enum GeometryDrawTool: Equatable {
	case line
	case rectangle
	case circle
}

/// Local map-plane coordinates (lon, latp) for small-area geometry.
struct GeometryDrawMath {
	/// Convert geographic coordinate to local plane point.
	static func planePoint(for latLon: LatLon) -> OSMPoint {
		OSMPoint(x: latLon.lon, y: lat2latp(latLon.lat))
	}

	/// Convert local plane point back to geographic coordinate.
	static func latLon(for planePoint: OSMPoint) -> LatLon {
		LatLon(lon: planePoint.x, lat: latp2lat(planePoint.y))
	}

	/// Four corners of a true rectangle from two fixed adjacent corners and a third-point hint.
	/// The hint is projected onto the line through `cornerB` perpendicular to edge A–B.
	static func rectangleCorners(
		cornerA: OSMPoint,
		cornerB: OSMPoint,
		thirdPointHint: OSMPoint
	) -> [OSMPoint] {
		let edge = Sub(cornerB, cornerA)
		let edgeLen = Mag(edge)
		guard edgeLen > 1e-12 else {
			return [cornerA, cornerB, cornerB, cornerA]
		}
		let perp = OSMPoint(x: -edge.y / edgeLen, y: edge.x / edgeLen)
		let width = Dot(Sub(thirdPointHint, cornerB), perp)
		let cornerC = Add(cornerB, Mult(perp, width))
		let cornerD = Add(cornerA, Sub(cornerC, cornerB))
		return [cornerA, cornerB, cornerC, cornerD]
	}

	/// Closed ring of points approximating a circle from diameter endpoints.
	static func circleRing(diameterA: OSMPoint, diameterB: OSMPoint, segments: Int = 24) -> [OSMPoint] {
		let center = Add(diameterA, Mult(Sub(diameterB, diameterA), 0.5))
		let radius = Mag(Sub(diameterB, diameterA)) * 0.5
		guard radius > 1e-12, segments >= 3 else {
			return [diameterA, diameterB, diameterA]
		}
		var points: [OSMPoint] = []
		points.reserveCapacity(segments)
		for i in 0..<segments {
			let angle = 2.0 * Double.pi * Double(i) / Double(segments)
			points.append(OSMPoint(x: center.x + radius * cos(angle),
			                       y: center.y + radius * sin(angle)))
		}
		return points
	}

	/// Open polyline from fixed points plus a rubber-band endpoint (line or rectangle preview).
	static func previewPolyline(fixedPoints: [OSMPoint], rubberBandEnd: OSMPoint) -> [OSMPoint] {
		guard !fixedPoints.isEmpty else { return [rubberBandEnd] }
		return fixedPoints + [rubberBandEnd]
	}
}
