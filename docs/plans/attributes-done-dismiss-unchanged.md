# Attributes tab: Done dismisses when tags unchanged

Standalone plan: **Attributes** navigation **Done** bar item in [`POIAttributesViewController`](../../src/iOS/POI/POIAttributesViewController.swift).

## Code today

- `viewWillAppear`: `saveButton.isEnabled = tabController?.isTagDictChanged() ?? false` — the **Done** (`saveButton`) **UIBarButtonItem** is **disabled** when the tag dictionary matches the map object, so taps do nothing.
- `done(_:)`: calls `dismiss(animated: true)` then `tabController.commitChanges()` — no branch for “no changes”.

## Goal

- If tags are **unchanged**, **Done** should still **dismiss** the POI editor (same net effect as **Cancel** for persistence: **no** `commitChanges()`).
- If tags **changed**, keep current behavior: dismiss and **commit** tag edits.

## Implementation

1. **Enable** `saveButton` whenever the **Attributes** screen is shown (remove `isEnabled = false` when unchanged), **or** keep enabled logic but use a **custom view** button that stays enabled — simplest path: **always enable** Done on Attributes.
2. In `done(_:)`:  
   - If `!(tabController?.isTagDictChanged() ?? false)` → `dismiss(animated: true)` only (**do not** call `commitChanges()`).  
   - Else → existing `dismiss` + `commitChanges()` order (verify other tabs’ unsaved state: `commitChanges` is what writes `keyValueDict` to the map — confirm cancel path for half-edited **Common Tags** still discards as today).
3. Re-test `cancel(_:)` still only dismisses without commit.

## Automated testing

- Instantiation of `POITabBarController` / `POIAttributesViewController` in unit tests is heavy; optional with mocks.
- If not feasible, document **“not covered by XCTest”** in PR.

## Manual testing

1. Open existing object → **Attributes** only (no edits on any tab) → tap **Done** → sheet closes; object tags on map **unchanged**.
2. Edit a value on **Common Tags** → switch to **Attributes** without further edits → **Done** → tags **persist** (commit still runs).
3. **Cancel** from **Attributes** with pending edits on another tab → behavior matches **pre-change** product expectation (document result; adjust if product wants Cancel to discard sibling edits).
