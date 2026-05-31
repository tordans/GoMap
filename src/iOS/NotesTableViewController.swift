//
//  NotesTableViewController.swift
//  Go Map!!
//
//  Created by Bryce Cogswell on 11/4/14.
//  Copyright (c) 2014 Bryce Cogswell. All rights reserved.
//

import MapKit
import SafariServices
import UIKit

class NotesOldCommentCell: UITableViewCell {
	@IBOutlet var date: UILabel!
	@IBOutlet var user: UIButton!
	@IBOutlet var action: UILabel!
	@IBOutlet var comment: UITextView!
	@IBOutlet var commentBackground: UIView!
}

class NotesNewCommentCell: UITableViewCell {
	@IBOutlet var textView: UITextView!
	@IBOutlet var commentButton: UIButton!
	@IBOutlet var resolveButton: UIButton!
}

class NotesTableViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {
	var newComment: String?

	@IBOutlet var tableView: UITableView!
	var note: OsmNoteMarker!
	var mapView: MapView!

	private enum UpdateSectionRow: Int, CaseIterable {
		case comment = 0
		case shareLink
		case directions
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let shareButton = UIBarButtonItem(barButtonSystemItem: .action,
		                                  target: self,
		                                  action: #selector(shareTapped(_:)))
		navigationItem.rightBarButtonItem = shareButton
		updateShareButton()

		tableView.estimatedRowHeight = 100
		tableView.rowHeight = UITableView.automaticDimension

		// add extra space at bottom so keyboard doesn't cover elements
		var rc = tableView.contentInset
		rc.bottom += 70
		tableView.contentInset = rc
	}

	func stylePrimaryActionButton(_ button: UIButton) {
		let title = button.title(for: .normal)
		if #available(iOS 26.0, *) {
			var config = UIButton.Configuration.prominentGlass()
			config.cornerStyle = .capsule
			config.title = title
			button.configuration = config
		} else if #available(iOS 15.0, *) {
			var config = UIButton.Configuration.filled()
			config.cornerStyle = .medium
			config.title = title
			button.configuration = config
		} else {
			button.layer.cornerRadius = 10
			button.clipsToBounds = true
			button.backgroundColor = button.isEnabled ? .systemBlue : .systemGray3
			button.setTitleColor(.white, for: .normal)
		}
	}

	func configureNewCommentCell(_ cell: NotesNewCommentCell) {
		stylePrimaryActionButton(cell.commentButton)
		stylePrimaryActionButton(cell.resolveButton)
		cell.commentButton.constraints.first(where: { $0.firstAttribute == .height })?.constant = 44
		cell.resolveButton.constraints.first(where: { $0.firstAttribute == .height })?.constant = 44
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
	}

	var canShareNoteLink: Bool {
		note.noteId > 0
	}

	func updateShareButton() {
		navigationItem.rightBarButtonItem?.isEnabled = canShareNoteLink
	}

	// MARK: - Table view data source

	func numberOfSections(in tableView: UITableView) -> Int {
		return note.comments.count > 0 ? 2 : 1
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if note.comments.count > 0, section == 0 {
			return NSLocalizedString("Note History", comment: "OSM note")
		} else {
			return NSLocalizedString("Update", comment: "update an osm note")
		}
	}

	func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		if section == 1 {
			return "\n\n\n\n\n\n\n\n\n"
		}
		return nil
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0, note.comments.count > 0 {
			return note.comments.count
		}
		return UpdateSectionRow.allCases.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == 0, note.comments.count > 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "noteCommentCell",
			                                         for: indexPath) as! NotesOldCommentCell
			let comment = note.comments[indexPath.row]
			let isAnonymous = comment.user == ""
			let user = isAnonymous ? "anonymous" : comment.user
			cell.date.text = comment.date
			cell.user.setTitle(user, for: .normal)
			cell.action.text = comment.action
			cell.user.isEnabled = !isAnonymous
			if comment.text.count == 0 {
				cell.commentBackground.isHidden = true
				cell.comment.text = nil
			} else {
				cell.commentBackground.isHidden = false
				cell.commentBackground.layer.cornerRadius = 5
				cell.commentBackground.layer.borderColor = cell.comment.textColor?.cgColor ?? UIColor.black.cgColor
				cell.commentBackground.layer.borderWidth = 1.0
				cell.commentBackground.layer.masksToBounds = true
				cell.comment.text = comment.text
			}
			return cell
		} else if indexPath.row == UpdateSectionRow.comment.rawValue {
			let cell = tableView.dequeueReusableCell(withIdentifier: "noteResolveCell",
			                                         for: indexPath) as! NotesNewCommentCell
			cell.textView.layer.cornerRadius = 5.0
			cell.textView.layer.borderColor = cell.textView.textColor?.cgColor ?? UIColor.black.cgColor
			cell.textView.layer.borderWidth = 1.0
			cell.textView.delegate = self
			cell.textView.text = newComment
			if note.comments.count == 0 {
				// brand new note
				cell.resolveButton.isHidden = true
				cell.commentButton.isEnabled = true
			} else {
				cell.resolveButton.isHidden = false
				cell.commentButton.isEnabled = false
			}
			configureNewCommentCell(cell)
			return cell
		} else if indexPath.row == UpdateSectionRow.shareLink.rawValue {
			let cell = tableView.dequeueReusableCell(withIdentifier: "noteShareCell")
				?? UITableViewCell(style: .default, reuseIdentifier: "noteShareCell")
			cell.textLabel?.text = NSLocalizedString("Open on openstreetmap.org",
			                                          comment: "share an OSM note link")
			cell.textLabel?.textAlignment = .center
			cell.textLabel?.textColor = .link
			cell.selectionStyle = canShareNoteLink ? .default : .none
			cell.isUserInteractionEnabled = canShareNoteLink
			cell.textLabel?.alpha = canShareNoteLink ? 1.0 : 0.4
			return cell
		} else {
			let cell = tableView.dequeueReusableCell(
				withIdentifier: "noteDirectionsCell",
				for: indexPath) as UITableViewCell
			return cell
		}
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		view.endEditing(true)

		if indexPath.section == 0, note.comments.count > 0 {
		} else if indexPath.row == UpdateSectionRow.comment.rawValue {
		} else if indexPath.row == UpdateSectionRow.shareLink.rawValue {
			if let cell = tableView.cellForRow(at: indexPath) {
				presentShareSheet(from: cell)
			}
			tableView.deselectRow(at: indexPath, animated: true)
		} else {
			// open note location using Apple Maps and get directions there
			let coordinate = CLLocationCoordinate2DMake(self.note.latLon.lat, self.note.latLon.lon)
			let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: nil)
			let note = MKMapItem(placemark: placemark)
			note.name = "OSM Note"
			let current = MKMapItem.forCurrentLocation()
			let options = [
				MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
			]
			MKMapItem.openMaps(with: [current, note], launchOptions: options)
		}
	}

	func newComment(_ text: String, resolves: Bool) {
		view.endEditing(true)

		let text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
		let alert = UIAlertController(
			title: NSLocalizedString("Updating Note...", comment: "OSM Note"),
			message: nil,
			preferredStyle: .alert)
		present(alert, animated: true)

		// if user created a note then make sure notes are visible
		let mainView = AppDelegate.shared.mainView!
		let mapMarkersView = mainView.mapLayersView.mapMarkersView!
		mainView.viewState.overlayMask.insert(.NOTES)
		mainView.updateMapMarkers(including: [.notes])

		Task { @MainActor in
			do {
				let newNote = try await mapMarkersView.upload(note: note, close: resolves, comment: text)
				alert.dismiss(animated: true, completion: {
					self.done(nil) // dismiss ourself after alert is dismissed
				})

				note = newNote
				updateShareButton()

				// remove note markers that are now resolved
				mapMarkersView.removeMarkers(where: { ($0 as? OsmNoteMarker)?.shouldHide() ?? false })
				mapMarkersView.updateMapMarkerButtonPositions()
			} catch {
				alert.dismiss(animated: true)

				let alert2 = UIAlertController(title: NSLocalizedString("Error", comment: ""),
				                               message: error.localizedDescription,
				                               preferredStyle: .alert)
				alert2.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
				                               style: .cancel,
				                               handler: nil))
				present(alert2, animated: true)
			}
		}
	}

	@IBAction func doComment(_ sender: Any) {
		guard let cell: NotesNewCommentCell = (sender as? UIView)?.superviewOfType() else { return }
		let text = cell.textView.text ?? ""
		newComment(text, resolves: false)
	}

	@IBAction func doResolve(_ sender: Any) {
		guard let cell: NotesNewCommentCell = (sender as? UIView)?.superviewOfType() else { return }
		let text = cell.textView.text ?? ""
		newComment(text, resolves: true)
	}

	func textViewDidChange(_ textView: UITextView) {
		if let cell: NotesNewCommentCell = textView.superviewOfType() {
			newComment = cell.textView.text
			let s = newComment?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
			cell.commentButton.isEnabled = (s?.count ?? 0) > 0
			if #unavailable(iOS 15.0) {
				cell.commentButton.backgroundColor = cell.commentButton.isEnabled ? .systemBlue : .systemGray3
			}
		}
	}

	@IBAction func showUser(_ sender: Any?) {
		guard let cell: NotesOldCommentCell = (sender as? UIButton)?.superviewOfType(),
		      let name = cell.user.titleLabel?.text,
		      let url = URL(string: "\(OSM_SERVER.serverURL)user/\(name)")
		else {
			return
		}
		let safariViewController = SFSafariViewController(url: url)
		safariViewController.modalPresentationStyle = .pageSheet
		safariViewController.popoverPresentationController?.sourceView = view
		present(safariViewController, animated: true)
	}

	@IBAction func shareTapped(_ sender: Any?) {
		if let barButton = sender as? UIBarButtonItem {
			presentShareSheet(from: barButton)
		} else {
			presentShareSheet(from: navigationItem.rightBarButtonItem)
		}
	}

	func presentShareSheet(from source: Any?) {
		guard canShareNoteLink else { return }
		let url = OSM_SERVER.serverURL.appendingPathComponent("note/\(note.noteId)")
		let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
		if let barButton = source as? UIBarButtonItem {
			activityVC.popoverPresentationController?.barButtonItem = barButton
		} else if let view = source as? UIView {
			activityVC.popoverPresentationController?.sourceView = view
			activityVC.popoverPresentationController?.sourceRect = view.bounds
		}
		present(activityVC, animated: true)
	}

	@IBAction func done(_ sender: Any?) {
		if let nav = self.navigationController {
			nav.dismiss(animated: true)
		} else {
			dismiss(animated: true)
		}
	}
}
