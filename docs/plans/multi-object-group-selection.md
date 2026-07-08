# Multi-object group selection

Planning document for the multi-select / group editing feature (iD-style).

## Goal

Allow mappers to select multiple OSM objects as a temporary editing group, move them
together, add members incrementally, and edit shared tags with conflict handling for
differing values.

## Current state (as verified in code)

- **Selection is single-object only.** `EditorMapLayer` exposes `selectedNode`,
  `selectedWay`, `selectedRelation` and the derived `selectedPrimary` (`node ?? way ?? relation`).
  `MapView.Selections` holds at most one of each type. These are referenced in ~40 places;
  each `didSet` triggers `setNeedsLayout()` + `owner.selectionDidChange()`.
  - `EditorMapLayer.swift` lines ~1790–1827 (`selections`, `selectedPrimary`, `selectedNode/Way/Relation`).
  - `MapView.swift` lines ~61–65 (`struct Selections`).
- **The "tooltip" is `PushPinView`** — a balloon with a text label and a move-handle
  `CALayer` (SF Symbol `arrow.up.and.down.and.arrow.left.and.right`). It has **only a
  `UIPanGestureRecognizer`** (no long-press today). Dragging the balloon drags the
  anchor object via `dragCallback`.
  - `PushPinView.swift` lines ~122–124 (pan recognizer), ~93–103 (move icon).
- **Pushpin text** is centralized in `MapView.refreshPushpinText()` (lines ~846–849):
  single source of truth → trivial to branch for a "Group" label.
- **Tap selection** runs through `EditorMapLayer.selectObjectAtPoint(_:)`
  (`+Edit.swift` ~140), invoked from `MapView.handleTapGesture` (~1024–1030). A normal tap
  **replaces** the current selection.
- **Map drag** runs through `dragContinue`/`dragMove`/`dragFinish` (`+Edit.swift` ~232+).
  `dragContinue` moves `object.nodeSet()` only, with delicate undo-coalescing
  (`silentUndo`, `beginUndoGrouping`/`endUndoGrouping`). `dragFinish` has heavy
  single-object special-casing (node→way connection, node merge, multipolygon role updates).
- **The main "+" add-node button already uses a long-press + timestamp pattern**
  (`MainViewController.plusButtonLongPressHandler`, `plusButtonTimestamp`,
  routed in `MapView.handleTapGesture` via `if mainView.plusButtonTimestamp != 0.0`).
  It **creates geometry**; it does not select existing objects.
- **Edit toolbar** (`MapView.updateEditControl()` ~418–501) is the established
  "something is selected" surface, anchored at the **bottom**; it hides `rulerView`
  while shown and builds its action set purely from `selectedPrimary`'s type.
- **Top of screen is already dense** (storyboard `@IBOutlet`s): settings, display,
  upload, undo/redo, search, compass, aerial logo, help, plus `userInstructionLabel` /
  `flashLabel`. There is **no precedent for a top overlay bar** in the app.
- **POI editing is single-object end-to-end:**
  - `POITabBarController.viewDidLoad` reads `appDelegate.mapView.selectedPrimary`,
    sets `keyValueDict = selection?.tags ?? [:]`.
  - Cells read values directly from `keyValueDict[key]`
    (`POICommonTagsViewController` ~445–455).
  - `commitChanges()` → `setTagsForCurrentObject(keyValueDict)` →
    `mapData.setTags(tags, for: selectedPrimary)`, which **replaces the object's
    entire tag set**.
- `selectionDidChange()` (`MapView.swift` ~1172) only forwards `selectedPrimary` to the
  markers view; the editor highlight pass currently highlights the single selection.

## Hard design constraints (decided from code review)

These are binding for the implementation and resolve the earlier open "TBD" items.

### C1 — Selection model is ADDITIVE, never a rewrite

Do **not** replace `selectedNode/Way/Relation` or the `Selections` struct. Keep
`selectedPrimary` as the **anchor** (first-selected member, or the object under the
pushpin) so all ~40 existing references keep working unchanged.

Add a parallel, ordered store layered on top:

```swift
// On EditorMapLayer (or a small dedicated owner type it holds):
private(set) var groupMembers: [OsmBaseObject] = []   // ordered by selection time
var isGroupActive: Bool { groupMembers.count > 1 }
```

Rules:

- The anchor (`selectedPrimary`) is always `groupMembers.first` when a group is active.
- `groupMembers` is empty (or single) for normal single-selection; existing code paths
  are untouched in that case.
- Mutating `groupMembers` must call the same `setNeedsLayout()` + `selectionDidChange()`
  hooks so highlighting and toolbars refresh consistently.
- Group is **session-only / ephemeral**: cleared by `unselectAll()` and never persisted
  or encoded. (Resolves the persistence open question.)
- Deduplicate on add: never append an object already in `groupMembers`.

### C2 — Multi-value tags: mixed keys tracked separately; commit diffs, never overwrites

This is the highest correctness risk. Two failure modes to avoid:

1. Storing a sentinel string (e.g. `"Multiple values"`) in `keyValueDict` → if the user
   never edits that field, commit writes the literal sentinel onto every member. Silent
   corruption.
2. Applying the merged dict wholesale to each member → clobbers per-object tags that were
   never part of the shared edit (e.g. each shop's unique `name`).

Required model (mirrors iD):

- Build the editor's working `keyValueDict` by merging member tags:
  - For each key present on **all** members with the **same** value → that value.
  - For each key whose value **differs** across members, OR is **absent on some** members
    → the key is **mixed**. Store its key in a separate `mixedKeys: Set<String>`.
    Do **not** put a placeholder into `keyValueDict` for mixed keys; leave the dict value
    empty/absent and let the cell render the localized **"Multiple values"** placeholder
    based on `mixedKeys.contains(key)`.
- Track which keys the user actually edits this session in `userEditedKeys: Set<String>`
  (populated from the existing `textFieldChanged` / value-picker callbacks).
- **Commit applies a diff, per member:**
  - For each key in `userEditedKeys`: set the new value on every member (empty value ⇒
    remove the key from that member).
  - Keys **not** in `userEditedKeys` are left **untouched** on every member — including
    still-mixed keys the user never opened.
  - Never write the contents of a mixed, unedited key.
- This commit/merge logic must be a **pure function** (input: `[member tags]` +
  `userEditedKeys` + new values → output: per-member resulting tags) so it can be unit
  tested independently of UI. **Unit tests are a required deliverable for this phase.**

Mixed-value detail sheet (the "list of values" the user story asks for):

- Tapping a mixed field opens a sheet listing `(member label → current value)` like iD.
- Selecting one of the listed values, or typing a new value, sets it as the shared value
  for all members and marks the key as user-edited (removing it from `mixedKeys` for
  display purposes).

### C3 — Plain-tap behavior while a group is active

A normal tap currently replaces selection (`handleTapGesture` → `selectObjectAtPoint`).
To avoid users destroying groups by accident:

- While a group is active and **not** in an add-mode:
  - Tap on a **member** → re-anchor to that member (it becomes `selectedPrimary`); group
    is preserved.
  - Tap on a **non-member object** → does **not** silently join it; treat as a normal
    new single selection only after the group is dismissed. Recommended: ignore for
    selection purposes and require the explicit "+" flow to add objects, so taps can't
    accidentally grow or replace the group. (If product prefers, a tap on empty space
    could be the dismiss gesture — see below.)
  - Tap on **empty space** → dismiss the group (clear `groupMembers`, fall back to no
    selection). The persistent group bar is the affordance that signals "you are in
    group mode," so this dismissal is discoverable.
- The group bar always offers an explicit close/dismiss control as the unambiguous exit.

### C4 — Group creation via long-press (not force-touch)

The input says "wenn ich da fest drauf drücke." Implement as a standard
`UILongPressGestureRecognizer` on `PushPinView` (force-touch APIs are deprecated and
inconsistent across devices). It must coexist with the existing pan:

- Configure so the pan does not start during a long-press and vice versa
  (`UIGestureRecognizerDelegate` / `require(toFail:)` as needed).
- On long-press recognized while exactly one object is selected → start a group seeded
  with the current `selectedPrimary`, show the group bar, switch pushpin text to "Group".

### C5 — "+" add-mode uses its OWN state, not `plusButtonTimestamp`

The existing `plusButtonTimestamp` is for **creating geometry** and must not be
overloaded. Add a dedicated state on the group controller:

```swift
enum GroupAddMode { case off, armed, batch }
var groupAddMode: GroupAddMode = .off
```

- Tap group-bar "+" → `.armed`; button shows pressed/highlighted state.
- Next map tap on an object → append to group, return to `.off`, reset button.
- Long-press group-bar "+" → `UIImpactFeedbackGenerator` haptic + `.batch`; each map tap
  appends a member; mode persists until the user taps "+" again (toggles `.off`) or the
  group is dismissed.
- Routing happens in `MapView.handleTapGesture`, branching on `groupAddMode` **before**
  the existing `plusButtonTimestamp` / `selectObjectAtPoint` logic.

### C6 — Group move is a dedicated path that skips single-object finish logic

Do not thread flags through `dragContinue`/`dragFinish`. Add a dedicated group-drag path:

- Compute the **union of all members' node sets** once.
- Inside a **single** `beginUndoGrouping`/`endUndoGrouping`, translate every node in the
  union by the same screen delta (reusing the per-node `adjust(_:byScreenDistance:)`
  math already in `dragContinue`), preserving the existing undo-coalescing so a drag is
  one undo step.
- **Skip** `dragFinish`'s node→way connection, node merge, and multipolygon-role logic
  for group moves — those are single-object semantics and are wrong for a group.

### C7 — Edit toolbar gating for multi-select

`updateEditControl()` builds actions from `selectedPrimary`'s type. Add an explicit
group branch (checked first):

- When `isGroupActive`: action set is `[.EDITTAGS]` (and optionally `.DELETE` if we choose
  to support deleting all members). Explicitly **exclude** `MORE`, `RESTRICT`,
  `PASTETAGS`, and node/way-specific actions that have no multi-object meaning.

### C8 — Highlight all members

The editor highlight pass and `selectionDidChange()` currently surface only
`selectedPrimary`. Extend the editor render/highlight pass to draw the selection
highlight for **every** object in `groupMembers`, so the group is "konstant sichtbar."

## UI: group bar

The user story specifies a bar "oben im Bildschirm," so a top bar is the requested
design. Constraints (no precedent exists, so be careful):

- Pin below the safe-area top inset and **below the existing top button cluster**
  (settings/display/upload/undo-redo/search/compass/help) so it never overlaps them on
  small devices or iPad. Verify against `userInstructionLabel` / `flashLabel` positions.
- Horizontal scroll of member chips, each showing the member's preset icon (fallback:
  geometry glyph), in **selection order**.
- A trailing **"+"** control implementing the `GroupAddMode` flow (C5) with a clear
  pressed/armed visual state and a distinct batch-mode state.
- A clear **close/dismiss** control (C3 exit).
- New file: `GroupSelectionBar.swift`, added programmatically in `MainViewController.viewDidLoad`
  (mirroring how `mapLayersView` is set up).

Lower-surface alternative to evaluate during implementation: reuse/extend the existing
bottom `editToolbar` area instead of a brand-new top bar. This is more consistent with
current patterns and lower-risk, but deviates from the literal "oben" request — flag the
trade-off to the product owner before building the top bar if cost becomes a concern.

## Map visuals & pushpin

- Single object → pushpin text = `friendlyDescription()` (unchanged).
- Group active → pushpin text = localized **"Group"**; branch in `refreshPushpinText()`
  (single-line change thanks to the centralized text setter).
- Move handle already exists in `PushPinView` — no new asset; the same balloon drives the
  group move via the dedicated drag path (C6).

## Implementation phases

| Phase | Scope | Key risk |
|-------|-------|----------|
| 1 | Additive `groupMembers` model (C1); highlight all members (C8); read-only `GroupSelectionBar` showing chips | Keep single-selection paths byte-for-byte unchanged |
| 2 | Long-press pushpin → create group (C4); group pushpin "Group" label; dedicated group move path (C6) | Gesture coexistence on `PushPinView`; undo grouping |
| 3 | `GroupAddMode` add / batch-add on the bar's "+" (C5); tap routing in `handleTapGesture`; plain-tap rules (C3) | Tap routing collisions; accidental group loss |
| 4 | Multi-object tag merge + `mixedKeys` + diff-commit (C2); "Multiple values" placeholder + value list sheet; **unit tests** | **Highest** — data correctness | **Done** |
| 5 | Edit-toolbar gating (C7); edge cases; xliff strings | Action sets, relations in group |

## Key files

- `src/Shared/EditorLayer/EditorMapLayer.swift` (+ `+Edit.swift`, `+HitTest.swift`)
- `src/Shared/MapView.swift`
- `src/iOS/CustomViews/PushPinView.swift`
- `src/iOS/MainViewController.swift`
- `src/iOS/POI/POITabBarController.swift`, `POICommonTagsViewController.swift`,
  `POIAllTagsViewController.swift`
- **New:** `GroupSelectionBar.swift`; a multi-value tag merge/commit helper
  (e.g. `GroupTagMerge.swift`) holding the pure merge/diff functions + their unit tests.

## New localized strings (xliff)

- "Group" (pushpin label)
- "Multiple values" (mixed-field placeholder)
- Any group-bar accessibility labels (add member, batch add, dismiss group)

## Implementation notes (Phases 1–5)

Decisions made during implementation:

- **Add-mode tap toggles members** — tapping an object already in the group while `groupAddMode` is active removes it (not add-only), for quicker correction.
- **Pushpin label** — localized `Group (%d)` with member count when `isGroupSessionActive` (`groupMembers` non-empty, including the one-member armed session).
- **One-member group session** — `isGroupSessionActive` (`!groupMembers.isEmpty`) gates toolbar (`[.EDITTAGS]` only), group drag, and pushpin label; `isGroupActive` (count > 1) remains for multi-select map taps, POI group editing, and tag commit. Long-press pushpin seeds a one-member session with `.armed` add mode; POI editing still uses the single-object path until a second member is added.
- **Mixed-field blur protection** — focusing then blurring a mixed preset field without entering text does not call `markKeyEdited` or write `""` into `keyValueDict`; only a non-empty value or explicit picker choice unifies the key.
- **Empty-space dismiss** — tapping empty map while a group is active clears the group and selection (`unselectAll()`); documented in the bar close button accessibility hint.
- **Edit toolbar** — group-active branch offers `[.EDITTAGS]` only; `.DELETE` deferred per C7 open decision (comment in `updateEditControl()`).
- **Bar placement** — `GroupSelectionBar` pinned below the top button cluster (`safeArea.top + 76`), centered, height 44pt, owned by `MainViewController`, updated from `MapView.selectionDidChange()`.
- **Long-press pushpin** — seeds group with one member, shows bar, sets `.armed` so the next tap can add a second member immediately.
- **Phase 4 (tag merge/commit)** — `GroupTagMerge` pure helpers; POI tab loads merged shared tags + `mixedKeys`; commit diffs via `userEditedKeys` only. Relations tab remains anchor-only (`parentRelations` of `selectedPrimary`). Feature-type changes diff old vs new dict and mark every changed key as edited. Mixed preset fields show localized "Multiple values" placeholder (never stored in `keyValueDict`); preset value picker adds a "Current values" section listing per-member values when the key is mixed.

## Remaining product decisions (non-blocking, pick before Phase 4/5)

- Maximum group size / performance ceiling with many ways (union node-set drag cost).
- Whether `DELETE` is offered for a whole group in the edit toolbar (C7) — **v1: EDITTAGS only**.
- Relations in a group: include the relation as a whole, or only its member ways/nodes?
- Whether a tap on empty space dismisses the group, or only the explicit close control
  does (C3) — **implemented: empty-space tap dismisses** (see bar accessibility hint).
