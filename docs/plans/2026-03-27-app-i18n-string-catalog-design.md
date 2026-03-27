# App i18n String Catalog Design

**Goal:** Localize the macOS Glint app UI into English, Simplified Chinese, and Traditional Chinese using Apple's current recommended String Catalog workflow, while keeping language selection managed by macOS.

**Approach:** Replace hard-coded user-visible English strings in the app with Apple-native localizable string APIs. Use `Text("...")` for SwiftUI literals and `String(localized:)` for user-visible text produced in view models, workflows, AppKit menu wiring, and backend status messaging. Store translations in a single `Localizable.xcstrings` catalog attached to the app target.

**Scope:**
- Menu bar menu labels and backend status text
- Shortcut panel copy
- Overlay panel copy
- OCR selection overlay copy
- Settings scene copy
- Workflow error and validation messages
- Backend control progress/error messages

**Out of Scope:**
- README or docs localization
- In-app language switcher
- Region-specific formatting work beyond existing static copy

**Architecture:**
- Add a new `Localizable.xcstrings` resource to the `Glint` target.
- Introduce a small `L10n` helper for non-SwiftUI strings so the codebase does not scatter raw `String(localized:)` calls across dozens of files.
- Keep SwiftUI string literals localized natively where that remains straightforward.
- Keep English as the development language and provide explicit `zh-Hans` and `zh-Hant` translations in the catalog.

**Testing Strategy:**
- Add focused tests around localized string access for menu labels, backend headlines, and workflow messages.
- Update existing tests that currently assert raw English literals so they assert through the localized access points.
- Run the full `Glint` test suite after the migration.

**Risks and Mitigations:**
- `pbxproj` wiring for the new string catalog can be easy to miss.
  Mitigation: add the resource explicitly to the app target and verify with `xcodebuild test`.
- Dynamic strings like "Quit Glint" or permission labels can drift if format strings are inconsistent.
  Mitigation: centralize them behind helper accessors and test the rendered output.
- Some strings may remain hard-coded if only searched by exact text.
  Mitigation: sweep all user-visible strings across App, UI, MenuBar, Workflow, OCR, and Backend modules before verification.
