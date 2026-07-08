//
//  TrafficSignPickerViewController.swift
//  Go Map!!
//

import UIKit

final class TrafficSignPickerViewController: UIViewController,
	UICollectionViewDataSource,
	UICollectionViewDelegateFlowLayout,
	UISearchResultsUpdating
{
	var countryCode = ""
	var initialValue = ""
	var onApply: ((String) -> Void)?

	private var selection: [TrafficSignSelectionItem] = []
	private var searchResults: [TrafficSignEntry] = []
	private let catalog = TrafficSignCatalog.shared

	private let selectedScroll = UIScrollView()
	private let selectedStack = UIStackView()
	private let composedValueLabel = UILabel()
	private let collectionView: UICollectionView
	private let searchController = UISearchController(searchResultsController: nil)
	private let emptyResultsLabel = UILabel()

	private let cellId = "SignCell"

	init() {
		let layout = UICollectionViewFlowLayout()
		layout.minimumInteritemSpacing = 8
		layout.minimumLineSpacing = 8
		layout.sectionInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
		collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		title = NSLocalizedString("Traffic Signs", comment: "Picker title for traffic_sign tag")

		selection = catalog.decompose(tagValue: initialValue, countryCode: countryCode)
		updateSearchResults()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .cancel,
			target: self,
			action: #selector(cancelTapped))
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done,
			target: self,
			action: #selector(doneTapped))

		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		navigationItem.searchController = searchController
		definesPresentationContext = true

		selectedScroll.translatesAutoresizingMaskIntoConstraints = false
		selectedScroll.showsHorizontalScrollIndicator = false
		selectedStack.axis = .horizontal
		selectedStack.spacing = 8
		selectedStack.alignment = .center
		selectedStack.translatesAutoresizingMaskIntoConstraints = false
		selectedScroll.addSubview(selectedStack)

		composedValueLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
		composedValueLabel.textColor = .secondaryLabel
		composedValueLabel.numberOfLines = 0
		composedValueLabel.translatesAutoresizingMaskIntoConstraints = false

		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.backgroundColor = .systemBackground
		collectionView.dataSource = self
		collectionView.delegate = self
		collectionView.register(TrafficSignPickerCell.self, forCellWithReuseIdentifier: cellId)

		emptyResultsLabel.font = .systemFont(ofSize: 15)
		emptyResultsLabel.textColor = .secondaryLabel
		emptyResultsLabel.textAlignment = .center
		emptyResultsLabel.numberOfLines = 0

		view.addSubview(selectedScroll)
		view.addSubview(composedValueLabel)
		view.addSubview(collectionView)

		NSLayoutConstraint.activate([
			selectedScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			selectedScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
			selectedScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
			selectedScroll.heightAnchor.constraint(equalToConstant: 56),
			selectedStack.topAnchor.constraint(equalTo: selectedScroll.topAnchor),
			selectedStack.leadingAnchor.constraint(equalTo: selectedScroll.leadingAnchor),
			selectedStack.trailingAnchor.constraint(equalTo: selectedScroll.trailingAnchor),
			selectedStack.bottomAnchor.constraint(equalTo: selectedScroll.bottomAnchor),
			selectedStack.heightAnchor.constraint(equalTo: selectedScroll.heightAnchor),
			composedValueLabel.topAnchor.constraint(equalTo: selectedScroll.bottomAnchor, constant: 4),
			composedValueLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
			composedValueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
			collectionView.topAnchor.constraint(equalTo: composedValueLabel.bottomAnchor, constant: 8),
			collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
		])

		rebuildSelectedRow()
	}

	@objc private func cancelTapped() {
		dismiss(animated: true)
	}

	@objc private func doneTapped() {
		let value = catalog.compose(selection: selection, countryCode: countryCode)
		onApply?(value)
		dismiss(animated: true)
	}

	func updateSearchResults(for searchController: UISearchController) {
		let query = searchController.searchBar.text ?? ""
		searchResults = catalog.search(query: query, countryCode: countryCode)
		updateEmptyResultsState(query: query)
		collectionView.reloadData()
	}

	private func updateSearchResults() {
		searchResults = catalog.search(query: "", countryCode: countryCode)
		updateEmptyResultsState(query: "")
	}

	private func updateEmptyResultsState(query: String) {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		if searchResults.isEmpty, !trimmed.isEmpty {
			emptyResultsLabel.text = String(
				format: NSLocalizedString("No signs match '%@'", comment: "Empty traffic sign search results"),
				trimmed)
			collectionView.backgroundView = emptyResultsLabel
		} else {
			collectionView.backgroundView = nil
		}
	}

	private func rebuildSelectedRow() {
		selectedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
		for (index, item) in selection.enumerated() {
			let chip = makeChip(for: item, index: index)
			selectedStack.addArrangedSubview(chip)
		}
		updateComposedValuePreview()
	}

	private func updateComposedValuePreview() {
		if selection.isEmpty {
			composedValueLabel.text = nil
			composedValueLabel.isHidden = true
		} else {
			composedValueLabel.text = catalog.compose(selection: selection, countryCode: countryCode)
			composedValueLabel.isHidden = false
		}
	}

	private func makeChip(for item: TrafficSignSelectionItem, index: Int) -> UIView {
		let button = UIButton(type: .system)
		button.tag = index
		button.addTarget(self, action: #selector(removeChip(_:)), for: .touchUpInside)

		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			imageView.widthAnchor.constraint(equalToConstant: 28),
			imageView.heightAnchor.constraint(equalToConstant: 28),
		])

		let removeLabel = UILabel()
		removeLabel.text = "×"
		removeLabel.font = .systemFont(ofSize: 14, weight: .bold)
		removeLabel.textColor = .secondaryLabel
		removeLabel.translatesAutoresizingMaskIntoConstraints = false

		switch item {
		case let .catalog(entry):
			imageView.image = catalog.image(for: entry) ?? UIImage(systemName: "signpost.right")
			button.accessibilityLabel = entry.descriptiveName
		case let .other(_, label, _):
			imageView.image = UIImage(systemName: "questionmark.circle")
			button.accessibilityLabel = String(
				format: NSLocalizedString("Other: %@", comment: "Unrecognized traffic sign fragment"),
				label)
		}
		button.accessibilityHint = NSLocalizedString("Double-tap to remove", comment: "Remove selected traffic sign chip")

		button.addSubview(imageView)
		button.addSubview(removeLabel)
		NSLayoutConstraint.activate([
			imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
			imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
			removeLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 2),
			removeLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -4),
			removeLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
			button.heightAnchor.constraint(equalToConstant: 44),
		])
		return button
	}

	@objc private func removeChip(_ sender: UIButton) {
		guard sender.tag < selection.count else { return }
		selection.remove(at: sender.tag)
		rebuildSelectedRow()
		collectionView.reloadData()
	}

	private func isSelected(_ entry: TrafficSignEntry) -> Bool {
		selection.contains(where: {
			if case let .catalog(e) = $0 { return e.osmValuePart == entry.osmValuePart }
			return false
		})
	}

	private func isMainSign(_ entry: TrafficSignEntry) -> Bool {
		if entry.isNamedValue == true { return true }
		return entry.kind == "traffic_sign"
	}

	private func isModifierSelection(_ item: TrafficSignSelectionItem) -> Bool {
		switch item {
		case let .catalog(entry):
			return !isMainSign(entry)
		case .other:
			return true
		}
	}

	private func toggle(_ entry: TrafficSignEntry) {
		if let idx = selection.firstIndex(where: {
			if case let .catalog(e) = $0 { return e.osmValuePart == entry.osmValuePart }
			return false
		}) {
			selection.remove(at: idx)
		} else {
			let newItem = TrafficSignSelectionItem.catalog(entry)
			if isMainSign(entry),
			   !selection.isEmpty,
			   selection.allSatisfy({ isModifierSelection($0) })
			{
				selection.insert(newItem, at: 0)
			} else {
				selection.append(newItem)
			}
		}
		rebuildSelectedRow()
		collectionView.reloadData()
	}

	// MARK: Collection view

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		searchResults.count
	}

	func collectionView(_ collectionView: UICollectionView,
	                    cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
	{
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! TrafficSignPickerCell
		let entry = searchResults[indexPath.item]
		cell.configure(entry: entry, image: catalog.image(for: entry), selected: isSelected(entry))
		return cell
	}

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		toggle(searchResults[indexPath.item])
	}

	func collectionView(_ collectionView: UICollectionView,
	                    layout collectionViewLayout: UICollectionViewLayout,
	                    sizeForItemAt indexPath: IndexPath) -> CGSize
	{
		let columns: CGFloat = 4
		let inset: CGFloat = 12 * 2 + 8 * (columns - 1)
		let available = collectionView.bounds.width - inset
		let width = max(80, available > 0 ? available / columns : 80)
		return CGSize(width: floor(width), height: width + 28)
	}
}

private final class TrafficSignPickerCell: UICollectionViewCell {
	private let imageView = UIImageView()
	private let label = UILabel()

	override init(frame: CGRect) {
		super.init(frame: frame)
		contentView.layer.cornerRadius = 8
		contentView.layer.borderWidth = 1
		contentView.layer.borderColor = UIColor.separator.cgColor

		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		label.font = .systemFont(ofSize: 10)
		label.textAlignment = .center
		label.numberOfLines = 2
		label.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(imageView)
		contentView.addSubview(label)

		NSLayoutConstraint.activate([
			imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
			imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
			imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
			imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
			label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
			label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
			label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
			label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -2),
		])
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError()
	}

	func configure(entry: TrafficSignEntry, image: UIImage?, selected: Bool) {
		imageView.image = image ?? UIImage(systemName: "signpost.right")
		label.text = entry.descriptiveName
		contentView.backgroundColor = selected ? UIColor.systemBlue.withAlphaComponent(0.15) : .secondarySystemBackground
		contentView.layer.borderColor = selected ? UIColor.systemBlue.cgColor : UIColor.separator.cgColor
		accessibilityLabel = entry.descriptiveName
		accessibilityTraits = selected ? [.button, .selected] : .button
	}
}
