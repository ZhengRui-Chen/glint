# Glint Brand Refresh Design

**Date:** 2026-03-26

**Status:** Approved

**Goal:** Refresh the macOS app branding so the application icon, menu bar icon, and Xcode-facing project naming consistently reflect the `Glint` brand.

## Scope

This change covers three visible branding surfaces:

- macOS app icon asset catalog contents
- macOS menu bar status item icon and tooltip
- Xcode project, target, scheme, and test target names

This change does not alter:

- translation workflows
- API behavior
- shortcut behavior
- bundle signing setup beyond name-aligned identifiers

## Visual Direction

The approved direction is:

- minimal technology feel
- geometric lines with a small glint highlight
- reusable for both app icon and menu bar icon

The generated art should produce two derived assets:

1. **App Icon**
   A branded icon that keeps the Glint visual identity and reads clearly at macOS icon sizes.

2. **Menu Bar Icon**
   A monochrome template icon derived from the same logo. It should not hardcode a light or dark appearance. Instead, it should be exported as a simple single-color asset and marked as a template image in AppKit so macOS can render it correctly in the status bar.

## Naming Strategy

User-facing naming is already `Glint` in code and should remain so.

Internal Xcode naming should be aligned as well:

- project name: `Glint`
- app target name: `Glint`
- test target name: `GlintTests`
- built product names: `Glint.app` and `GlintTests.xctest`

This keeps Xcode, DerivedData outputs, and test imports aligned with the current brand instead of mixing legacy module names and `Glint`.

## Asset Strategy

Generate a single high-resolution logo source image with `nano-banana`, then derive:

- square PNG sizes for `AppIcon.appiconset`
- a simple PDF or PNG template asset for the menu bar icon

The menu bar icon should prioritize legibility at small sizes over fidelity to the full app icon. If necessary, the template version should simplify the logo by removing fill, background, or secondary details while preserving the core glint shape.

## Code Changes

`StatusBarController` currently uses a text title (`HY`) and a legacy tooltip. It should switch to:

- `NSImage`-backed status item artwork
- `image.isTemplate = true`
- tooltip text based on `AppBranding.displayName`

`MenuBarViewModel` should stop referencing the old display string in the quit label.

## Testing Strategy

Add a focused regression test for menu bar branding:

- no text title on the status item
- image exists on the status item button
- the image is configured as a template image

Verification should also include:

- full `xcodebuild test`
- generation and presence of expected icon assets
- successful app build after target and scheme rename
