# Pushpin label: preset first line, optional name second line

Standalone plan: selection **callout** text on the map pushpin balloon.

## Code today

- [`src/Shared/MapView.swift`](../../src/Shared/MapView.swift) — `refreshPushpinText()` assigns a **single** string:  
  `editorLayer.selectedPrimary?.friendlyDescription() ?? NSLocalizedString("(new object)", comment: "")`  
  to `pushPin?.text`.
- [`src/Shared/OSMModels/OsmBaseObject.swift`](../../src/Shared/OSMModels/OsmBaseObject.swift) — `friendlyDescription(withDetails:)` prefers **`givenName()`** (e.g. `name`, `name:en`, …), then a **matched preset** `friendlyName()`, then many fallbacks. So the balloon often shows **name**, not preset type.
- [`src/iOS/CustomViews/PushPinView.swift`](../../src/iOS/CustomViews/PushPinView.swift) — one **CATextLayer**; `layoutSubviews` sizes the balloon from `textLayer.preferredFrameSize()`. Two visual lines require **layout and rendering** changes (second `CATextLayer`, `NSAttributedString` with two font sizes, or embedded `UILabel`).

## Goal

- **Line 1:** Always show **matched preset / feature type** when a non-generic match exists (same priority intent as “what it is”).
- **Line 2 (optional):** Show display **name** (e.g. from `givenName()`) when present, using a **smaller** font than line 1.

## Implementation

1. Add a helper (on `OsmBaseObject` or a small free function) returning `(primary: String, secondary: String?)` — e.g. `pushpinCalloutLines(...)`.
   - **Primary:** result of preset matching + `friendlyName()` when not generic; else fall back to current `friendlyDescription()` behavior for line 1 only.
   - **Secondary:** `givenName()` if non-empty and **not redundant** with primary (normalize compare case/whitespace).
2. **`refreshPushpinText()`:** pass both strings into `PushPinView` (new API e.g. `setPrimary(_:secondary:)`) instead of a single `text`.
3. **`PushPinView`:** layout two lines; keep move handle and hit-testing; ensure `preferredFrameSize()` / max width (300pt) still behave; truncation on long strings.
4. **New object** (`selectedPrimary == nil`): keep localized “new object” string as today (single line acceptable).

## Automated testing

- Unit tests for the helper with synthetic `tags` dictionaries: e.g. `shop=convenience` + `name=Foo` → primary convenience preset label, secondary `Foo`.
- Cases: name only, preset only, neither (fallback), `name` equals preset label (secondary nil).

## Manual testing

1. Objects with **only** `name` → verify line 1 still useful (preset or fallback).
2. Objects with **preset + name** → line 1 preset, line 2 name, smaller typography visible.
3. Long **name** / long preset string → truncation and balloon size do not cover crosshair incorrectly (opacity logic in `PushPinView` still sane).
4. After tag edits in POI editor, return to map → `refreshPushpinText()` reflects updates.
