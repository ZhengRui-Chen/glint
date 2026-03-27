# README Brand Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rework the repository README into a `Glint`-first bilingual documentation set with a top logo, clear personal-use expectations, and separate Chinese and English entry points.

**Architecture:** Keep the README rewrite contained to documentation files and stable docs assets. Use `README.md` as the Chinese primary homepage, add `README.en.md` as the English secondary document, and introduce dedicated logo/screenshot assets under `docs/assets` so the homepage does not depend on Xcode-only resources.

**Tech Stack:** Markdown, GitHub README rendering, PNG docs assets

---

### Task 1: Prepare stable README assets

**Files:**
- Create: `docs/assets/glint-logo.png`
- Create: `docs/assets/glint-screenshot.png`

**Step 1: Export a README-safe logo**

Use the approved `Glint` branding asset as the source and export a PNG sized for
GitHub README display.

**Step 2: Capture or prepare a product screenshot**

Create one screenshot that clearly shows either:
- the menu bar menu with backend status, or
- the translation overlay

**Step 3: Verify assets render cleanly in Markdown**

Check that both assets can be embedded with relative paths and look correct in a
GitHub-style README.

**Step 4: Commit**

```bash
git add docs/assets/glint-logo.png docs/assets/glint-screenshot.png
git commit -m "docs: add glint readme assets"
```

### Task 2: Rewrite the Chinese primary README

**Files:**
- Modify: `README.md`

**Step 1: Replace the current title block**

Change the opening from `HY-MT MLX PoC` to a `Glint`-first header with:
- logo
- product title
- one-line positioning
- language switch links

**Step 2: Add the expectation-setting notice**

Insert a prominent notice near the top that states:
- the project is maintained primarily for personal use
- there is no ready-to-download release build yet
- users must build and deploy it themselves

**Step 3: Restructure the document**

Reorder the document so it flows as:
1. Product intro
2. Quick start
3. macOS app usage
4. Local backend setup
5. Model and prompt notes
6. Project layout
7. Upstream acknowledgements

**Step 4: Reword model/backend sections**

Keep `HY-MT` and `oMLX`, but present them as the current backend stack rather
than the repository identity.

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: rewrite chinese readme for glint"
```

### Task 3: Add the English secondary README

**Files:**
- Create: `README.en.md`

**Step 1: Mirror the Chinese information architecture**

Use the same top-level structure as `README.md` so both documents stay aligned.

**Step 2: Keep English prose concise**

Preserve the same facts, but write a slightly shorter external-facing version.

**Step 3: Include language switch links**

Make sure `README.md` links to `README.en.md`, and `README.en.md` links back to
`README.md`.

**Step 4: Commit**

```bash
git add README.en.md README.md
git commit -m "docs: add english readme"
```

### Task 4: Verify documentation consistency

**Files:**
- Verify: `README.md`
- Verify: `README.en.md`
- Verify: `docs/assets/glint-logo.png`
- Verify: `docs/assets/glint-screenshot.png`

**Step 1: Review critical statements**

Confirm both READMEs consistently state:
- personal use
- no downloadable release
- self-build and self-deploy requirement

**Step 2: Review setup commands**

Confirm both READMEs point to the current Glint project path:
- `mac-app/HYMTQuickTranslate/Glint.xcodeproj`

**Step 3: Build the app to validate referenced workflow**

Run: `zsh scripts/build_mac_app.sh`

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add README.md README.en.md docs/assets
git commit -m "docs: polish glint readme set"
```
