# POI editor: hide Attributes tab for pending objects; align tab restore with new nodes

Standalone plan: **`UserPrefs.poiTabIndex`** and **Attributes** visibility in [`POITabBarController`](../../src/iOS/POI/POITabBarController.swift).

## Code today

- [`src/iOS/POI/POITabBarController.swift`](../../src/iOS/POI/POITabBarController.swift) `viewDidLoad`:
  - Reads `UserPrefs.shared.poiTabIndex`.
  - If `tabIndex == 2` and `selection == nil`, sets `tabIndex = 0`.
  - If `selection == nil`, removes the last view controller from `viewControllers` (the **Attributes** nav stack).
  - Sets `selectedIndex = tabIndex`.
- `selection` is `AppDelegate.shared.mapView.selectedPrimary` (node, way, or relation).
- **Pending** OSM objects use **negative `ident`** until upload (see e.g. [`OsmXmlGenerator.swift`](../../src/Shared/OSMModels/OsmXmlGenerator.swift)); they are still **non-nil** `selectedPrimary`, so all **three** tabs remain and saved index **2** can reopen **Attributes** on a not-yet-uploaded **way** / **area**.
- `updatePOIAttributesTabBarItemVisibility(withSelectedObject:)` removes Attributes only when `selectedObject == nil` (often redundant after `removeLast()` in the same `viewDidLoad`).

## Goal

- **Ways** and **areas** (and relations if applicable) that are **pending** (local-only, no server metadata) should match **new node** UX: **no Attributes tab**, and **no restoring saved tab index 2** onto a two-tab controller.

## Implementation

1. Add `shouldShowAttributesTab(for selection: OsmBaseObject?) -> Bool`:
   - `selection == nil` → `false`
   - `selection.ident < 0` → `false` (confirm no edge case where negative id is still “real” in tests)
   - else → `true`
2. In `viewDidLoad`, replace the bare `selection == nil` check with `shouldShowAttributesTab`: when `false`, perform the same `removeLast()` and the same **index 2 → 0** clamping as today.
3. Keep `updatePOIAttributesTabBarItemVisibility` consistent (same predicate), or remove dead paths if redundant.
4. Optional follow-up: if selection can become non-nil while POI stays open, document whether tab list must refresh (out of scope unless product requires it).

## Automated testing

- Extract **pure function**  
  `resolvedTabBar(savedIndex: Int, selection: OsmBaseObject?, defaultThreeTabs: Bool) -> (tabCount: Int, selectedIndex: Int)`  
  mirroring storyboard order **0 Common Tags, 1 All Tags, 2 Attributes**.
- **XCTest** matrix: `savedIndex` ∈ {0,1,2} × `selection` ∈ {nil, node ident -1, node ident +1, way ident -1}.

## Manual testing

1. Edit **existing** object → **Attributes** → switch to **All Tags** → close → create **new way** (negative id) → open POI → confirm **only two tabs** and sensible **selectedIndex** (0 or 1 from prefs, never a blank third slot).
2. Leave previous session on **Attributes** (`poiTabIndex == 2`) → open POI for **pending way** → lands on **Common Tags** (0), not crashed tab index.
3. After **upload** (positive id), reopen POI → **Attributes** tab returns and index 2 is valid again.
