//
//  EditorMapLayer+GeometryDraw.swift
//  Go Map!!
//

import UIKit

extension EditorMapLayer {
	var isGeometryDrawActive: Bool {
		geometryDrawTool != nil
	}

	func beginGeometryDraw(_ tool: GeometryDrawTool) {
		cancelGeometryDraw()
		geometryDrawTool = tool
		geometryDrawFixedCorners = []
		owner.unselectAll()
		owner.removePin()

		let hint: String
		switch tool {
		case .line:
			hint = NSLocalizedString("Line: tap map to add vertices. Undo to cancel.", comment: "geometry draw")
			owner.placePushpin(at: crosshairScreenPoint(), object: nil)
		case .rectangle:
			hint = NSLocalizedString("Rectangle: tap three corners. Undo to cancel.", comment: "geometry draw")
		case .circle:
			hint = NSLocalizedString("Circle: tap diameter endpoints. Undo to cancel.", comment: "geometry draw")
		}
		display.flashMessage(title: nil, message: hint)
		subscribeGeometryDrawPreview()
		updateGeometryDrawPreview()
	}

	func cancelGeometryDraw() {
		guard geometryDrawTool != nil else { return }
		geometryDrawTool = nil
		geometryDrawFixedCorners = []
		removeGeometryDrawPreview()
		unsubscribeGeometryDrawPreview()
	}

	func geometryDrawTap(at screenPoint: CGPoint) {
		guard let tool = geometryDrawTool else { return }
		if isHidden {
			display.flashMessage(title: nil,
			                     message: NSLocalizedString("Editing layer not visible", comment: ""))
			return
		}

		switch tool {
		case .line:
			addNode(at: screenPoint)
		case .rectangle:
			handleRectangleTap(at: screenPoint)
		case .circle:
			handleCircleTap(at: screenPoint)
		}
		updateGeometryDrawPreview()
	}

	func updateGeometryDrawPreview() {
		guard let tool = geometryDrawTool else {
			removeGeometryDrawPreview()
			return
		}
		let crosshairPlane = GeometryDrawMath.planePoint(for: viewPort.screenCenterLatLon())

		var planePoints: [OSMPoint] = []
		switch tool {
		case .line:
			if let pushpin = owner.pushpinView() {
				let anchor = GeometryDrawMath.planePoint(
					for: viewPort.mapTransform.latLon(forScreenPoint: pushpin.arrowPoint))
				planePoints = GeometryDrawMath.previewPolyline(fixedPoints: [anchor],
				                                               rubberBandEnd: crosshairPlane)
			}
		case .rectangle:
			let fixed = geometryDrawFixedCorners.map { GeometryDrawMath.planePoint(for: $0) }
			switch fixed.count {
			case 0:
				break
			case 1:
				planePoints = GeometryDrawMath.previewPolyline(fixedPoints: fixed,
				                                               rubberBandEnd: crosshairPlane)
			default:
				let corners = GeometryDrawMath.rectangleCorners(cornerA: fixed[0],
				                                                  cornerB: fixed[1],
				                                                  thirdPointHint: crosshairPlane)
				planePoints = corners + [corners[0]]
			}
		case .circle:
			let fixed = geometryDrawFixedCorners.map { GeometryDrawMath.planePoint(for: $0) }
			if fixed.count == 1 {
				planePoints = GeometryDrawMath.circleRing(diameterA: fixed[0],
				                                            diameterB: crosshairPlane)
				planePoints.append(planePoints[0])
			}
		}

		guard !planePoints.isEmpty else {
			removeGeometryDrawPreview()
			return
		}
		let path = previewPath(forPlanePoints: planePoints)
		let layer = geometryDrawPreviewLayer ?? {
			let shape = CAShapeLayer()
			shape.strokeColor = UIColor.systemOrange.cgColor
			shape.fillColor = nil
			shape.lineWidth = 3.0
			shape.lineDashPattern = [8, 6]
			shape.zPosition = 200
			insertSublayer(shape, at: UInt32(sublayers?.count ?? 0))
			geometryDrawPreviewLayer = shape
			return shape
		}()
		layer.path = path
		layer.frame = bounds
	}

	// MARK: Private

	private func crosshairScreenPoint() -> CGPoint {
		viewPort.screenCenterPoint()
	}

	private func handleRectangleTap(at screenPoint: CGPoint) {
		let latLon = viewPort.mapTransform.latLon(forScreenPoint: screenPoint)
		geometryDrawFixedCorners.append(latLon)
		if geometryDrawFixedCorners.count >= 3 {
			commitRectangle()
		}
	}

	private func handleCircleTap(at screenPoint: CGPoint) {
		let latLon = viewPort.mapTransform.latLon(forScreenPoint: screenPoint)
		geometryDrawFixedCorners.append(latLon)
		if geometryDrawFixedCorners.count >= 2 {
			commitCircle()
		}
	}

	private func commitRectangle() {
		let fixed = geometryDrawFixedCorners.map { GeometryDrawMath.planePoint(for: $0) }
		guard fixed.count >= 3 else { return }
		let corners = GeometryDrawMath.rectangleCorners(cornerA: fixed[0],
		                                                  cornerB: fixed[1],
		                                                  thirdPointHint: fixed[2])
		let latLons = corners.map { GeometryDrawMath.latLon(for: $0) }
		commitClosedWay(latLons)
	}

	private func commitCircle() {
		let fixed = geometryDrawFixedCorners.map { GeometryDrawMath.planePoint(for: $0) }
		guard fixed.count >= 2 else { return }
		let ring = GeometryDrawMath.circleRing(diameterA: fixed[0], diameterB: fixed[1])
		let latLons = ring.map { GeometryDrawMath.latLon(for: $0) }
		commitClosedWay(latLons)
	}

	private func commitClosedWay(_ corners: [LatLon]) {
		guard !corners.isEmpty else { return }
		let way = mapData.createWay()
		var firstNode: OsmNode?
		for (index, corner) in corners.enumerated() {
			let node = mapData.createNode(atLocation: corner)
			if index == 0 {
				firstNode = node
			}
			do {
				let add = try mapData.canAddNode(to: way, at: index)
				add(node)
			} catch {
				display.showAlert(NSLocalizedString("Can't create shape", comment: ""),
				                  message: error.localizedDescription)
				cancelGeometryDraw()
				return
			}
		}
		if let firstNode {
			do {
				let add = try mapData.canAddNode(to: way, at: corners.count)
				add(firstNode)
			} catch {
				display.showAlert(NSLocalizedString("Can't create shape", comment: ""),
				                  message: error.localizedDescription)
				cancelGeometryDraw()
				return
			}
		}
		selectedWay = way
		selectedNode = nil
		owner.placePushpinForSelection(at: nil)
		setNeedsLayout()
		owner.didUpdateObject()
		cancelGeometryDraw()
		display.flashMessage(title: nil,
		                     message: NSLocalizedString("Shape created", comment: "geometry draw"))
	}

	private func previewPath(forPlanePoints planePoints: [OSMPoint]) -> CGPath {
		let path = CGMutablePath()
		for (index, plane) in planePoints.enumerated() {
			let latLon = GeometryDrawMath.latLon(for: plane)
			let screen = viewPort.mapTransform.screenPoint(forLatLon: latLon, birdsEye: true)
			if index == 0 {
				path.move(to: screen)
			} else {
				path.addLine(to: screen)
			}
		}
		return path
	}

	private func removeGeometryDrawPreview() {
		geometryDrawPreviewLayer?.removeFromSuperlayer()
		geometryDrawPreviewLayer = nil
	}

	private func subscribeGeometryDrawPreview() {
		unsubscribeGeometryDrawPreview()
		viewPort.mapTransform.onChange.subscribe(geometryDrawPreviewToken) { [weak self] in
			self?.updateGeometryDrawPreview()
		}
	}

	private func unsubscribeGeometryDrawPreview() {
		viewPort.mapTransform.onChange.unsubscribe(geometryDrawPreviewToken)
	}
}
