# Shortcut Panel Design

**Goal:** Replace the current menu-embedded shortcut recording flow with a
small dedicated shortcut panel that feels native to Glint, makes recording
clearer, and reduces configuration errors.

## Why This Change

The current shortcut configuration flow is functional but weak:

- shortcut recording happens inside the menu itself
- the menu enters a half-editing state that is easy to miss
- feedback is limited to short menu text changes
- duplicate or invalid shortcut outcomes are not explained well

This is a poor fit for a menu bar product. Menus work best for immediate
actions, not for short-lived editing workflows that need focus, validation, and
feedback.

## Product Direction

Glint should treat shortcut management as a small focused settings task:

- the menu bar menu opens the settings flow
- a separate utility panel owns the editing interaction
- the panel reuses Glint's existing motion language so it feels cohesive with
  the translation overlay

## User Experience

### Menu entry

Remove the current inline recorder entries:

- `Selection Shortcut: ...`
- `Clipboard Shortcut: ...`
- `Cancel Shortcut Recording`

Replace them with one stable item:

- `Keyboard Shortcuts…`

This keeps the menu clean and removes the split interaction model.

### Shortcut panel

Open a dedicated utility panel with:

1. Title: `Keyboard Shortcuts`
2. Supporting text describing what the panel does
3. Two shortcut rows:
   - `Translate Selection`
   - `Translate Clipboard`
4. A status message area
5. `Reset to Defaults`
6. `Done`

Each row contains a recorder-style control that shows either:

- the current shortcut
- the current recording prompt
- a warning or saved state through the shared status area

## Interaction Model

### Primary states

The panel only needs four states:

- `idle`
- `recording(selection)`
- `recording(clipboard)`
- `feedback(saved|error|warning)`

### Recording behavior

- Only one shortcut can be recorded at a time.
- Clicking a recorder puts that row into recording state.
- The active control changes to a `Type shortcut` style prompt.
- Pressing `Esc` cancels the active recording session.
- Clicking the other recorder switches focus cleanly.

### Validation behavior

Two validation tiers are needed:

1. **Hard error**
   - duplicate shortcut already used by the other Glint action
   - result: do not save

2. **Soft warning**
   - combination appears likely to conflict with a system shortcut pattern
   - result: allow save, but show clear warning

The panel should not surface Carbon or internal implementation terms.

### Success behavior

- Save immediately after a valid shortcut is recorded.
- Re-register the active hotkey immediately.
- Update the recorder control immediately.
- Show short-lived confirmation such as `Shortcut saved`.

### Reset behavior

- `Reset to Defaults` restores both shortcuts together.
- Re-register both active hotkeys immediately.
- Show `Defaults restored`.

## Visual and Motion Language

The panel should look like a native macOS utility panel with Glint's existing
motion sensibility, not like a full preferences window.

### Visual principles

- compact fixed-size window
- clear spacing between the two recorder rows
- obvious active recording state
- subdued secondary status text

### Motion principles

Reuse the overlay's existing interaction language:

- panel open: subtle fade + upward drift
- panel close: subtle fade + downward drift
- recorder active state: gentle background/border transition
- status text changes: short fade transition

The motion should be visible but restrained.

## Architecture

### New components

- `ShortcutPanelController`
  - owns the utility panel lifecycle and presentation
- `ShortcutPanelViewModel`
  - owns display state, recording target, validation feedback, and actions
- `ShortcutRecorderButton` or equivalent lightweight recorder view
  - renders current shortcut and active recording state

### Existing components reused

- `ShortcutRecorder`
- `ShortcutSettings`
- `GlobalHotkeyMonitor`
- AppDelegate hotkey reload wiring

The key design choice is to keep the existing hotkey storage and registration
pipeline, and only replace the UI and state coordination around recording.

## Error Handling

The panel should present user-facing messages such as:

- `Press a new shortcut, or Esc to cancel`
- `Shortcut saved`
- `This shortcut is already used by Glint`
- `This shortcut may conflict with a system shortcut`
- `Defaults restored`

Messages should be direct and product-facing.

## Testing Strategy

At minimum, add coverage for:

- panel view model idle and recording states
- duplicate-shortcut rejection
- reset-to-defaults behavior
- menu wiring showing only `Keyboard Shortcuts…`
- save flow reloading the active hotkeys

## Acceptance Criteria

- The menu no longer records shortcuts inline.
- The menu exposes one `Keyboard Shortcuts…` entry.
- A dedicated shortcut panel opens and closes cleanly.
- Both shortcut actions can be edited in the panel.
- Duplicate Glint shortcuts are rejected with a clear message.
- Restoring defaults updates both shortcuts and the live registrations.
- The panel motion feels aligned with the existing overlay motion language.
