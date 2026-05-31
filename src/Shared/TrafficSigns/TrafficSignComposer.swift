//
//  TrafficSignComposer.swift
//  Go Map!!
//
//  Offline compose/decompose for traffic_sign values, matching @osm-traffic-signs/converter rules.
//

import Foundation

enum TrafficSignComposer {
	static func compose(selection: [TrafficSignSelectionItem],
	                    countryCode: String,
	                    catalog: TrafficSignCatalog) -> String
	{
		let cc = countryCode.uppercased()
		guard !cc.isEmpty, !selection.isEmpty else { return "" }

		let named = Set(catalog.namedValues())
		var countryPrefixSet = false
		var parts: [String] = []

		for (index, item) in selection.enumerated() {
			let osmPart = item.osmValuePart
			let isNamed = named.contains(osmPart)
			var countryPrefixString = ""
			if !countryPrefixSet, !isNamed {
				countryPrefixString = "\(cc):"
				countryPrefixSet = true
			}

			let kind: String = {
				if case let .catalog(entry) = item { return entry.kind }
				return "traffic_sign"
			}()

			let isFirst = index == 0
			let prevNamed = index > 0 && named.contains(selection[index - 1].osmValuePart)
			let separator = isFirst ? "" : (kind == "traffic_sign" || prevNamed ? ";" : ",")
			parts.append("\(separator)\(countryPrefixString)\(osmPart)")
		}
		return parts.joined()
	}

	static func decompose(tagValue: String,
	                      countryCode: String,
	                      catalog: TrafficSignCatalog) -> [TrafficSignSelectionItem]
	{
		let cc = countryCode.uppercased()
		guard !cc.isEmpty, !tagValue.isEmpty else { return [] }

		var cleaned = removeKeys(from: tagValue)
		cleaned = removeCountryPrefix(from: cleaned, countryPrefix: cc)
		let redirects = catalog.redirects(for: countryCode)
		let lowerRedirects = Dictionary(uniqueKeysWithValues: redirects.map { ($0.key.lowercased(), $0.value) })

		let valueParts = splitIntoSignValueParts(cleaned).map { part -> String in
			lowerRedirects[part.lowercased()] ?? part
		}

		return valueParts.map { part in
			if let entry = catalog.entry(forOsmValuePart: part, countryCode: cc) {
				return .catalog(entry)
			}
			let (signId, signValue) = splitSignIdSignValue(part)
			if let entry = catalog.entryMatching(signId: signId, signValue: signValue, countryCode: cc) {
				return .catalog(entry)
			}
			let display = part.hasPrefix("\""), part.hasSuffix("\"") ? String(part.dropFirst().dropLast()) : part
			return .other(osmValuePart: part, displayLabel: display)
		}
	}

	// MARK: - Parsing helpers (ported from @osm-traffic-signs/converter)

	private static func splitIntoSignValueParts(_ input: String) -> [String] {
		var result: [String] = []
		var current = ""
		var bracketDepth = 0
		var inQuotes = false
		for char in input {
			if char == "\"" {
				inQuotes.toggle()
				current.append(char)
			} else if !inQuotes, char == "[" {
				bracketDepth += 1
				current.append(char)
			} else if !inQuotes, char == "]" {
				bracketDepth = max(0, bracketDepth - 1)
				current.append(char)
			} else if !inQuotes, bracketDepth == 0, char == "," || char == ";" {
				let trimmed = current.trimmingCharacters(in: .whitespaces)
				if !trimmed.isEmpty { result.append(trimmed) }
				current = ""
			} else {
				current.append(char)
			}
		}
		let trimmed = current.trimmingCharacters(in: .whitespaces)
		if !trimmed.isEmpty { result.append(trimmed) }
		return result
	}

	private static func removeCountryPrefix(from input: String, countryPrefix: String) -> String {
		input
			.replacingOccurrences(of: "\(countryPrefix):", with: "")
			.replacingOccurrences(of: "\(countryPrefix.lowercased()):", with: "")
	}

	private static func removeKeys(from input: String) -> String {
		let split = input.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
		guard split.count >= 2 else { return input }
		let likelyTag = String(split[0])
		if likelyTag.contains("traffic_sign") {
			return split.dropFirst().joined(separator: "=")
		}
		return input
	}

	private static func splitSignIdSignValue(_ urlKey: String) -> (signId: String, signValue: String?) {
		if urlKey.hasPrefix("\""), urlKey.hasSuffix("\"") {
			return (urlKey, nil)
		}
		let parts = urlKey.split(separator: "[", maxSplits: 1, omittingEmptySubsequences: false)
		let signId = String(parts[0])
		if parts.count < 2 {
			return (signId, nil)
		}
		var bracket = String(parts[1])
		if bracket.hasSuffix("]") {
			bracket.removeLast()
		}
		return (signId, bracket.isEmpty ? nil : bracket)
	}
}
