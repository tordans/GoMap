# GitHub issue ideas

Vocabulary: **POI editor** (object editor), tabs **Common Tags** / **All Tags** / **Attributes**, **preset** row, **node** / **way** / **area**, map **+** and **layer** flyouts.

---

## Preset row: two tap targets (back to Common Tags + styled chooser)

**Context:** The POI editor has three tabs along the bottom: **Common Tags** (preset fields), **All Tags** (middle, raw tags), and **Attributes** (OSM metadata). At the top of **All Tags** (middle) sits the row that shows the current preset and opens the preset chooser.

**Problem:** With the keyboard up on **All Tags**, the bottom tab bar that allows chaing the tabs is hidden. Users still need a fast path to switch between the first (Common Tags) and second (All Tags) panels.

**Idea:**

Change the UI Element that shows teh current preset and opens the preset chooser:

- **Left (preset title):** Turn the label into a clear control (e.g. button semantics) that switches to the **Common Tags** tab and scrolls/focuses the preset **field list**—same mental model as “I’m editing this preset; take me back to its fields.”
- **Right (chooser):** Replace the small arrow with a standard **SF Symbol** / **system-styled** button (per Apple HIG) so it reads as “open preset picker,” consistent with the rest of the chrome.

---

## Long-press map “+”: flyout for line / rectangle / circle (geometry helpers)

**Context:** The map toolbar already uses a **long-press flyout** on another control (layers / map mode). The **+** control currently adds a **node** in one gesture.

**Goal:** Offer a flyout on **long-press +** so mappers can start structured **way** / **area** work without only dropping isolated nodes.

**Flyout (initial set):** Line · Rectangle · Circle.

**Map interaction (per tool):**

- **Line:** successive taps define vertices of an open way – this is what we now.
- **Rectangle:** three taps = three corners; constraints keep the shape a true rectangle.
- **Circle:** two taps = diameter endpoints.

**Live preview:** After tap 1, draw a **rubber-band segment** from that fix to the crosshair for tap 2. After tap 2 on **Rectangle**, stretch the **rectangle preview** toward the crosshair for tap 3 while **preserving right angles**—the crosshair need not sit exactly on the geometric corner; the preview stays a proper rectangle. Treat this as a dedicated **map edit mode**, separate from normal single-tap node placement.

---

## Map selection callout: preset on line one, `name` on line two

**Context:** Tapping a feature on the map shows a **callout** (tooltip) near the object.

**Today:** The first line sometimes shows **`name=*`** and sometimes the **preset / feature type**, depending on context—which makes quick scanning inconsistent.

**Change:**

1. **Line 1 (always):** Matched **preset name** (the feature type from the preset system), same anchor position as now.
2. **Line 2 (optional):** If the object has a display **name** (e.g. `name=*`), show it here in a **slightly smaller** font so hierarchy reads: *what it is* → *what it’s called*.

---

## Remember last POI tab: skip Attributes for new objects; align node vs way

**Context:** `POITabBarController` restores **`UserPrefs.poiTabIndex`** when the POI editor opens. Tabs are **0 = Common Tags**, **1 = All Tags**, **2 = Attributes**.

**What the code does today (`POITabBarController.viewDidLoad`):**

- **`selection`** is `mapView.selectedPrimary` (the selected **node**, **way**, or **relation**).
- **`selection == nil`** (common when adding a **new standalone node** from the pushpin before a primary object is attached): the **Attributes** nav controller is **removed** from `viewControllers` (only two tabs). If the saved index was **2**, it is **forced to 0** before `selectedIndex` is applied—so you never land on a missing third tab, and you open on **Common Tags** after having left an existing object on **Attributes**.
- **`selection != nil`**: all **three** tabs stay, and the saved index is applied **as-is**—including **2** on objects that are still **local-only** (negative `ident`, not on the API yet).

**Observed UX (matches the above):**

1. Edit an **existing node** → **Attributes** → switch to **Common Tags** or **All Tags** → later open the editor for a **new node** with `selection == nil` → you return to **Common Tags** or **All Tags**, and **Attributes** is not in the tab bar.
2. Same as (1), but leave the last session on **Attributes** (index 2) → next **new node** (`selection == nil`) session opens on **Common Tags** (index 2 is clamped to 0), **Attributes** still hidden.
3. For a **new way** / **area** that already exists in memory, **`selection` is usually non-nil** → **Attributes** remains visible and index **2** can still be restored, even though that tab has no real OSM metadata yet.

**Change:** Treat **new geometry** the same whether `selectedPrimary` is nil or a **pending** **way** / **closed way (area)** / **relation** (e.g. **`ident < 0`** or whatever flag the app uses for “not uploaded”): **strip the Attributes tab** and apply the **same index clamping** as the `selection == nil` branch (never restore **2** onto a two-tab bar; never show **Attributes** until the object has server-backed metadata worth showing). **Ways** and **areas** should match the **new node** behavior the user described.

---

## Name-like tags: same text treatment as `name` on Common Tags

**Context:** In the POI editor (**All Tags** and **Common Tags**), the primary **`name`** field is treated specially while typing (for example **word-capitalization** / title-style behavior and related keyboard or autocorrect affordances).

**Problem:** Other OSM keys that carry human-readable names do not get that behavior today. **`alt_name`**, **`old_name`**, and especially **localized names** (`name:en`, `name:de`, …—any `name:` + language suffix) behave like plain text fields, so mappers must **capitalize each word manually** even though the semantics match `name`.

**Change:** Apply the **same input handling** as for **`name`** to every tag the app treats as a “display name” variant—at minimum **`alt_name`**, **`old_name`**, and **`name:*`** (regex or allow-list keyed off the `name:` prefix). Optional: extend the same list to other preset-defined name fields if they share the same UI control.

---

## Attributes tab: checkmark dismisses when there are no edits

**Context:** On the **Attributes** tab, the navigation bar has a **checkmark** (“done”) control and a way to leave without saving (e.g. **close** / **×**).

**Today:** If **nothing** in the editor changed, the checkmark is effectively a **no-op**—it does not dismiss the POI sheet.

**Change:** When the tag dict is **unchanged**, tapping the **checkmark** should still **dismiss the POI editor** (same as after a successful save), but **must not** write tags—behaviorally equivalent to **dismiss without saving**, like **×**. When there **are** edits, keep current behavior: checkmark **saves** and closes.

---

## Map fixme markers: light blue when the object is a relation member

**Context:** Selecting a **relation** on the map highlights its member **ways** (and other members) in a distinctive **light blue** (`EditorMapLayer` uses `relationColor`, RGB 66/188/244). Separately, objects tagged with **`fixme=*`** get a small **“F”** map marker (`FixmeMarker` via `MapMarkerDatabase`).

**Today:** Relation member highlighting and fixme markers are unrelated visually. Every fixme badge uses the same generic **blue** button styling from `MapMarker.makeButton()`, whether the tagged object stands alone or belongs to one or more **relations**.

**Problem:** Fixmes on **relation members** are often not something mappers can resolve inside Go Map (they may require external tools, relation-level edits, or context the app does not expose). When scanning the map, those markers look the same as fixmes on ordinary nodes and ways, so they add noise without signaling “this is relation-scoped / probably not actionable here.”

**Change:** When a **`fixme=*`** marker is placed on an object that is a **member of at least one relation**, tint the marker with the **same light blue** as relation member highlighting—not the default fixme blue. Fixmes on non-relation objects keep today’s styling.

**Why:** Gives an at-a-glance visual filter: relation-bound fixmes read as a distinct category, so mappers can mentally (or eventually via marker filters) de-emphasize them while focusing on fixmes they can actually address in the editor.

---

## One-way arrows: blue reverse arrow when `bicycle:oneway=no`

**Context:** **`OsmWay.computeIsOneWay()`** treats `oneway=yes` / `-1` and several implicit one-way highway types as **`ONEWAY.FORWARD`** / **`.BACKWARD`**. **`EditorMapLayer`** draws **black** chevron arrows along those ways (`fillColor` black, white stroke) at a fixed offset along the geometry.

**Today:** Only the **general** one-way direction is shown. There is no map hint when cyclists are explicitly allowed the **opposite** direction via **`bicycle:oneway=no`** on a way that is still one-way for other traffic (e.g. `oneway=yes` + `bicycle:oneway=no`).

**Change:** When a way is one-way **and** tagged **`bicycle:oneway=no`**, keep the existing **black** arrow for the motor/general direction, and add a second arrow in the **opposite** direction, drawn in **blue** (distinct from the default black). Place the blue arrow **along the same way** but with a **lateral or longitudinal offset** so it does not sit on top of the black chevron—enough separation to read both directions at a glance.

**Scope (initial):** Match OSM semantics for **`bicycle:oneway=no`** on ways that already resolve to **`isOneWay != .NONE`**; respect **`oneway=-1`** (black arrow backward, blue forward). Optional follow-up: other mode-specific exceptions (`foot:oneway`, `bus:oneway`, …) if mappers need them.

**Why:** This tagging pattern is common on urban cycle infrastructure (one-way street with contraflow cycling). A second, offset, color-coded arrow communicates “cars this way, bikes both ways” without opening the POI editor.

---

## Directional nodes: map **Rotate** updates `direction` / `camera:direction`

**Context:** **`OsmNode.direction`** (see `OsmNode+Direction.swift`) reads numeric degrees, cardinals, or ranges from **`direction=*`** or **`camera:direction=*`**. The map draws a direction wedge via **`directionShapeLayers(with:)`**. In the POI editor, **`PresetValueTextField`** offers a compass affordance that opens **`DirectionViewController`** (“point your phone…”) to set those tag values.

**Today:** The **Rotate** edit action (`.ROTATE` in **`EditorMapLayer+Edit`**) only starts for **ways** and **multipolygon relations**; nodes get *“Only ways/multipolygons can be rotated.”* Rotation always moves geometry. Direction is edited only through the POI field / compass flow.

**Change:** When a selected **node** carries a **technical direction** tag (`direction` or `camera:direction` with a value **`OsmNode.direction`** can parse—not highway **`forward`/`backward`** semantics on a way), expose **Rotate** in the edit menu the same way as for areas, but enter a **direction-edit rotate mode** instead of moving the point:

- Gesture matches existing object rotation (pinch / rotate overlay around the node).
- Each rotation step **writes** the tag (create or update **`direction`** / **`camera:direction`**) with the new bearing in degrees (same convention as today’s map preview and compass UI).
- Live preview: keep the on-map direction wedge aligned with the gesture while rotating.
- If the tag is removed or unparsable, fall back to today’s behavior (no rotate on node, or prompt to add direction first—pick one and document it).

**Why:** Mappers who already use area rotation muscle memory get a map-native way to aim benches, surveillance cameras, viewpoints, etc., without opening the POI sheet or holding the phone for compass capture—complementary to, not a replacement for, **`DirectionViewController`**.

**Scope (initial):** `direction` and `camera:direction` on **standalone nodes**; optional follow-up: extend to nodes that only infer direction from way geometry if that stays unambiguous.

---

## Traffic signs: build script, POI picker (`traffic_sign*`), map overlay

**Context:** Go Map!! already runs **prep scripts** before release—e.g. `src/presets/update.sh` (iD tagging schema) and `src/POI-Icons/update.sh` (preset icons). The app also resolves **map country** for presets (`currentRegion.country`, `CountryCoder` / `borders.json`). POI fields that support structured values already expose a **+** affordance that opens a picker (combo / semicolon-separated values).

**Package:** [@osm-traffic-signs/converter](https://www.npmjs.com/package/@osm-traffic-signs/converter) — catalog, search index, **compose** rules (country prefix e.g. `DE:`, semicolon-separated list, comma sub-parts), and **decompose** templates to split an existing `traffic_sign` value back into components.

**Catalog scope (initial):** Germany only; the npm package is country-scoped. More countries can follow as catalogs land in the package.

### 1. Build script (iOS asset pipeline)

Add a prep step alongside presets/icons (wire into `src/update_all.sh` when ready):

- Run Node, consume `@osm-traffic-signs/converter`, emit a **bundled index** for iOS (sign metadata, icons, search tokens, country codes, “frequently used” list).
- **Vendor the composition/decomposition rules** from the package so the app can **serialize** and **parse** tag values offline with the same semantics as the web tooling (correct `DE:` prefix, `;` between signs, `,` within compound signs).

### 2. POI editor: `+` on `traffic_sign`, `traffic_sign:forward`, `traffic_sign:backward`

**Show `+` only when** the current map country has a catalog entry (today: **DE**). Reuse existing country detection; hide the control elsewhere.

**Tap `+` → panel:**

| Region | Content |
|--------|---------|
| Top | **Search field** — query the bundled index |
| Below search | **Selected signs** — horizontal row of chosen items (chips / thumbnails) |
| Below selection | **Results** — **iOS grid** of matching signs; tap to add/remove from selection |

**Empty search:** list **frequently used** signs for the active country (from the index), not an empty grid.

**Apply:** write back a single tag value using the vendored **compose** rules.

**Editing an existing value:** on `+`, **decompose** the current string per package rules, run search/display **per component**, pre-fill the selected row. Components that are **not** in the catalog (free-text fragments in the value) must **not** be dropped—surface them as **“other”** entries in the selection row so mappers see and keep them.

Same UI for **`traffic_sign`**, **`traffic_sign:forward`**, and **`traffic_sign:backward`** (three independent fields where the preset/schema exposes them).

### 3. Display setting: show traffic signs on the map

Add a toggle in **display settings** next to the existing **highlight unknown roads** (or equivalent map-overlay section): **Show traffic signs**.

When **on**, the map renderer draws a compact **bead chain** of sign icons (stacked/overlapping miniatures, “pearls on a string”):

- **Nodes** with `traffic_sign=*` (or directional variants): chain at the **point**.
- **Ways** with sign tags: chain **along the way**, oriented with **line direction**.

**Directional tags:**

| Tags present | Map behavior |
|--------------|--------------|
| `traffic_sign:forward` / `:backward` | Show each chain in **that** travel direction along the way |
| Only one directional tag | Use it for its direction; fall back to undirected `traffic_sign` for the other if needed |
| Both directional + `traffic_sign` | **Directional values win** over the generic tag where they overlap |

Respect the same **country catalog** gate as the editor (no overlay where no icons/index exist).

**Why:** `traffic_sign` values are long, country-prefixed, and easy to mistype; the npm package already encodes valid composition. A picker plus optional map preview makes surveying and fixing sign tags practical without memorizing StVO codes.
