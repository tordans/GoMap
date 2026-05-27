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
