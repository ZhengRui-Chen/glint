# README Backend Integration Design

**Goal:** Rework the README so backend onboarding starts from the app's HTTP contract, while clearly stating that this repository only ships and verifies the current `oMLX + HY-MT` backend path.

## Why This Change

The current README explains how to run the default local backend, but it does
not clearly separate:

- what `Glint` expects from any backend
- what this repository actually provides out of the box
- what a contributor must adapt when bringing a different backend

That makes backend onboarding slower than necessary and can leave readers with
the wrong impression that `Glint` is tightly coupled to `oMLX`.

## Documentation Strategy

### Contract first

The README should explain the backend in three layers:

1. `Glint` talks to a local OpenAI-compatible HTTP service
2. This repository only includes one concrete implementation path:
   `oMLX + HY-MT`
3. Other backends can work if they satisfy the same contract

This keeps the documentation honest without over-claiming multi-backend support
inside the repository.

### Keep Quick Start practical

The top-level quick start should still use the in-repo `oMLX` workflow because
it is the only implementation path that the repository currently ships,
documents, and smoke-tests.

### Add an explicit integration section

The README should gain a dedicated backend integration section that explains:

- default base URL
- authentication header
- required health-check endpoint
- required translation endpoint
- minimum response shape
- prompt expectations

## Product Constraints To Document

The documentation must reflect current runtime behavior rather than aspirational
configuration:

- `baseURL`, `model`, and `apiKey` are currently hard-coded in
  `AppConfig.default`
- the app checks backend reachability with `GET /v1/models`
- the app sends translation requests to `POST /v1/chat/completions`
- repository scripts only manage the `oMLX` backend flow

These constraints are important because they define what “compatible backend”
means today.

## Proposed README Structure

### Chinese primary README

1. Product overview
2. Quick start with the default in-repo backend
3. macOS app behavior
4. Backend integration
5. Default backend implementation in this repo
6. Bring your own backend
7. Verification commands
8. Model and prompt notes
9. Project layout
10. Upstream references

### English secondary README

Mirror the same structure and intent so the two documents stay aligned.

## Acceptance Criteria

- `README.md` clearly states that `Glint` depends on a local
  OpenAI-compatible backend contract
- `README.md` clearly states that this repository only ships the current
  `oMLX + HY-MT` implementation
- `README.md` includes a concrete compatibility checklist for custom backends
- `README.en.md` mirrors the same information architecture and constraints
- both READMEs describe the current hard-coded defaults accurately
