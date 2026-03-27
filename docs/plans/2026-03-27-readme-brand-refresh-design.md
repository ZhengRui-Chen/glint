# README Brand Refresh Design

**Goal:** Reframe the repository homepage around the `Glint` product brand, add a logo at the top of the README, and split documentation into a Chinese primary README and an English secondary README.

## Why This Change

The current repository name and README tone still center the project around
`HY-MT MLX PoC`, which now misrepresents the product direction.

The repository has shifted toward:

- a branded macOS product: `Glint`
- a local translation workflow
- a personal-use project with self-hosted setup requirements

The README should communicate the product first and treat the current model and
backend stack as implementation details.

## Content Strategy

### Primary identity

- Repository brand: `Glint`
- Product framing: macOS local translation app backed by a local LLM service
- Current backend: `oMLX` + `HY-MT`
- Important nuance: the model is the current default backend, not the project identity

### Audience expectation

The README must clearly state near the top that:

- the project is maintained primarily for personal use
- there is no ready-to-download release build yet
- users must compile the macOS app and deploy the local backend themselves

This notice should appear before detailed setup instructions.

## Bilingual README Structure

### Chinese primary document

- File: `README.md`
- Role: primary project homepage
- Scope: complete setup and product explanation

Recommended structure:

1. Logo and project title
2. One-sentence product positioning
3. Personal-use / no-release / self-build notice
4. Chinese / English switch links
5. Product screenshot
6. Quick start
7. Glint app overview
8. Local backend and model setup
9. Project layout
10. Upstream acknowledgements

### English secondary document

- File: `README.en.md`
- Role: external-facing concise version
- Scope: same structure, slightly more compact prose

The English README should keep the same main sections so the two files do not
drift semantically, even if the Chinese version contains slightly more detail.

## Visual Assets

The top logo should not reference `.icns` directly from the Xcode bundle.
Instead, create stable documentation assets such as:

- `docs/assets/glint-logo.png`
- `docs/assets/glint-screenshot.png`

This keeps GitHub rendering stable and decouples README presentation from app
bundle resources.

## Messaging Principles

- Lead with product, not model internals.
- Use `Glint` as the main noun throughout the opening sections.
- Treat `HY-MT` and `oMLX` as current backend details.
- Keep the README practical and direct.
- Avoid claiming general availability or polished installation UX.

## Acceptance Criteria

- `README.md` opens with `Glint`, not `HY-MT MLX PoC`
- The top section includes logo and language switch links
- The personal-use / no-release / self-build message is prominent
- `README.en.md` exists and mirrors the main information architecture
- Quick start reflects the current Glint app plus local backend workflow
