# mac-app Flatten Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove the dead `HYMTQuickTranslate.xcodeproj` shell and flatten the active macOS app tree from `mac-app/HYMTQuickTranslate/` into `mac-app/`.

**Architecture:** Treat this as a path migration, not a behavior change. Move the live project, source, tests, and branding folders to `mac-app/`, then update every path consumer in scripts, docs, and Xcode project metadata, and finally rerun full macOS verification.

**Tech Stack:** Git worktrees, Xcode project metadata, zsh build script, Markdown docs, AppKit/Swift test suite

---

### Task 1: Lock the current baseline

**Files:**
- Verify: `mac-app/HYMTQuickTranslate/Glint.xcodeproj`
- Verify: `mac-app/HYMTQuickTranslate/Glint`
- Verify: `mac-app/HYMTQuickTranslate/GlintTests`

**Step 1: Run the full current macOS test suite**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
Expected: PASS with the current baseline before any move

**Step 2: Record the live directory layout**

Run: `find mac-app/HYMTQuickTranslate -maxdepth 2 -type d | sort`
Expected: shows `Branding`, `Glint`, `Glint.xcodeproj`, `GlintTests`, and the dead `HYMTQuickTranslate.xcodeproj`

**Step 3: Commit the design and plan docs**

```bash
git add docs/plans/2026-03-27-mac-app-flatten-design.md docs/plans/2026-03-27-mac-app-flatten.md
git commit -m "docs: add mac app flatten plan"
```

### Task 2: Move the live macOS app tree

**Files:**
- Move: `mac-app/HYMTQuickTranslate/Glint.xcodeproj`
- Move: `mac-app/HYMTQuickTranslate/Glint`
- Move: `mac-app/HYMTQuickTranslate/GlintTests`
- Move: `mac-app/HYMTQuickTranslate/Branding`
- Delete: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj`

**Step 1: Move the active directories to `mac-app/`**

Run:

```bash
mv mac-app/HYMTQuickTranslate/Glint.xcodeproj mac-app/Glint.xcodeproj
mv mac-app/HYMTQuickTranslate/Glint mac-app/Glint
mv mac-app/HYMTQuickTranslate/GlintTests mac-app/GlintTests
mv mac-app/HYMTQuickTranslate/Branding mac-app/Branding
rm -rf mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj
```

Expected: `mac-app/` directly contains the real project tree

**Step 2: Remove now-empty container directories**

Run: `find mac-app/HYMTQuickTranslate -depth -type d -empty -delete || true`
Expected: the historical container directory disappears if empty

**Step 3: Inspect post-move layout**

Run: `find mac-app -maxdepth 2 -type d | sort`
Expected: `mac-app/Glint.xcodeproj`, `mac-app/Glint`, `mac-app/GlintTests`, `mac-app/Branding`

### Task 3: Rewrite path consumers

**Files:**
- Modify: `scripts/build_mac_app.sh`
- Modify: `README.md`
- Modify: `README.en.md`
- Modify: `docs/plans/2026-03-27-vision-ocr.md`
- Modify: `docs/plans/2026-03-27-app-i18n-string-catalog.md`
- Modify: `docs/plans/2026-03-27-shortcut-panel.md`
- Modify: `docs/plans/2026-03-26-glint-brand-refresh.md`
- Modify: `docs/plans/2026-03-26-macos-quick-translate-polish.md`
- Modify: `docs/plans/2026-03-26-macos-quick-translate-dual-input.md`

**Step 1: Update the build script**

Change `PROJECT_PATH` from `mac-app/HYMTQuickTranslate/Glint.xcodeproj` to `mac-app/Glint.xcodeproj`.

**Step 2: Update user-facing README paths**

Replace all references to:

- `mac-app/HYMTQuickTranslate/Glint.xcodeproj`

with:

- `mac-app/Glint.xcodeproj`

**Step 3: Update retained plan/docs path references**

Replace all retained references to:

- `mac-app/HYMTQuickTranslate/Glint`
- `mac-app/HYMTQuickTranslate/GlintTests`
- `mac-app/HYMTQuickTranslate/Glint.xcodeproj`
- `mac-app/HYMTQuickTranslate/Branding`

with their `mac-app/` equivalents.

**Step 4: Verify no stale references remain**

Run: `rg -n "mac-app/HYMTQuickTranslate/(Glint\\.xcodeproj|Glint|GlintTests|Branding|HYMTQuickTranslate\\.xcodeproj)" README.md README.en.md scripts docs mac-app`
Expected: no matches

### Task 4: Verify Xcode project integrity after the move

**Files:**
- Verify: `mac-app/Glint.xcodeproj/project.pbxproj`

**Step 1: Open the project metadata for moved relative paths**

Run: `rg -n "HYMTQuickTranslate|GlintTests|Branding|Glint/" mac-app/Glint.xcodeproj/project.pbxproj`
Expected: paths are either absent or still valid relative to the new project location

**Step 2: Run a full test build against the new path**

Run: `xcodebuild test -project mac-app/Glint.xcodeproj -scheme Glint -destination 'platform=macOS'`
Expected: PASS

**Step 3: Run the build script**

Run: `zsh scripts/build_mac_app.sh`
Expected: PASS and prints `Built app at .../dist/Glint.app`

### Task 5: Final cleanup and commit

**Files:**
- Verify: `mac-app/`
- Verify: `README.md`
- Verify: `README.en.md`
- Verify: `scripts/build_mac_app.sh`
- Verify: `docs/plans/*.md`

**Step 1: Review the final diff surface**

Run: `git status --short && git diff --stat`
Expected: only the path flattening changes are present

**Step 2: Commit the refactor**

```bash
git add mac-app README.md README.en.md scripts/build_mac_app.sh docs/plans
git commit -m "refactor: flatten mac app project layout"
```
