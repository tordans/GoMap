# All Tags: preset header — two tap targets (Common Tags + styled chooser)

Standalone plan: preset row on the **All Tags** tab only.

## Code today

- [`src/iOS/POI/POIAllTagsViewController.swift`](../../src/iOS/POI/POIAllTagsViewController.swift): private `SectionHeaderCell` builds a **UILabel** (feature / preset title) and a **UIButton** titled `">"`. Only the button walks the responder chain to find `POIAllTagsViewController` and pushes `POIFeaturePickerViewController` via `pickFeature`. The label is not interactive.
- **Common Tags** uses different UI (`FeatureTypeCell` in [`src/iOS/POI/POICommonTagsViewController.swift`](../../src/iOS/POI/POICommonTagsViewController.swift)); this work does not replace that row.

## Goal

- **Left:** Tapping the preset / feature **title** switches to the **Common Tags** tab (tab index **0**) so users can return to preset fields when the keyboard hides the tab bar.
- **Right:** Replace the plain `">"` control with a **system-styled** control (e.g. **SF Symbol** `chevron.right` or `ellipsis.circle`) and accessibility text such as “Change preset”.

## Implementation

1. **Title control:** Make the label tappable (`UITapGestureRecognizer`), wrap it in `UIButton` with plain configuration, or use `UIControl` — ensure one clear hit target. On action, obtain `tabBarController as? POITabBarController`, set `selectedIndex = 0`, and invoke existing `slideTabTo(tabIndex: 0)` if that matches how tab changes are animated elsewhere (avoid double animation).
2. **Trailing control:** Replace text `">"` with `UIButton.Configuration` + `UIImage(systemName:)`; set `accessibilityLabel` / `accessibilityHint` appropriately.
3. **Separation of concerns:** Preset picker push remains **only** on the trailing button; the title control **must not** push the feature picker.
4. Optional: scroll **Common Tags** table to top when switching (call into `POICommonTagsViewController` if a public method exists, or defer).

## Automated testing

- No unit coverage exists for this header today.
- Optional **UI test** in [`src/iOS/GoMapUITests/MapViewUITestCase.swift`](../../src/iOS/GoMapUITests/MapViewUITestCase.swift): present POI → **All Tags** → tap header title → assert **Common Tags** root is visible. Likely requires **accessibility identifiers** on tab roots or tab bar items.

## Manual testing

1. Select an object with tags → open POI → **All Tags** → focus a value field so the keyboard covers the bottom tab bar → tap the **header title** → verify **Common Tags** appears with preset fields.
2. From the same header, tap the **chevron** (or chosen symbol) → verify **POIFeaturePicker** pushes as before.
3. **VoiceOver:** two distinct elements, correct reading order and labels.
4. iPad / Mac Catalyst: verify tap targets meet minimum size (44pt) if layout changes.
