//
//  TrafficSignOverlayLayer.swift
//  Go Map!!
//

import UIKit

/// Draws compact chains of traffic-sign icons on nodes and ways when enabled in display settings.
final class TrafficSignOverlayLayer: CALayer {
	private weak var viewPort: MapViewPort?
	private weak var mapData: OsmMapData?
	private let catalog = TrafficSignCatalog.shared
	private let iconSize: CGFloat = 14
	private let iconOverlap: CGFloat = 8

	init(viewPort: MapViewPort, mapData: OsmMapData) {
		self.viewPort = viewPort
		self.mapData = mapData
		super.init()
		zPosition = ZLAYER.DATA.rawValue + 0.5
	}

	override init(layer: Any) {
		let other = layer as! TrafficSignOverlayLayer
		viewPort = other.viewPort
		mapData = other.mapData
		super.init(layer: layer)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	func refresh() {
		guard let viewPort = viewPort, let mapData = mapData else { return }
		let country = AppDelegate.shared.mainView.currentRegion.country.uppercased()
		guard catalog.hasCatalog(forCountryCode: country) else {
			sublayers = nil
			return
		}

		let rect = viewPort.boundingLatLonForScreen()
		var newLayers: [CALayer] = []

		mapData.enumerateObjects(inRegion: rect) { obj in
			if let node = obj as? OsmNode {
				self.addChains(for: node, country: country, viewPort: viewPort, into: &newLayers)
			} else if let way = obj as? OsmWay {
				self.addChains(for: way, country: country, viewPort: viewPort, into: &newLayers)
			}
		}

		sublayers = newLayers
	}

	private func addChains(for node: OsmNode,
	                       country: String,
	                       viewPort: MapViewPort,
	                       into layers: inout [CALayer])
	{
		let tags = node.tags
		let pt = MapTransform.mapPoint(forLatLon: node.latLon)
		let screen = viewPort.mapTransform.screenPoint(forMapPoint: pt, birdsEye: true)

		if let value = tags["traffic_sign"], !value.isEmpty {
			addBeadChain(components: catalog.displayComponents(forTagValue: value, countryCode: country),
			             at: screen,
			             angle: 0,
			             into: &layers)
		}
		for (key, angleOffset) in [("traffic_sign:forward", 0.0), ("traffic_sign:backward", .pi)] {
			if let value = tags[key], !value.isEmpty {
				addBeadChain(components: catalog.displayComponents(forTagValue: value, countryCode: country),
				             at: CGPoint(x: screen.x, y: screen.y + (key == "traffic_sign:forward" ? -6 : 6)),
				             angle: angleOffset,
				             into: &layers)
			}
		}
	}

	private func addChains(for way: OsmWay,
	                       country: String,
	                       viewPort: MapViewPort,
	                       into layers: inout [CALayer])
	{
		guard way.nodes.count >= 2 else { return }
		let tags = way.tags

		let forwardValue = tags["traffic_sign:forward"]
		let backwardValue = tags["traffic_sign:backward"]
		let genericValue = tags["traffic_sign"]
		let hasForward = !(forwardValue?.isEmpty ?? true)
		let hasBackward = !(backwardValue?.isEmpty ?? true)

		if hasForward {
			addChainAlongWay(way, value: forwardValue!, country: country, viewPort: viewPort, reversed: false, into: &layers)
		} else if !hasBackward, let genericValue, !genericValue.isEmpty {
			addChainAlongWay(way, value: genericValue, country: country, viewPort: viewPort, reversed: false, into: &layers)
		}

		if hasBackward {
			addChainAlongWay(way, value: backwardValue!, country: country, viewPort: viewPort, reversed: true, into: &layers)
		} else if !hasForward, let genericValue, !genericValue.isEmpty {
			addChainAlongWay(way, value: genericValue, country: country, viewPort: viewPort, reversed: true, into: &layers)
		}
	}

	private func addChainAlongWay(_ way: OsmWay,
	                              value: String,
	                              country: String,
	                              viewPort: MapViewPort,
	                              reversed: Bool,
	                              into layers: inout [CALayer])
	{
		let components = catalog.displayComponents(forTagValue: value, countryCode: country)
		guard !components.isEmpty else { return }

		let nodes = reversed ? Array(way.nodes.reversed()) : way.nodes
		guard nodes.count >= 2,
		      let midIndex = nodes.indices.dropFirst().dropLast().first
		else {
			if let node = nodes.first {
				let pt = viewPort.mapTransform.screenPoint(forLatLon: node.latLon, birdsEye: true)
				addBeadChain(components: components, at: pt, angle: 0, into: &layers)
			}
			return
		}

		let a = MapTransform.mapPoint(forLatLon: nodes[midIndex - 1].latLon)
		let b = MapTransform.mapPoint(forLatLon: nodes[midIndex].latLon)
		let midMap = OSMPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
		let midLatLon = MapTransform.latLon(forMapPoint: midMap)
		let screen = viewPort.mapTransform.screenPoint(forLatLon: midLatLon, birdsEye: true)
		let angle = atan2(b.y - a.y, b.x - a.x)
		addBeadChain(components: components, at: screen, angle: CGFloat(angle), into: &layers)
	}

	private func addBeadChain(components: [TrafficSignDisplayComponent],
	                          at center: CGPoint,
	                          angle: CGFloat,
	                          into layers: inout [CALayer])
	{
		let count = components.count
		guard count > 0 else { return }
		let totalWidth = iconSize + CGFloat(max(0, count - 1)) * iconOverlap
		var x = center.x - totalWidth / 2

		for component in components {
			let layer = CALayer()
			layer.bounds = CGRect(x: 0, y: 0, width: iconSize, height: iconSize)
			layer.position = CGPoint(x: x + iconSize / 2, y: center.y)
			layer.cornerRadius = 2
			layer.backgroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
			layer.borderColor = UIColor.darkGray.cgColor
			layer.borderWidth = 0.5

			switch component {
			case let .image(assetName, _):
				layer.contents = UIImage(named: assetName)?.cgImage
			case let .other(label):
				layer.contents = placeholderImage(label: label).cgImage
			}

			if angle != 0 {
				layer.setAffineTransform(CGAffineTransform(rotationAngle: angle))
			}
			layers.append(layer)
			x += iconOverlap
		}
	}

	private func placeholderImage(label: String) -> UIImage {
		let size = CGSize(width: iconSize, height: iconSize)
		return UIGraphicsImageRenderer(size: size).image { ctx in
			UIColor.systemGray.setFill()
			ctx.fill(CGRect(origin: .zero, size: size))
			let text = String(label.prefix(2))
			let attrs: [NSAttributedString.Key: Any] = [
				.font: UIFont.systemFont(ofSize: 7, weight: .bold),
				.foregroundColor: UIColor.white,
			]
			let ts = text.size(withAttributes: attrs)
			text.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2), withAttributes: attrs)
		}
	}
}

extension TrafficSignOverlayLayer: MapLayersView.LayerOrView {
	var hasTileServer: TileServer? { nil }

	func removeFromSuper() {
		removeFromSuperlayer()
	}
}
