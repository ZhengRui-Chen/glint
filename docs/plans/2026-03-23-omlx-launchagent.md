# oMLX LaunchAgent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a macOS LaunchAgent that keeps `omlx serve` running in the background and provide scripts to install, start, stop, restart, and inspect it.

**Architecture:** Use a launchd plist template that points at the existing `scripts/start_omlx.sh` entrypoint. Keep service configuration in the repository, and let small shell wrappers manage `launchctl` lifecycle operations for the current user.

**Tech Stack:** `zsh`, `launchctl`, `launchd`, existing `oMLX` service scripts.

---

### Task 1: Add LaunchAgent template

**Files:**
- Create: `launchd/com.hy-mt.omlx.plist.template`

**Step 1: Write the file**

Use a plist that runs `/bin/zsh` with `scripts/start_omlx.sh`, sets `RunAtLoad` and `KeepAlive`, and writes logs under `.runtime/omlx/logs/`.

**Step 2: Verify syntax**

Run: `plutil -lint launchd/com.hy-mt.omlx.plist.template`
Expected: `OK`

### Task 2: Add launchctl management scripts

**Files:**
- Create: `scripts/install_omlx_launch_agent.sh`
- Create: `scripts/start_omlx_launch_agent.sh`
- Create: `scripts/stop_omlx_launch_agent.sh`
- Create: `scripts/restart_omlx_launch_agent.sh`
- Create: `scripts/status_omlx_launch_agent.sh`
- Create: `scripts/uninstall_omlx_launch_agent.sh`

**Step 1: Write the scripts**

Implement idempotent `launchctl bootstrap`, `bootout`, `kickstart`, `print`, and uninstall behavior for `gui/$(id -u)/com.hy-mt.omlx`.

**Step 2: Verify behavior**

Run:
- `zsh scripts/install_omlx_launch_agent.sh`
- `zsh scripts/status_omlx_launch_agent.sh`

Expected: agent installs and reports a loaded oMLX service.

### Task 3: Document the new workflow

**Files:**
- Modify: `README.md`

**Step 1: Add a short LaunchAgent section**

Document how to install, start, stop, restart, and uninstall the agent.

**Step 2: Verify readability**

Open the updated README section and confirm the commands match the scripts.
