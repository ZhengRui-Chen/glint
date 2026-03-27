# Vision OCR Design

**Goal:** Add an experimental OCR translation entry to Glint using Apple Vision, with area selection, a dedicated hotkey, and UI behavior aligned with the current overlay language.

**Approach:** Reuse the existing translation and overlay architecture. OCR becomes a third input path alongside clipboard and selection: capture a screen region, extract text with Vision, then send the recognized text through the existing translation workflow.

## User Experience

- Add a new menu action: `Translate OCR Area`.
- Add a new default hotkey: `Control + Option + Command + O`.
- Triggering OCR opens a full-screen selection surface.
- The user drags to define a capture region.
- The selection surface shows a subtle dimmed backdrop, a highlighted frame, and light motion when it appears and when the drag changes.
- Releasing the mouse captures that region, runs OCR, then shows the existing translation overlay.
- Escape cancels region selection without showing the translation overlay.

## Architecture

- Keep `TranslateTextWorkflow` as the shared translation engine.
- Add an OCR-specific input source that returns recognized text or a `TextInputFailure`.
- Add a small service layer around `VNRecognizeTextRequest` so OCR is testable without requiring Vision in unit tests.
- Add a dedicated screen-region picker panel/controller so screenshot interaction stays separate from the translation overlay.
- Wire OCR into `AppDelegate`, `MenuBarViewModel`, `StatusBarController`, and shortcut registration/recording.

## Capture And OCR Flow

1. User triggers OCR from the menu or hotkey.
2. App presents a non-destructive full-screen capture overlay.
3. User drags to create a region and releases.
4. Controller captures that region into `CGImage`.
5. OCR service runs `VNRecognizeTextRequest` against the image.
6. Recognized text is normalized and sent into `TranslateTextWorkflow`.
7. Existing overlay shows loading, result, long-text confirmation, or error.

## Error Handling

- Empty drag region: treat as cancel.
- Escape during selection: cancel silently.
- Screen capture failure: show `Unable to capture the selected area.`
- OCR returns no text: show `No text was recognized in the selected area.`
- OCR infrastructure failure: show `OCR is unavailable on this system.`
- Translation failures continue to use the current workflow messages.

## UI And Motion

- Match the current Glint style rather than introducing a new visual system.
- Selection overlay uses a soft dim layer plus a brighter rounded rectangle for the active region.
- Add small easing on overlay appearance and on selection updates; keep duration around the current `0.18s` family so it feels related to the existing translation panel.
- Keep copy concise and utility-focused.

## Testing Strategy

- Unit-test shortcut defaults and duplicate-shortcut protection with OCR added.
- Unit-test menu labels and action callbacks for the OCR entry.
- Unit-test OCR text normalization and OCR workflow result mapping through protocol seams.
- Unit-test app delegate hotkey registration behavior with the third hotkey monitor.
- Build and run the full macOS test suite after implementation.

## Non-Goals

- No persistent OCR history.
- No editable OCR text review screen before translation.
- No migration to ScreenCaptureKit in this experiment branch.
- No changes to backend translation protocol.
