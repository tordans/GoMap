//
//  GroupSelectionBar.swift
//  Go Map!!
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

import UIKit

final class GroupSelectionBar: UIView {
	var onTapMember: (OsmBaseObject) -> Void = { _ in }
	var onRemoveMember: (OsmBaseObject) -> Void = { _ in }
	var onToggleAddMode: (_ longPress: Bool) -> Void = { _ in }
	var onClose: () -> Void = {}

	private let backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
	private let scrollView = UIScrollView()
	private let chipStack = UIStackView()
	private let addButton = UIButton(type: .system)
	private let closeButton = UIButton(type: .system)
	private let addButtonLongPress = UILongPressGestureRecognizer()

	override init(frame: CGRect) {
		super.init(frame: frame)
		setUp()
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func setUp() {
		translatesAutoresizingMaskIntoConstraints = false
		isHidden = true
		layer.cornerRadius = 10
		layer.masksToBounds = false
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOpacity = 0.15
		layer.shadowRadius = 4
		layer.shadowOffset = CGSize(width: 0, height: 2)

		backgroundView.translatesAutoresizingMaskIntoConstraints = false
		backgroundView.layer.cornerRadius = 10
		backgroundView.clipsToBounds = true
		addSubview(backgroundView)

		scrollView.translatesAutoresizingMaskIntoConstraints = false
		scrollView.showsHorizontalScrollIndicator = false
		scrollView.alwaysBounceHorizontal = true
		backgroundView.contentView.addSubview(scrollView)

		chipStack.translatesAutoresizingMaskIntoConstraints = false
		chipStack.axis = .horizontal
		chipStack.spacing = 6
		chipStack.alignment = .center
		scrollView.addSubview(chipStack)

		addButton.translatesAutoresizingMaskIntoConstraints = false
		addButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
		addButton.accessibilityLabel = NSLocalizedString("Add object to group",
		                                                 comment: "Accessibility label for group bar add button")
		addButton.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
		backgroundView.contentView.addSubview(addButton)

		addButtonLongPress.minimumPressDuration = 0.5
		addButtonLongPress.addTarget(self, action: #selector(addLongPressed(_:)))
		addButton.addGestureRecognizer(addButtonLongPress)

		closeButton.translatesAutoresizingMaskIntoConstraints = false
		closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
		closeButton.tintColor = .secondaryLabel
		closeButton.accessibilityLabel = NSLocalizedString("Dismiss group",
		                                                   comment: "Accessibility label for group bar close button")
		closeButton.accessibilityHint = NSLocalizedString("Clears the group and selection. Tap empty map space to dismiss as well.",
		                                                  comment: "Accessibility hint for dismissing an object group")
		closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
		backgroundView.contentView.addSubview(closeButton)

		NSLayoutConstraint.activate([
			backgroundView.topAnchor.constraint(equalTo: topAnchor),
			backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
			backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
			backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

			closeButton.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor, constant: -6),
			closeButton.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
			closeButton.widthAnchor.constraint(equalToConstant: 32),
			closeButton.heightAnchor.constraint(equalToConstant: 32),

			addButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
			addButton.centerYAnchor.constraint(equalTo: backgroundView.contentView.centerYAnchor),
			addButton.widthAnchor.constraint(equalToConstant: 32),
			addButton.heightAnchor.constraint(equalToConstant: 32),

			scrollView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor, constant: 8),
			scrollView.trailingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: -6),
			scrollView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor, constant: 4),
			scrollView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor, constant: -4),

			chipStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
			chipStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
			chipStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
			chipStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
			chipStack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
		])
	}

	func update(members: [OsmBaseObject],
	            anchor: OsmBaseObject?,
	            addMode: EditorMapLayer.GroupAddMode)
	{
		chipStack.arrangedSubviews.forEach { view in
			chipStack.removeArrangedSubview(view)
			view.removeFromSuperview()
		}

		for member in members {
			chipStack.addArrangedSubview(chipView(for: member, isAnchor: member === anchor))
		}

		switch addMode {
		case .off:
			addButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
			addButton.backgroundColor = .clear
			addButton.tintColor = tintColor
		case .armed:
			addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
			addButton.backgroundColor = .clear
			addButton.tintColor = .systemBlue
		case .batch:
			addButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
			addButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
			addButton.tintColor = .systemBlue
			addButton.layer.cornerRadius = 8
		}
	}

	private func chipView(for member: OsmBaseObject, isAnchor: Bool) -> UIView {
		let memberRef = member
		let container = UIView()
		container.translatesAutoresizingMaskIntoConstraints = false
		container.layer.cornerRadius = 8
		container.layer.borderWidth = isAnchor ? 2 : 1
		container.layer.borderColor = (isAnchor ? UIColor.systemBlue : UIColor.separator).cgColor
		container.backgroundColor = UIColor.secondarySystemBackground

		let bodyButton = ButtonClosure(type: .custom)
		bodyButton.translatesAutoresizingMaskIntoConstraints = false
		bodyButton.backgroundColor = .clear
		bodyButton.onTap = { [weak self] _ in
			self?.onTapMember(memberRef)
		}
		bodyButton.accessibilityLabel = member.friendlyDescription()
		bodyButton.accessibilityHint = NSLocalizedString("Double tap to make this the anchor",
		                                                 comment: "Accessibility hint for a group member chip")
		container.addSubview(bodyButton)

		let symbolName: String
		if member is OsmNode {
			symbolName = "circle.fill"
		} else if member is OsmWay {
			symbolName = "line.diagonal"
		} else {
			symbolName = "square.grid.2x2"
		}

		let icon = UIImageView(image: UIImage(systemName: symbolName))
		icon.translatesAutoresizingMaskIntoConstraints = false
		icon.tintColor = .secondaryLabel
		icon.setContentHuggingPriority(.required, for: .horizontal)
		icon.setContentCompressionResistancePriority(.required, for: .horizontal)

		let label = UILabel()
		label.translatesAutoresizingMaskIntoConstraints = false
		label.font = UIFont.preferredFont(forTextStyle: .caption1)
		label.textColor = .label
		label.lineBreakMode = .byTruncatingTail
		var title = member.friendlyDescription()
		if title.count > 24 {
			title = String(title.prefix(21)) + "..."
		}
		label.text = title

		let remove = ButtonClosure(type: .system)
		remove.translatesAutoresizingMaskIntoConstraints = false
		remove.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
		remove.tintColor = .tertiaryLabel
		remove.accessibilityLabel = NSLocalizedString("Remove from group",
		                                              comment: "Accessibility label for removing a member from the group bar")
		remove.onTap = { [weak self] _ in
			self?.onRemoveMember(memberRef)
		}

		let row = UIStackView(arrangedSubviews: [icon, label])
		row.translatesAutoresizingMaskIntoConstraints = false
		row.axis = .horizontal
		row.spacing = 4
		row.alignment = .center
		row.isUserInteractionEnabled = false
		bodyButton.addSubview(row)
		container.addSubview(remove)

		NSLayoutConstraint.activate([
			bodyButton.topAnchor.constraint(equalTo: container.topAnchor),
			bodyButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
			bodyButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
			bodyButton.trailingAnchor.constraint(equalTo: remove.leadingAnchor),

			icon.widthAnchor.constraint(equalToConstant: 12),
			icon.heightAnchor.constraint(equalToConstant: 12),
			remove.widthAnchor.constraint(equalToConstant: 22),
			remove.heightAnchor.constraint(equalToConstant: 22),
			row.leadingAnchor.constraint(equalTo: bodyButton.leadingAnchor, constant: 6),
			row.trailingAnchor.constraint(equalTo: bodyButton.trailingAnchor, constant: -4),
			row.topAnchor.constraint(equalTo: bodyButton.topAnchor, constant: 4),
			row.bottomAnchor.constraint(equalTo: bodyButton.bottomAnchor, constant: -4),
			remove.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
			remove.centerYAnchor.constraint(equalTo: container.centerYAnchor),
			container.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
		])

		return container
	}

	@objc private func addTapped() {
		onToggleAddMode(false)
	}

	@objc private func addLongPressed(_ gesture: UILongPressGestureRecognizer) {
		guard gesture.state == .began else {
			return
		}
		onToggleAddMode(true)
	}

	@objc private func closeTapped() {
		onClose()
	}
}
