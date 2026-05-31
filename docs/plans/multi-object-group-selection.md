# Multi-object group selection

Planning document for the multi-select / group editing feature (iD-style).

## Goal

Allow mappers to select multiple OSM objects as a temporary editing group, move them together, add members incrementally, and edit shared tags with conflict handling for differing values.

## Current state

- Selection is single-object only: `EditorMapLayer.selectedNode/Way/Relation` and `MapView.Selections`.
- Long-press on map shows an action sheet to pick one object from overlapping hits (`longPressAtPoint`).
- Pushpin callout shows object name and a move handle; drag moves one object.
- POI editors (`POITabBarController`) bind to a single `selectedPrimary`.

## Proposed architecture

### 1. Selection group model

- Add `SelectionGroup` (ordered `[OsmBaseObject]`) owned by `EditorMapLayer` / `MapView`.
- `selectedPrimary` remains the “anchor” object (first selected, or object under pushpin).
- Group creation: long-press on pushpin callout while one object is selected → start group with that object.
- Subsequent taps while not in add-mode replace selection unless modifier/long-press adds to group (TBD in UX polish).
- `unselectAll()` clears group and single selection.

### 2. Group bar UI

- New `GroupSelectionBar` pinned to top of map (below safe area / nav chrome).
- Horizontal scroll of member chips (preset icon or geometry glyph) in selection order.
- **+** button enters *add mode* (pressed/highlighted state).
- Tap map object in add mode → append to group, exit add mode.
- Long-press **+** → `UIImpactFeedbackGenerator`, enter *batch add mode*; each map tap adds until user taps **+** again or dismisses group.

### 3. Map visuals & pushpin

- Render selection highlight for all group members (reuse editor highlight pass).
- Pushpin label: single object → `friendlyDescription()`; group → localized **“Group”** with move icon.
- Group drag: extend `dragMove` / `dragFinish` to translate all member geometries by the same screen delta (respect node/way semantics, undo grouping).

### 4. Multi-object tag editing

- `POITabBarController` accepts `selections: [OsmBaseObject]`.
- Merge tags: for each key, if all values equal → show value; if any differ → show **“Multiple values”** (localized).
- Tap conflicting field → sheet listing `(object label → value)` like iD; picking a value sets that value on all objects, or user can type a new shared value.
- `commitChanges()` applies `keyValueDict` to every group member.
- Hide or disable edit actions that are undefined for multi-select (split, join, turn restrictions, etc.).

### 5. Gesture integration

- `selectObjectAtPoint`: branch on add-mode / batch-add-mode flags before default single-select.
- Reuse existing long-press disambiguation sheet only when not in group-add mode.
- Coordinate with map pan/zoom and existing `plusButtonTimestamp` long-press on main **+** (geometry creation) to avoid conflicts.

## Suggested implementation phases

| Phase | Scope |
|-------|--------|
| 1 | `SelectionGroup` model, member highlighting, group bar read-only |
| 2 | Long-press pushpin → create group; group pushpin label & group move |
| 3 | Add / batch-add modes on group bar **+** |
| 4 | Multi-tag merge UI and batch commit |
| 5 | Edit toolbar gating, edge cases, xliff strings |

## Key files

- `src/Shared/EditorLayer/EditorMapLayer.swift` (+ `+Edit.swift`, `+HitTest.swift`)
- `src/Shared/MapView.swift`
- `src/iOS/CustomViews/PushPinView.swift`
- `src/iOS/MainViewController.swift`
- `src/iOS/POI/POITabBarController.swift`, `POICommonTagsViewController.swift`, `POIAllTagsViewController.swift`
- **New:** `GroupSelectionBar.swift`, `MultiValueTagPresenter.swift` (or similar)

## Open questions

- Maximum group size / performance with many ways?
- Should group persist across app background or only for session?
- Relations in group: include as whole relation or only nodes/ways?
