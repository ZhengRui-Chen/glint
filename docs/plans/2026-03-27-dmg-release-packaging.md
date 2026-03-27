# DMG Release Packaging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a minimal DMG packaging workflow for ordinary macOS release distribution.

**Architecture:** Keep `.app` build and `.dmg` packaging as separate scripts. Extend the existing app build script to accept a build configuration, then let a new DMG script call it with `Release`, stage `Glint.app` plus an `Applications` symlink, and create `dist/Glint.dmg` with `hdiutil`.

**Tech Stack:** zsh, xcodebuild, hdiutil, README documentation

---

### Task 1: Add a failing DMG smoke test

**Files:**
- Create: `scripts/tests/build_dmg_smoke_test.sh`

**Step 1: Write the failing test**

Create a shell smoke test that:
- removes any stale `dist/Glint.dmg`
- runs `zsh scripts/build_dmg.sh`
- asserts `dist/Glint.dmg` exists
- runs `hdiutil imageinfo dist/Glint.dmg`

**Step 2: Run test to verify it fails**

Run: `zsh scripts/tests/build_dmg_smoke_test.sh`
Expected: FAIL because `scripts/build_dmg.sh` does not exist yet.

### Task 2: Extend app build script for release configuration

**Files:**
- Modify: `scripts/build_mac_app.sh`

**Step 1: Write minimal implementation**

Update the script to honor `CONFIGURATION`, defaulting to `Debug`, and derive the source
app path from that configuration.

**Step 2: Run focused verification**

Run: `CONFIGURATION=Release zsh scripts/build_mac_app.sh`
Expected: `dist/Glint.app` is produced from the `Release` build path.

### Task 3: Implement DMG packaging

**Files:**
- Create: `scripts/build_dmg.sh`

**Step 1: Write minimal implementation**

Implement a zsh script that:
- calls `CONFIGURATION=Release zsh scripts/build_mac_app.sh`
- stages `Glint.app` and an `Applications` symlink in a temporary directory
- removes any stale `dist/Glint.dmg`
- runs `hdiutil create` to generate `dist/Glint.dmg`

**Step 2: Run the smoke test again**

Run: `zsh scripts/tests/build_dmg_smoke_test.sh`
Expected: PASS.

### Task 4: Document release packaging

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`

**Step 1: Update docs**

Add a short section showing how to build the release DMG and what file is produced.

**Step 2: Re-run packaging verification**

Run: `zsh scripts/build_dmg.sh`
Expected: `dist/Glint.dmg` is refreshed successfully.

### Task 5: Final verification

**Files:**
- Verify only

**Step 1: Run app test suite**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
Expected: PASS.

**Step 2: Run DMG smoke test**

Run: `zsh scripts/tests/build_dmg_smoke_test.sh`
Expected: PASS.

**Step 3: Confirm image metadata**

Run: `hdiutil imageinfo dist/Glint.dmg`
Expected: exit code 0 with image metadata output.
