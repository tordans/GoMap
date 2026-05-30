//
//  POITabBarController.swift
//  Go Map!!
//
//  Copyright © 2021 Bryce Cogswell. All rights reserved.
//

import UIKit

class POITabBarController: UITabBarController {
	var keyValueDict = [String: String]()
	var relationList: [OsmRelation] = []
	var selection: OsmBaseObject?

	/// Whether the Attributes tab (index 2) should appear for the current selection.
	/// Pending local-only objects use negative `ident` until upload, same as brand-new nodes.
	static func shouldShowAttributesTab(for selection: OsmBaseObject?) -> Bool {
		guard let selection else { return false }
		return selection.ident >= 0
	}

	/// Resolves tab count and selected index from saved prefs and selection (storyboard order: Common, All, Attributes).
	static func resolvedTabBar(
		savedIndex: Int,
		selection: OsmBaseObject?,
		defaultThreeTabs: Bool = true
	) -> (tabCount: Int, selectedIndex: Int) {
		let showAttributes = shouldShowAttributesTab(for: selection)
		let tabCount = (defaultThreeTabs && showAttributes) ? 3 : 2
		var selectedIndex = savedIndex
		if savedIndex == 2, !showAttributes {
			selectedIndex = 0
		}
		return (tabCount, selectedIndex)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let appDelegate = AppDelegate.shared
		let selection = appDelegate.mapView.selectedPrimary
		self.selection = selection
		keyValueDict = selection?.tags ?? [:]
		relationList = selection?.parentRelations ?? []

		let savedIndex = UserPrefs.shared.poiTabIndex.value ?? 0
		let resolved = Self.resolvedTabBar(savedIndex: savedIndex, selection: selection)
		if !Self.shouldShowAttributesTab(for: selection) {
			var vcList = viewControllers!
			vcList.removeLast()
			self.viewControllers = vcList
		}
		selectedIndex = resolved.selectedIndex

		updatePOIAttributesTabBarItemVisibility(withSelectedObject: selection)

		if #available(iOS 17, *) {
			// On MacCatalyst (and maybe iPad) UITabBar is broken.
			// This fixes it.
			// See https://forums.developer.apple.com/forums/thread/759478
			traitOverrides.horizontalSizeClass = .compact
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// make window resizable on MacCatalyst
		if let windowScene = view.window?.windowScene {
			windowScene.sizeRestrictions?.minimumSize = CGSize(width: 400, height: 300)
			windowScene.sizeRestrictions?.maximumSize = CGSize(width: 2000, height: 2000)
		}
	}

	func removeValueFromKeyValueDict(key: String) {
		keyValueDict.removeValue(forKey: key)
	}

	override var keyCommands: [UIKeyCommand]? {
		let esc = UIKeyCommand(
			input: UIKeyCommand.inputEscape,
			modifierFlags: [],
			action: #selector(escapeKeyPress(_:)))
		return [esc]
	}

	@objc func escapeKeyPress(_ keyCommand: UIKeyCommand?) {
		selectedViewController?.view.endEditing(true)
		selectedViewController?.dismiss(animated: true)
	}

	/// Hides the POI attributes tab when the selection has no server attributes yet (nil or pending negative id).
	/// - Parameter selectedObject: The object that the user selected on the map.
	func updatePOIAttributesTabBarItemVisibility(withSelectedObject selectedObject: OsmBaseObject?) {
		guard !Self.shouldShowAttributesTab(for: selectedObject) else { return }

		var viewControllersToKeep: [UIViewController] = []
		for controller in viewControllers ?? [] {
			if controller is UINavigationController,
			   (controller as? UINavigationController)?.viewControllers.first is POIAttributesViewController
			{
				continue
			}
			viewControllersToKeep.append(controller)
		}

		if viewControllersToKeep.count != viewControllers?.count {
			setViewControllers(viewControllersToKeep, animated: false)
		}
	}

	func setFeatureKey(_ key: String, value: String?) {
		if let value = value,
		   value.count > 0
		{
			keyValueDict[key] = value
		} else {
			keyValueDict.removeValue(forKey: key)
		}
	}

	func commitChanges() {
		AppDelegate.shared.mapView.setTagsForCurrentObject(tags: keyValueDict)
	}

	func isTagDictChanged(_ newDictionary: [String: String]) -> Bool {
		guard let tags = AppDelegate.shared.mapView.selectedPrimary?.tags
		else {
			// it's a brand new object
			return newDictionary.count > 0
		}
		return newDictionary != tags
	}

	func isTagDictChanged() -> Bool {
		return isTagDictChanged(keyValueDict)
	}

	override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
		guard
			let tabIndex = tabBar.items?.firstIndex(of: item),
			tabIndex != selectedIndex
		else { return }
		UserPrefs.shared.poiTabIndex.value = tabIndex
		slideTabTo(tabIndex: tabIndex)
	}

	// Do a sliding animation of the views
	func slideTabTo(tabIndex: Int) {
		guard let newVC = viewControllers?[tabIndex],
		      let fromView = selectedViewController?.view,
		      let toView = newVC.view else { return }
		let moveRight = selectedIndex < tabIndex
		let screenWidth = UIScreen.main.bounds.width
		toView.frame.origin.x = moveRight ? screenWidth : -screenWidth

		view.addSubview(toView)

		UIView.animate(withDuration: 0.3, animations: {
			fromView.frame.origin.x = moveRight ? -screenWidth : screenWidth
			toView.frame.origin.x = 0
		}) { _ in
			fromView.removeFromSuperview()
			self.selectedViewController = newVC
		}
	}
}
