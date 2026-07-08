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
	var groupMembers: [OsmBaseObject] = []
	var mixedKeys = Set<String>()
	var userEditedKeys = Set<String>()

	var isGroupEditing: Bool { groupMembers.count > 1 }

	override func viewDidLoad() {
		super.viewDidLoad()

		let appDelegate = AppDelegate.shared
		let mapView = appDelegate.mapView
		let selection = mapView.selectedPrimary
		self.selection = selection

		if mapView.isGroupActive {
			groupMembers = mapView.groupMembers
			let memberTagSets = groupMembers.map { $0.tags }
			let merged = GroupTagMerge.merge(memberTags: memberTagSets)
			keyValueDict = merged.shared
			mixedKeys = merged.mixedKeys
		} else {
			keyValueDict = selection?.tags ?? [:]
		}

		// Relations tab shows the anchor object's parent relations only (v1).
		relationList = selection?.parentRelations ?? []

		var tabIndex = UserPrefs.shared.poiTabIndex.value ?? 0
		if tabIndex == 2,
		   selection == nil
		{
			tabIndex = 0
		}
		if selection == nil {
			// don't show attributes page
			var vcList = viewControllers!
			vcList.removeLast()
			self.viewControllers = vcList
		}
		selectedIndex = tabIndex

		// hide attributes tab on new objects
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

	func markKeyEdited(_ key: String) {
		userEditedKeys.insert(key)
		mixedKeys.remove(key)
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

	/// Hides the POI attributes tab bar item when the user is adding a new item, since it doesn't have any attributes yet.
	/// - Parameter selectedObject: The object that the user selected on the map.
	func updatePOIAttributesTabBarItemVisibility(withSelectedObject selectedObject: OsmBaseObject?) {
		let isAddingNewItem = selectedObject == nil
		if isAddingNewItem {
			// Remove the `POIAttributesViewController`.
			var viewControllersToKeep: [UIViewController] = []
			for controller in viewControllers ?? [] {
				if controller is UINavigationController,
				   (controller as? UINavigationController)?.viewControllers.first is POIAttributesViewController
				{
					// For new objects, the navigation controller that contains the view controller
					// for POI attributes is not needed; ignore it.
					return
				} else {
					viewControllersToKeep.append(controller)
				}
			}

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
		let mapView = AppDelegate.shared.mapView
		if isGroupEditing {
			mapView.setTagsForGroup(editedValues: keyValueDict, userEditedKeys: userEditedKeys)
		} else {
			mapView.setTagsForCurrentObject(tags: keyValueDict)
		}
	}

	func isTagDictChanged(_ newDictionary: [String: String]) -> Bool {
		if isGroupEditing {
			for key in userEditedKeys {
				let newValue = newDictionary[key]
				for member in groupMembers {
					let oldValue = member.tags[key]
					if newValue != oldValue {
						return true
					}
				}
			}
			return false
		}

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
