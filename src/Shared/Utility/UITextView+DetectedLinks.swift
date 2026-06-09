//
//  UITextView+DetectedLinks.swift
//  Go Map!!
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

import UIKit

extension UITextView {
	/// Read-only text with tappable `http`/`https` links (e.g. note comments, alert messages).
	func configureForDetectedLinks(text: String, delegate: UITextViewDelegate? = nil) {
		self.delegate = delegate
		isEditable = false
		isSelectable = true
		isScrollEnabled = false
		isUserInteractionEnabled = true
		dataDetectorTypes = [.link]
		linkTextAttributes = [.foregroundColor: UIColor.link]
		textContainer.lineFragmentPadding = 0
		textContainerInset = .zero
		self.text = text
	}

	func clearDetectedLinks() {
		delegate = nil
		dataDetectorTypes = []
		text = nil
	}
}
