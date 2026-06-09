//
//  OsmNoteMarker.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 9/16/21.
//  Copyright © 2021 Bryce Cogswell. All rights reserved.
//

import Foundation
import KissXML
import UIKit

final class OsmNoteComment {
	let date: String
	let action: String
	let text: String
	let user: String

	init(date: String, action: String, text: String, user: String) {
		self.date = date
		self.action = action
		self.text = text
		self.user = user
	}

	var description: String {
		return "\(action): \(text)"
	}
}

// A regular OSM note
final class OsmNoteMarker: MapMarker {
	private static let recentlyClosedRetention: TimeInterval = 24 * 60 * 60

	static let noteAPIDateFormatter: DateFormatter = {
		let format = DateFormatter()
		format.locale = Locale(identifier: "en_US_POSIX")
		format.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
		format.timeZone = TimeZone(secondsFromGMT: 0)
		return format
	}()

	let status: String // open, closed, etc.
	let noteId: Int64
	let dateCreated: String
	let dateClosed: String?
	private(set) var comments: [OsmNoteComment]

	override var markerIdentifier: String {
		return "note-\(noteId)"
	}

	override var accessibilityLabel: String? {
		if isRecentlyClosed {
			return NSLocalizedString("Recently closed OSM note", comment: "map marker")
		}
		return NSLocalizedString("OSM note", comment: "map marker")
	}

	var isRecentlyClosed: Bool {
		status == "closed" && !shouldHide()
	}

	var isClosed: Bool {
		status == "closed"
	}

	func shouldHide() -> Bool {
		guard status == "closed" else { return false }
		guard let closedDate = dateForClosedStatus() else { return true }
		return Date().timeIntervalSince(closedDate) > Self.recentlyClosedRetention
	}

	static func date(fromNoteDateString string: String) -> Date? {
		if let date = noteAPIDateFormatter.date(from: string) {
			return date
		}
		return OsmBaseObject.rfc3339DateFormatter().date(from: string)
	}

	override var buttonLabel: String { "N" }

	override func makeButton() -> UIButton {
		let button = super.makeButton()
		applyButtonAppearance(to: button)
		return button
	}

	override func reuseButtonFrom(_ other: MapMarker) {
		super.reuseButtonFrom(other)
		if let button = button {
			applyButtonAppearance(to: button)
		}
	}

	override func refreshButtonAppearance() {
		if let button = button {
			applyButtonAppearance(to: button)
		}
	}

	private func dateForClosedStatus() -> Date? {
		if let dateClosed,
		   let date = Self.date(fromNoteDateString: dateClosed)
		{
			return date
		}
		if let closedComment = comments.last(where: { $0.action == "closed" }),
		   let date = Self.date(fromNoteDateString: closedComment.date)
		{
			return date
		}
		return nil
	}

	private func applyButtonAppearance(to button: UIButton) {
		if isRecentlyClosed {
			button.layer.backgroundColor = UIColor.systemGray3.cgColor
			button.alpha = 0.45
		} else {
			button.layer.backgroundColor = UIColor.blue.cgColor
			button.alpha = 1.0
		}
		button.accessibilityLabel = accessibilityLabel
	}

	/// A note newly created by user
	override init(latLon: LatLon) {
		noteId = 0
		status = ""
		dateCreated = ""
		dateClosed = nil
		comments = []

		super.init(latLon: latLon)
	}

	/// Initialize based on OSM Notes query
	init?(noteXml noteElement: DDXMLElement) {
		guard let lat2 = noteElement.attribute(forName: "lat")?.stringValue,
		      let lon2 = noteElement.attribute(forName: "lon")?.stringValue,
		      let lat = Double(lat2),
		      let lon = Double(lon2)
		else { return nil }

		var noteId: Int64?
		var dateCreated: String?
		var dateClosed: String?
		var status: String?
		var comments: [OsmNoteComment] = []
		for child in noteElement.children ?? [] {
			guard let child = child as? DDXMLElement else {
				continue
			}
			if child.name == "id" {
				if let string = child.stringValue,
				   let id = Int64(string)
				{
					noteId = id
				}
			} else if child.name == "date_created" {
				dateCreated = child.stringValue
			} else if child.name == "date_closed" {
				dateClosed = child.stringValue
			} else if child.name == "status" {
				status = child.stringValue
			} else if child.name == "comments" {
				guard let children = child.children as? [DDXMLElement] else { return nil }
				for commentElement in children {
					var date = ""
					var user = ""
					var action = ""
					var text = ""
					for child in commentElement.children ?? [] {
						guard let child = child as? DDXMLElement else {
							continue
						}
						if child.name == "date" {
							date = child.stringValue ?? ""
						} else if child.name == "user" {
							user = child.stringValue ?? ""
						} else if child.name == "action" {
							action = child.stringValue ?? ""
						} else if child.name == "text" {
							text = child.stringValue?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
						}
					}
					let comment = OsmNoteComment(date: date, action: action, text: text, user: user)
					comments.append(comment)
				}
			}
		}
		guard let noteId = noteId,
		      let dateCreated = dateCreated,
		      let status = status
		else { return nil }

		self.noteId = noteId
		self.status = status
		self.dateCreated = dateCreated
		self.dateClosed = dateClosed
		self.comments = comments
		super.init(latLon: LatLon(latitude: lat, longitude: lon))
	}

	override func handleButtonPress(in mainView: MainViewController, markerView: MapMarkersView) {
		mainView.performSegue(withIdentifier: "NotesSegue", sender: self)
	}
}
