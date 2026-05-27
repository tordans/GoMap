# Map toolbar: long-press “+” — geometry flyout (line / rectangle / circle)

Standalone plan: map **add node** control and structured drawing modes.

## Code today

- [`src/iOS/MainViewController.swift`](../../src/iOS/MainViewController.swift): `addNodeButtonLongPressGestureRecognizer` and `plusButtonLongPressHandler(_:)`. On **ended**, if press duration **&lt; 0.5s** and touch inside the button, calls `mapView.rightClick(at: mapView.bounds.center())`. Longer presses do not present UI.
- [`displayButtonLongPressHandler()`](../../src/iOS/MainViewController.swift) presents a **UIAlertController** action sheet for aerial / editor display modes — reuse this interaction pattern for consistency.
- Way/node editing: [`src/Shared/EditorLayer/EditorMapLayer+Edit.swift`](../../src/Shared/EditorLayer/EditorMapLayer+Edit.swift) (`extendSelectedWay`, `addNode`, `createWay`, `setTagsForCurrentObject`, …). Preview / rubber-band work would extend this layer or a small helper owned by the editor layer.

## Goal

- **Long-press +** shows a flyout: **Line**, **Rectangle**, **Circle** (per product spec in `github-issue-ideas.md`).
- Each option enters a dedicated **map edit mode** with live preview rules (rubber-band to crosshair, rectangle constraints, circle from two diameter taps).

## Implementation (phased)

**Phase A — UI**

- Detect long-press distinct from the existing short-press → `rightClick` path (adjust duration / state machine so both behaviors remain reliable).
- Present `UIAlertController` (action sheet) or [`CustomActionSheetController`](../../src/iOS/CustomViews/CustomActionSheetController.swift) with three actions; Cancel dismisses with no state change.

**Phase B — Line mode**

- Map “Line” to successive taps that add vertices to an **open way**, reusing or wrapping `extendSelectedWay` / way creation. Define **finish** and **cancel** explicitly (toolbar button, double-tap, or gesture documented in UX).

**Phase C — Rectangle / circle**

- New state on `EditorMapLayer` (or `MapView`): tap counter, crosshair position source, temporary `CAShapeLayer` preview.
- **Rectangle:** three taps, geometry constrained to a true rectangle; preview after tap 2 follows crosshair with right angles preserved.
- **Circle:** two taps = diameter endpoints.
- **Cancel:** document one clear global cancel (toolbar, long-press again, etc.).

## Automated testing

- Extract pure math (rectangle from three corners, circle from two points) into a small **Swift type** and add **XCTest** under [`src/iOS/GoMapTests/`](../../src/iOS/GoMapTests/).
- End-to-end gestures: **UI tests** or manual unless accessibility IDs and stable hooks are added.

## Manual testing

1. Short tap **+** (if still mapped to add node / right-click): behavior unchanged vs baseline build.
2. Long-press **+** → sheet appears; **Cancel** leaves map unchanged.
3. **Line:** draw a short way; **Undo** restores prior state.
4. **Rectangle / circle:** preview matches finger/crosshair; committed object is correct **way**/**area**; test portrait, landscape, external display.
5. Memory: cancel mid-flow — no leaked layers or stuck mode.
