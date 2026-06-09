//
//  TrafficSignCatalog.swift
//  Go Map!!
//

import UIKit

/// Keys supported by the traffic-sign value picker.
enum TrafficSignTagKey {
	static let all = ["traffic_sign", "traffic_sign:forward", "traffic_sign:backward"]

	static func isPickerKey(_ key: String) -> Bool {
		all.contains(key)
	}
}

struct TrafficSignEntry: Codable, Equatable {
	let osmValuePart: String
	let signId: String
	let name: String
	let descriptiveName: String
	let kind: String
	let imageName: String
	let isNamedValue: Bool?
	let searchTokens: [String]

	var assetName: String {
		imageName.replacingOccurrences(of: ".svg", with: "")
	}

	var hasIcon: Bool {
		!(isNamedValue ?? false) && !assetName.isEmpty
	}
}

struct TrafficSignCountryCatalog: Codable {
	let entries: [TrafficSignEntry]
	let redirects: [String: String]
	let frequent: [String]
}

private struct TrafficSignIndexFile: Codable {
	let version: Int
	let countries: [String]
	let namedTrafficSignValues: [String]
	let catalogs: [String: TrafficSignCountryCatalog]
}

/// A catalog sign or unrecognized free-text fragment preserved from an existing tag value.
enum TrafficSignSelectionItem: Equatable {
	case catalog(TrafficSignEntry)
	case other(osmValuePart: String, displayLabel: String)

	var osmValuePart: String {
		switch self {
		case let .catalog(entry): return entry.osmValuePart
		case let .other(part, _): return part
		}
	}

	var isCatalog: Bool {
		if case .catalog = self { return true }
		return false
	}
}

final class TrafficSignCatalog {
	static let shared = TrafficSignCatalog()

	private let index: TrafficSignIndexFile
	private let entriesByOsmPart: [String: [String: TrafficSignEntry]]
	private let allEntriesByCountry: [String: [TrafficSignEntry]]

	private init() {
		let url = Bundle.main.url(forResource: "TrafficSignIndex", withExtension: "json")!
		let data = try! Data(contentsOf: url)
		index = try! JSONDecoder().decode(TrafficSignIndexFile.self, from: data)

		var byPart: [String: [String: TrafficSignEntry]] = [:]
		var allByCountry: [String: [TrafficSignEntry]] = [:]
		for (code, catalog) in index.catalogs {
			let upper = code.uppercased()
			var dict: [String: TrafficSignEntry] = [:]
			for entry in catalog.entries {
				dict[entry.osmValuePart] = entry
			}
			byPart[upper] = dict
			allByCountry[upper] = catalog.entries
		}
		entriesByOsmPart = byPart
		allEntriesByCountry = allByCountry
	}

	func hasCatalog(forCountryCode countryCode: String) -> Bool {
		index.catalogs[countryCode.uppercased()] != nil
	}

	func countryCodes() -> [String] {
		index.countries
	}

	func namedValues() -> [String] {
		index.namedTrafficSignValues
	}

	func redirects(for countryCode: String) -> [String: String] {
		index.catalogs[countryCode.uppercased()]?.redirects ?? [:]
	}

	func frequentEntries(for countryCode: String) -> [TrafficSignEntry] {
		guard let catalog = index.catalogs[countryCode.uppercased()] else { return [] }
		return catalog.frequent.compactMap { id in
			catalog.entries.first(where: { $0.osmValuePart == id || $0.signId == id })
		}
	}

	func entry(forOsmValuePart part: String, countryCode: String) -> TrafficSignEntry? {
		entriesByOsmPart[countryCode.uppercased()]?[part]
	}

	func entryMatching(signId: String, signValue: String?, countryCode: String) -> TrafficSignEntry? {
		let entries = allEntriesByCountry[countryCode.uppercased()] ?? []
		let matches = entries.filter { $0.signId == signId }
		if matches.count == 1 {
			return matches[0]
		}
		if matches.count > 1 {
			if let signValue = signValue {
				return matches.first(where: { $0.osmValuePart.contains("[\(signValue)]") })
			}
			return matches.first(where: { !$0.osmValuePart.contains("[") })
		}
		return nil
	}

	func search(query: String, countryCode: String) -> [TrafficSignEntry] {
		guard let catalog = index.catalogs[countryCode.uppercased()] else { return [] }
		let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		if q.isEmpty {
			return frequentEntries(for: countryCode)
		}
		return catalog.entries.filter { entry in
			entry.searchTokens.contains(where: { $0.contains(q) })
				|| entry.osmValuePart.lowercased().contains(q)
				|| entry.descriptiveName.lowercased().contains(q)
				|| entry.signId.lowercased().contains(q)
		}
	}

	func image(for entry: TrafficSignEntry) -> UIImage? {
		guard entry.hasIcon else { return nil }
		return UIImage(named: entry.assetName)
	}

	func decompose(tagValue: String, countryCode: String) -> [TrafficSignSelectionItem] {
		TrafficSignComposer.decompose(tagValue: tagValue, countryCode: countryCode, catalog: self)
	}

	func compose(selection: [TrafficSignSelectionItem], countryCode: String) -> String {
		TrafficSignComposer.compose(selection: selection, countryCode: countryCode, catalog: self)
	}

	/// Split a tag value into display components for map overlay (catalog icons + text for unknown parts).
	func displayComponents(forTagValue tagValue: String, countryCode: String) -> [TrafficSignDisplayComponent] {
		decompose(tagValue: tagValue, countryCode: countryCode).map { item in
			switch item {
			case let .catalog(entry):
				return .image(assetName: entry.assetName, label: entry.descriptiveName)
			case let .other(part, label):
				return .other(label: label.isEmpty ? part : label)
			}
		}
	}
}

enum TrafficSignDisplayComponent {
	case image(assetName: String, label: String)
	case other(label: String)
}
