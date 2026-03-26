# macOS Quick Translate Polish Design

**Goal:** Evolve the current MVP into a stable, more native-feeling macOS quick-translate utility by fixing first-launch reliability, improving dismissal and animation behavior, resizing the overlay based on content, and adopting macOS 26 Liquid Glass styling where available.

## Scope

This design covers five requested improvements:

1. Adopt macOS 26 visual styling with Liquid Glass where supported
2. Close the overlay when clicking outside the window
3. Add lightweight motion
4. Resize the overlay according to translated text length
5. Fix the bug where the app exits on first launch and only launches correctly on the second attempt

## Priorities

Implementation order is intentionally staged:

1. **Stability first**
   Fix first-launch exit before adding more UI complexity.
2. **Interaction second**
   Improve close behavior, animation, and dynamic sizing on top of a stable startup path.
3. **Visual upgrade last**
   Add Liquid Glass only after the runtime behavior is dependable.

This keeps failure domains narrow and makes regressions easier to isolate.

## Architecture

The current app already has a clean enough split between workflow logic and presentation:

- `TranslateClipboardWorkflow` owns clipboard intake, policy, direction, and network call orchestration
- `OverlayPanelController` owns the AppKit panel lifecycle
- `OverlayContentView` and helper views render overlay states
- `AppDelegate` wires app lifecycle and hotkey registration

The polish work should preserve that split. Runtime behavior changes should stay close to `AppDelegate` and `OverlayPanelController`, while visual changes should stay inside the UI layer.

## Phase A: First-Launch Stability

### Problem

The first-launch exit strongly suggests a lifecycle timing issue rather than a translation issue. Likely causes include:

- hotkey registration running too early in app startup
- accessory activation policy interacting badly with launch timing
- panel/controller setup or event handler installation happening before the app is fully active

### Design

- Keep `AppDelegate` as the integration point
- Delay hotkey registration until the app has completed startup and the next run-loop turn if needed
- Separate "app launched successfully" from "shortcut is ready"
- Avoid creating or activating overlay UI during initial startup unless explicitly triggered

### Success Criteria

- First launch does not exit
- First launch can immediately accept the shortcut
- Subsequent launches behave the same as the first

## Phase B: Interaction and Motion

### Outside-Click Dismissal

The panel should close when the user clicks elsewhere, but not so aggressively that it disappears during its own presentation transition.

Design:

- Keep the existing focus-loss dismissal model
- Preserve the short grace period that prevents instant close on presentation
- Treat focus loss after the grace period as the standard click-away dismissal path

### Motion

Motion should feel native and restrained.

Design:

- Animate panel appearance with a subtle fade + slight scale
- Animate content-state transitions between `loading`, `result`, `error`, and `confirmLongText`
- Avoid springy or oversized motion that would fight the “quick utility” character

### Dynamic Sizing

The overlay should adapt to text length while staying predictable.

Design:

- Calculate a target content height from translated text length and line count heuristics
- Clamp to a minimum and maximum window height
- Keep scrolling for long content beyond the max height
- Resize only when the displayed state changes, not continuously while idle

### Success Criteria

- Click-away dismissal works naturally
- The overlay feels responsive, not abrupt
- Short results produce a compact overlay
- Long results grow the panel up to a ceiling, then scroll internally

## Phase C: macOS 26 Liquid Glass

### Goal

Adopt newer Apple visual language without breaking older compatible behavior.

### Design

- Use `#available(macOS 26, *)` to gate Liquid Glass styling
- Keep the existing overlay structure, but update the container and controls to use platform-appropriate materials and glass effects where available
- Prefer subtle system-native glass treatment over custom effects
- Preserve a compatible fallback path for older systems or unsupported environments

### Success Criteria

- macOS 26 gets a visually upgraded overlay aligned with current system design
- Non-macOS-26 paths still build and remain functional
- Liquid Glass does not change shortcut, translation, or dismissal behavior

## Testing Strategy

### Automated

- Add first-launch stability seam tests where possible around startup and hotkey registration
- Add deterministic tests for sizing policy calculations
- Add deterministic tests for dismissal grace-period logic
- Keep all existing workflow and client tests green

### Manual

- Cold launch the app and verify it stays alive
- Trigger translation immediately after cold launch
- Verify click-away dismissal
- Verify `Esc` dismissal still works
- Verify short, medium, and long text resize behavior
- On macOS 26, verify Liquid Glass is applied and readable

## Non-Goals

- No settings UI for customizing animations, materials, or shortcut
- No packaging/signing/notarization work in this polish pass
- No major workflow or API contract changes
