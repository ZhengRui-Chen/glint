# README Backend Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rewrite the bilingual README so contributors can understand Glint's backend contract quickly, while making it explicit that this repository only provides the current `oMLX + HY-MT` implementation path.

**Architecture:** Keep the work contained to documentation. Use the current application code as the source of truth for the backend contract, then restructure `README.md` and `README.en.md` so they separate protocol requirements, in-repo scripts, and custom backend responsibilities.

**Tech Stack:** Markdown, GitHub README rendering, Swift runtime config references, shell scripts

---

### Task 1: Document the current backend contract from code

**Files:**
- Reference: `mac-app/HYMTQuickTranslate/Glint/Config/AppConfig.swift`
- Reference: `mac-app/HYMTQuickTranslate/Glint/Networking/LocalTranslationClient.swift`
- Reference: `mac-app/HYMTQuickTranslate/Glint/Networking/ChatCompletionModels.swift`
- Reference: `mac-app/HYMTQuickTranslate/Glint/Backend/BackendHealthChecker.swift`

**Step 1: Extract the runtime defaults**

Record the current default values used by the app:
- `baseURL = http://127.0.0.1:8001`
- `model = HY-MT1.5-1.8B-4bit`
- `apiKey = local-hy-key`

**Step 2: Extract the required endpoints**

Record the current endpoint contract:
- `GET /v1/models` for health checks
- `POST /v1/chat/completions` for translation

**Step 3: Extract the minimum request and response shape**

Record the current request fields:
- `model`
- `messages`
- `max_tokens`
- `temperature`

Record the minimum response shape:
- `choices[0].message.content`

### Task 2: Rewrite the Chinese README around protocol-first onboarding

**Files:**
- Modify: `README.md`

**Step 1: Keep the existing product framing and quick start**

Preserve the current top-level product intro and keep `oMLX + HY-MT` as the
default runnable path.

**Step 2: Add a dedicated `Backend Integration` section**

Explain the app contract in practical terms:
- local OpenAI-compatible backend
- default address
- auth header
- required endpoints
- minimum JSON request and response shape

**Step 3: Add a dedicated `This Repo's Default Backend` section**

State clearly that the repository currently ships only:
- `configs/omlx.env`
- `scripts/start_omlx*.sh`
- `scripts/stop_omlx.sh`
- `scripts/restart_omlx.sh`
- `scripts/status_omlx.sh`
- `scripts/api_smoke.py`

**Step 4: Add a `Bring Your Own Backend` checklist**

List the exact compatibility requirements and call out the current hard-coded
defaults in the app.

### Task 3: Mirror the same structure in the English README

**Files:**
- Modify: `README.en.md`

**Step 1: Align section order with the Chinese README**

Keep the same information architecture so the documents do not drift.

**Step 2: Translate the new backend sections accurately**

Preserve the same technical statements for:
- contract
- repository scope
- custom backend checklist
- hard-coded defaults

### Task 4: Verify documentation accuracy

**Files:**
- Verify: `README.md`
- Verify: `README.en.md`

**Step 1: Review critical statements**

Confirm both READMEs state:
- Glint uses a local OpenAI-compatible backend contract
- the repository only ships the current `oMLX + HY-MT` implementation
- custom backends must satisfy the documented contract

**Step 2: Run baseline verification**

Run: `uv run pytest`

Expected: existing repository tests still pass

**Step 3: Review Markdown for command and path consistency**

Check that the two READMEs reference the same scripts, paths, and defaults.
