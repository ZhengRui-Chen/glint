# Glint Brand Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the macOS app so its visual brand assets and Xcode project naming consistently use `Glint`.

**Architecture:** Keep the app behavior unchanged while refreshing branding in three layers: generated source art, derived Xcode asset catalog resources, and Xcode project naming. Drive the behavior-facing menu bar change with a failing test first, then update the project metadata and assets, and finally verify with tests and build commands.

**Tech Stack:** Swift 6, AppKit, XCTest, Xcode asset catalogs, `nano-banana`, shell image tooling

---

### Task 1: Add a regression test for Glint menu bar branding

**Files:**
- Modify: `mac-app/GlintTests/MenuBarViewModelTests.swift`
- Modify: `mac-app/Glint/MenuBar/StatusBarController.swift`
- Modify: `mac-app/Glint/Config/AppConfig.swift`

**Step 1: Write the failing test**

Add a test asserting that the status item:

- does not render the legacy `HY` title
- has an image on the button
- marks the image as a template image
- uses `Glint` in the tooltip

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests`

Expected: FAIL because the controller still uses a text title and the old tooltip.

**Step 3: Write minimal implementation**

Update `StatusBarController` to load a menu bar icon asset, clear the button title, set the tooltip from `AppBranding.displayName`, and mark the image as a template image.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS' -only-testing:GlintTests/MenuBarViewModelTests`

Expected: PASS

### Task 2: Generate and install Glint icon assets

**Files:**
- Modify: `mac-app/Glint/Assets.xcassets/AppIcon.appiconset/*`
- Create: `mac-app/Glint/Assets.xcassets/MenuBarIcon.imageset/Contents.json`
- Create: `mac-app/Glint/Assets.xcassets/MenuBarIcon.imageset/MenuBarIcon.png`

**Step 1: Generate the source logo**

Run `nano-banana` with a prompt that describes:

- minimal tech brand mark
- geometric lines
- small glint highlight
- strong silhouette
- white monochrome-compatible shape

**Step 2: Derive platform assets**

Generate:

- app icon PNGs for all existing `AppIcon.appiconset` slots
- a simplified monochrome menu bar icon asset

**Step 3: Update asset catalog metadata**

Ensure `Contents.json` includes the new menu bar image set and the app icon slots still match the generated files.

**Step 4: Verify resource presence**

Run: `find mac-app/Glint/Assets.xcassets -maxdepth 2 -type f | sort`

Expected: the refreshed app icon files and new `MenuBarIcon.imageset` files are present.

### Task 3: Rename the Xcode-facing project to Glint

**Files:**
- Modify: `mac-app/Glint.xcodeproj/project.pbxproj`
- Modify: `mac-app/Glint.xcodeproj/xcshareddata/xcschemes/Glint.xcscheme`
- Modify: `mac-app/GlintTests/*.swift`
- Modify: `mac-app/Glint/App/GlintApp.swift`

**Step 1: Write the failing change surface**

Rename the test module imports and app entry type references from the legacy app module names to `Glint`.

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: FAIL until the Xcode target, product, and scheme metadata are renamed consistently.

**Step 3: Write minimal implementation**

Update the project metadata so the project, app target, test target, product names, test host, scheme references, and Swift test module imports all align to `Glint`.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: PASS

### Task 4: Verify the full brand refresh

**Files:**
- Modify: `docs/plans/2026-03-26-glint-brand-refresh-design.md`
- Modify: `docs/plans/2026-03-26-glint-brand-refresh.md`

**Step 1: Run project tests**

Run: `uv run pytest -q`

Expected: PASS

**Step 2: Run macOS unit tests**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: PASS

**Step 3: Run app build**

Run: `xcodebuild build -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`

Expected: PASS

**Step 4: Record verification results**

Capture the final command outputs in the session summary and report any residual risks, such as the generated art still benefiting from manual visual review in Xcode.
