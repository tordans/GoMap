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
