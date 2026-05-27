# POI editor: name-like tag keys — same autocapitalization as `name`

Standalone plan: **`name`**, **`alt_name`**, **`old_name`**, **`name:*`** value fields.

## Code today

- [`src/iOS/POI/POICommonTagsViewController.swift`](../../src/iOS/POI/POICommonTagsViewController.swift): for preset-driven cells, `cell.valueField.autocapitalizationType = presetKey.autocapitalizationType` ([`PresetDisplayKey`](../../src/Shared/PresetsDisplay/PresetDisplayKey.swift) comes from tagging schema).
- [`src/iOS/POI/KeyValueTableCell.swift`](../../src/iOS/POI/KeyValueTableCell.swift): `awakeFromNib` sets `text2.autocapitalizationType = .none` (value field).
- [`src/iOS/POI/POIAllTagsViewController.swift`](../../src/iOS/POI/POIAllTagsViewController.swift): `cellForRow` sets `text1.autocapitalizationType = .none` for the key field; value field keeps **none** from the cell nib.

## Goal

- Any **name-like** key should use the **same** `UITextAutocapitalizationType` (and related traits if desired) as the primary **`name`** field on **Common Tags** for that object — typically **`.words`**, but **verify at runtime** against the `name` `PresetDisplayKey` for the current feature.

## Implementation

1. Add `TagKey.isNameLike(_ key: String) -> Bool`:
   - Exact: `name`, `alt_name`, `old_name` (extend list if product adds `official_name`, etc.).
   - Prefix: `key.hasPrefix("name:")` — watch for false positives (`namesake` is not `name:`).
2. **All Tags:** in `tableView(_:cellForRowAt:)`, after configuring `KeyValueTableCell`, if `isNameLike(kv.k)`, set `text2.autocapitalizationType` (and optionally `spellCheckingType`) to match **`name`** behavior.
3. **Common Tags:** when configuring `PresetValueTextField`, if `isNameLike(presetKey.tagKey)` and schema supplied `.none`, **override** to match the capitalization type used for `tagKey == "name"` on the same feature (query `allPresets` / first matching display key for `"name"`).
4. **KeyValueTableCell** `textView` path: if multi-line editor uses different traits, align **name-like** keys there too (grep `textView.autocapitalizationType` in same file).

## Automated testing

- **XCTest** for `isNameLike`: positive `name`, `name:en`, `name:zh-Hans`, `alt_name`, `old_name`; negative `namesake`, `name_source`, empty string.

## Manual testing

1. **All Tags:** add row `name:de` → type multi-word value → keyboard / autocapitalization behaves like **`name`** on **Common Tags**.
2. **Common Tags:** preset fields for localized names (if shown) get word caps.
3. Non-name keys unchanged (e.g. `ref`, `operator`).
