//
//  GroupTagMergeTestCase.swift
//  GoMapTests
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

@testable import Go_Map__
import XCTest

class GroupTagMergeTestCase: XCTestCase {
	func testMerge_allMembersShareSameValue_putsKeyInShared() {
		/// Given
		let members = [
			["amenity": "cafe", "name": "A"],
			["amenity": "cafe", "name": "A"]
		]

		/// When
		let result = GroupTagMerge.merge(memberTags: members)

		/// Then
		XCTAssertEqual(result.shared, ["amenity": "cafe", "name": "A"])
		XCTAssertTrue(result.mixedKeys.isEmpty)
	}

	func testMerge_differingValues_marksKeyMixedNotInShared() {
		/// Given
		let members = [
			["name": "Shop A"],
			["name": "Shop B"]
		]

		/// When
		let result = GroupTagMerge.merge(memberTags: members)

		/// Then
		XCTAssertNil(result.shared["name"])
		XCTAssertEqual(result.mixedKeys, ["name"])
	}

	func testMerge_absentOnSomeMembers_marksKeyMixed() {
		/// Given
		let members = [
			["opening_hours": "Mo-Fr"],
			[:]
		]

		/// When
		let result = GroupTagMerge.merge(memberTags: members)

		/// Then
		XCTAssertNil(result.shared["opening_hours"])
		XCTAssertEqual(result.mixedKeys, ["opening_hours"])
	}

	func testMerge_emptyMemberTags_returnsEmptyResult() {
		/// Given
		let members: [[String: String]] = []

		/// When
		let result = GroupTagMerge.merge(memberTags: members)

		/// Then
		XCTAssertTrue(result.shared.isEmpty)
		XCTAssertTrue(result.mixedKeys.isEmpty)
	}

	func testMerge_singleMember_returnsAllTagsSharedWithNoMixed() {
		/// Given
		let members = [["shop": "bakery", "name": "Only"]]

		/// When
		let result = GroupTagMerge.merge(memberTags: members)

		/// Then
		XCTAssertEqual(result.shared, ["shop": "bakery", "name": "Only"])
		XCTAssertTrue(result.mixedKeys.isEmpty)
	}

	func testCommit_noUserEditedKeys_returnsIdenticalTags() {
		/// Given
		let memberTags = ["shop": "bakery", "name": "Local"]

		/// When
		let result = GroupTagMerge.commit(
			memberTags: memberTags,
			editedValues: ["shop": "cafe"],
			userEditedKeys: [])

		/// Then
		XCTAssertEqual(result, memberTags)
	}

	func testCommit_editedSharedKey_appliedToMember() {
		/// Given
		let memberTags = ["amenity": "cafe", "name": "A"]

		/// When
		let result = GroupTagMerge.commit(
			memberTags: memberTags,
			editedValues: ["amenity": "restaurant"],
			userEditedKeys: ["amenity"])

		/// Then
		XCTAssertEqual(result["amenity"], "restaurant")
		XCTAssertEqual(result["name"], "A")
	}

	func testCommit_uneditedMixedKey_leavesMemberValueUntouched() {
		/// Given
		let memberTags = ["name": "Shop A", "shop": "bakery"]

		/// When
		let result = GroupTagMerge.commit(
			memberTags: memberTags,
			editedValues: ["name": "Unified"],
			userEditedKeys: ["shop"])

		/// Then
		XCTAssertEqual(result["name"], "Shop A")
		XCTAssertEqual(result["shop"], "bakery")
	}

	func testCommit_emptyEditedValue_removesKey() {
		/// Given
		let memberTags = ["note": "old", "shop": "bakery"]

		/// When
		let result = GroupTagMerge.commit(
			memberTags: memberTags,
			editedValues: ["note": ""],
			userEditedKeys: ["note"])

		/// Then
		XCTAssertNil(result["note"])
		XCTAssertEqual(result["shop"], "bakery")
	}

	func testCommit_preservesPerMemberUniqueTagsWhenEditingSharedKey() {
		/// Given
		let memberATags = ["amenity": "cafe", "name": "Cafe A"]
		let memberBTags = ["amenity": "cafe", "name": "Cafe B"]

		/// When
		let resultA = GroupTagMerge.commit(
			memberTags: memberATags,
			editedValues: ["amenity": "restaurant"],
			userEditedKeys: ["amenity"])
		let resultB = GroupTagMerge.commit(
			memberTags: memberBTags,
			editedValues: ["amenity": "restaurant"],
			userEditedKeys: ["amenity"])

		/// Then
		XCTAssertEqual(resultA["amenity"], "restaurant")
		XCTAssertEqual(resultA["name"], "Cafe A")
		XCTAssertEqual(resultB["amenity"], "restaurant")
		XCTAssertEqual(resultB["name"], "Cafe B")
	}

	func testCommit_keyAddedByEditThatNoMemberHad() {
		/// Given
		let memberTags = ["shop": "bakery"]

		/// When
		let result = GroupTagMerge.commit(
			memberTags: memberTags,
			editedValues: ["wheelchair": "yes"],
			userEditedKeys: ["wheelchair"])

		/// Then
		XCTAssertEqual(result["wheelchair"], "yes")
		XCTAssertEqual(result["shop"], "bakery")
	}
}
