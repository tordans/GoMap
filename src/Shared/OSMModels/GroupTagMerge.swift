//
//  GroupTagMerge.swift
//  Go Map!!
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

import Foundation

/// Pure merge/commit helpers for multi-object tag editing (constraint C2).
enum GroupTagMerge {
	/// Builds the editor working dict from member tag sets.
	///
	/// Keys shared by every member with the same value appear in `shared`. Keys that differ
	/// across members or are absent on some members are listed in `mixedKeys` only — never
	/// as sentinel strings in `shared`, so commit cannot accidentally write placeholders.
	static func merge(memberTags: [[String: String]]) -> (shared: [String: String], mixedKeys: Set<String>) {
		guard let first = memberTags.first else {
			return ([:], [])
		}
		if memberTags.count == 1 {
			return (first, [])
		}

		var shared = [String: String]()
		var mixedKeys = Set<String>()
		let allKeys = Set(memberTags.flatMap { $0.keys })

		for key in allKeys {
			let values = memberTags.map { $0[key] }
			if values.allSatisfy({ $0 != nil }),
			   let firstValue = values[0],
			   values.dropFirst().allSatisfy({ $0 == firstValue })
			{
				shared[key] = firstValue
			} else {
				mixedKeys.insert(key)
			}
		}

		return (shared, mixedKeys)
	}

	/// Applies user edits to one member's tags.
	///
	/// Only keys in `userEditedKeys` are changed (set when non-empty in `editedValues`, removed
	/// when empty or absent). All other keys — including mixed keys the user never edited —
	/// are left untouched so per-member values are never clobbered.
	static func commit(memberTags: [String: String],
	                   editedValues: [String: String],
	                   userEditedKeys: Set<String>) -> [String: String]
	{
		var result = memberTags
		for key in userEditedKeys {
			if let value = editedValues[key], !value.isEmpty {
				result[key] = value
			} else {
				result.removeValue(forKey: key)
			}
		}
		return result
	}
}
