# macOS Quick Translate Dual Input Design

**Date:** 2026-03-26

**Status:** Approved

**Goal:** Extend the current macOS quick-translate MVP into a dual-input utility that supports both clipboard translation and selected-text translation, with a menu bar control surface and independent configurable shortcuts.

## Scope

This design adds two major capabilities on top of the current MVP:

1. A menu bar interface for control and configuration
2. A second translation path that reads currently selected text instead of relying on the clipboard

The intended product shape becomes:

- Keep the existing clipboard translation path
- Add a new selected-text translation path
- Add a persistent status-bar control surface
- Let each path have its own shortcut

## Product Decision

The chosen product direction is **dual-path coexistence**:

- **Path A:** `Translate Clipboard`
- **Path B:** `Translate Selection`

This is intentionally not a replacement of the clipboard MVP. Clipboard translation remains the stable fallback interaction model, while selected-text translation becomes the higher-convenience path where host-app integration permits it.

## Why This Shape

This design is more robust than making selected-text translation the only primary interaction:

- clipboard translation already works and should not be discarded
- selected-text extraction has more system-permission and host-app compatibility risk
- a menu bar entry point is a natural place to expose permissions, shortcut state, and path-specific actions

This keeps the product practical even when selected-text capture is unavailable in some apps.

## Architecture

The existing app already separates translation workflow from UI reasonably well:

- `TranslateClipboardWorkflow` handles orchestration for text input, policy, direction, and API call
- `OverlayPanelController` handles panel presentation
- `AppDelegate` handles app lifecycle and hotkey registration

The dual-input version should generalize the workflow boundary:

### Input Source Layer

Introduce a shared text-input abstraction:

- `ClipboardInputSource`
- `SelectionInputSource`

The workflow should operate on **resolved input text**, not directly on `NSPasteboard`.

This keeps:

- clipboard-specific logic out of the general workflow
- selection-specific permission and extraction logic isolated
- both paths testable with stubs

### Trigger Layer

The app should support two distinct triggers:

- clipboard shortcut
- selection shortcut

Each trigger maps to a specific input source and a display preference:

- clipboard path: overlay defaults to centered display
- selection path: overlay prefers cursor-near positioning, with fallback to centered display

### Control Surface Layer

Add a menu bar item as the persistent control surface.

The menu bar layer owns:

- showing path actions
- showing configured shortcuts
- launching shortcut-recording flows
- displaying accessibility-permission state
- quit action

## Menu Bar Design

The first version should stay small and utility-focused.

Recommended menu layout:

- `Translate Selection`
- `Translate Clipboard`
- separator
- `Selection Shortcut: ...`
- `Clipboard Shortcut: ...`
- separator
- `Accessibility Permission: Granted / Required`
- `Quit`

This is intentionally a menu, not a full preferences window.

## Shortcut Configuration Design

The first release should allow both shortcuts to be configured.

Recommended interaction:

- selecting `Selection Shortcut: ...` enters a short recording mode
- selecting `Clipboard Shortcut: ...` enters a short recording mode
- the next valid key combination becomes the new shortcut
- duplicate assignments are rejected
- assignments are persisted locally

This avoids introducing a full settings UI while still solving the core need.

## Selected Text Translation Design

### Input Acquisition

Selected-text translation should use a dedicated `SelectionInputSource`.

Its responsibility:

- check accessibility permission
- inspect the current frontmost application
- attempt to read selected text through accessibility APIs

### Important Product Rule

If selected text is unavailable, the system should **not silently fall back to clipboard translation**.

Instead, it should present a clear error such as:

- `No selected text found.`
- `Selected text is unavailable in the current app.`
- `Accessibility permission is required for selection translation.`

This keeps the interaction transparent. A silent fallback could translate stale clipboard contents and feel incorrect.

### Overlay Positioning

The selection path should prefer showing the overlay near the user’s current focus region.

Preferred order:

1. Near the insertion point / selection anchor if obtainable
2. Near the current mouse cursor as a practical fallback
3. Centered on screen if positioning data is unavailable

Position failure must never block translation itself.

## Permissions Strategy

Selected-text translation requires a more privileged system integration path than clipboard reading.

Recommended behavior:

- do not force the permission prompt at app launch
- request or explain permissions only when the user first triggers `Translate Selection`
- keep menu bar permission state visible
- once granted, selection translation should work on the next trigger without extra setup

This avoids front-loading friction for clipboard-only users.

## Error Handling

Compared with the clipboard path, the selection path introduces extra failure modes:

- accessibility permission missing
- no current selected text
- host app does not expose selected text
- cursor/selection geometry unavailable

Recommended handling:

- missing permission: clear error plus permission status in menu bar
- no selected text: explicit short error
- unsupported host app: explicit short error
- geometry unavailable: still translate, but present the overlay centered
- translation/API errors: reuse the current overlay error model

## Compatibility Boundary

The first release should avoid fragile host-app-specific hacks.

Explicit non-goals for this design:

- app-specific selection adapters
- simulated `Cmd+C` copy-and-restore tricks
- clipboard mutation as an implementation detail of selection translation
- injected event hooks or application scripting hacks as the primary path

Reasoning:

- these approaches are harder to reason about
- they risk corrupting clipboard contents
- they make failures unpredictable
- they create debugging burden disproportionate to MVP value

The initial contract should be:

- if accessibility can expose selected text, translate it
- if it cannot, report that clearly

## Testing Strategy

### Automated

Add deterministic tests for:

- input-source routing
- selection-input permission failure behavior
- rejection of duplicate shortcut assignments
- cursor-position fallback selection
- workflow behavior for selected-text errors

### Manual

Verify:

- clipboard shortcut still works
- selection shortcut works in supported apps
- selection path reports missing permission correctly
- selection path reports unsupported host-app behavior clearly
- cursor-near overlay positioning works when location is available
- centered fallback still works when location is unavailable
- menu bar correctly shows both actions and permission state

## Documentation Impact

The user-facing docs should be updated to cover:

- menu bar behavior
- two independent shortcuts
- the requirement for accessibility permission for selection translation
- the fact that selected-text translation may not work uniformly in all host apps

## Non-Goals

This design does not include:

- translation history
- a full preferences window
- automatic selected-text fallback to clipboard
- host-app-specific deep integrations
- packaging/signing/notarization work
