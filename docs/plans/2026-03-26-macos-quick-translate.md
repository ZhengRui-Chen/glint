# macOS Quick Translate Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a minimal native macOS companion app that translates clipboard text through the existing local `oMLX` API when the user presses a global shortcut, then shows the result in a temporary floating panel.

**Architecture:** Keep the current Python and `oMLX` service layer unchanged and add a new Swift macOS app under `mac-app/`. Put deterministic logic such as direction detection, threshold policy, request building, and response parsing behind unit tests, then wire that logic into a thin AppKit-backed workflow for shortcut handling and temporary panel presentation.

**Tech Stack:** Swift 6, SwiftUI, AppKit, XCTest, `URLSession`, Xcode macOS app target

---

### Task 1: Create the macOS app skeleton and test target

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/HYMTQuickTranslateApp.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppDelegate.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Config/AppConfig.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/HYMTQuickTranslateTests.swift`
- Modify: `README.md`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import HYMTQuickTranslate

final class HYMTQuickTranslateTests: XCTestCase {
    func test_app_config_uses_local_service_defaults() {
        let config = AppConfig.default
        XCTAssertEqual(config.baseURL.absoluteString, "http://127.0.0.1:8001")
        XCTAssertEqual(config.model, "HY-MT1.5-1.8B-4bit")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: FAIL because the project, target, or `AppConfig` does not exist yet.

**Step 3: Write minimal implementation**

```swift
struct AppConfig {
    let baseURL: URL
    let model: String

    static let `default` = AppConfig(
        baseURL: URL(string: "http://127.0.0.1:8001")!,
        model: "HY-MT1.5-1.8B-4bit"
    )
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS for the new default-config test.

**Step 5: Commit**

```bash
git add README.md mac-app/HYMTQuickTranslate
git commit -m "feat: add mac quick translate app skeleton"
```

### Task 2: Add clipboard intake, direction detection, and text-length policy

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Core/ClipboardTextReader.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Core/TranslationDirection.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Core/DirectionDetector.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Core/TextLengthPolicy.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/DirectionDetectorTests.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/TextLengthPolicyTests.swift`

**Step 1: Write the failing tests**

```swift
func test_direction_detector_prefers_en2zh_for_latin_text() {
    XCTAssertEqual(DirectionDetector.detect("Hello world"), .enToZh)
}

func test_direction_detector_prefers_zh2en_for_han_text() {
    XCTAssertEqual(DirectionDetector.detect("你好，世界"), .zhToEn)
}

func test_direction_detector_falls_back_to_en2zh_for_weak_signal() {
    XCTAssertEqual(DirectionDetector.detect("https://example.com"), .enToZh)
}

func test_text_length_policy_requires_confirmation_above_soft_limit() {
    let policy = TextLengthPolicy(softLimit: 2000, hardLimit: 8000)
    XCTAssertEqual(policy.evaluate(String(repeating: "a", count: 2001)), .needsConfirmation)
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/DirectionDetectorTests -only-testing:HYMTQuickTranslateTests/TextLengthPolicyTests`
Expected: FAIL because these types and behaviors do not exist yet.

**Step 3: Write minimal implementation**

```swift
enum TranslationDirection {
    case enToZh
    case zhToEn

    var targetLanguage: String {
        switch self {
        case .enToZh: return "中文"
        case .zhToEn: return "English"
        }
    }
}
```

Implement:

- `ClipboardTextReader.readString()` using `NSPasteboard.general.string(forType: .string)`
- `DirectionDetector.detect(_:)` with Han-vs-Latin heuristics
- `TextLengthPolicy.evaluate(_:)` returning `allowed`, `needsConfirmation`, or `rejected`

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/DirectionDetectorTests -only-testing:HYMTQuickTranslateTests/TextLengthPolicyTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add clipboard direction and threshold logic"
```

### Task 3: Add the local API client and payload/response tests

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Networking/ChatCompletionModels.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Networking/LocalTranslationClient.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Networking/TranslationPromptBuilder.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/TranslationPromptBuilderTests.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/LocalTranslationClientTests.swift`

**Step 1: Write the failing tests**

```swift
func test_prompt_builder_uses_translation_only_template() {
    let prompt = TranslationPromptBuilder.makePrompt(
        text: "It is a pleasure to meet you.",
        targetLanguage: "中文"
    )
    XCTAssertTrue(prompt.contains("只需要输出翻译后的结果"))
}

func test_client_decodes_first_choice_content() throws {
    let data = """
    {"choices":[{"message":{"content":"很高兴见到你。"}}]}
    """.data(using: .utf8)!
    let decoded = try LocalTranslationClient.decodeContent(from: data)
    XCTAssertEqual(decoded, "很高兴见到你。")
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/TranslationPromptBuilderTests -only-testing:HYMTQuickTranslateTests/LocalTranslationClientTests`
Expected: FAIL because prompt builder and client decoding do not exist.

**Step 3: Write minimal implementation**

```swift
struct TranslationPromptBuilder {
    static func makePrompt(text: String, targetLanguage: String) -> String {
        "将以下文本翻译为\(targetLanguage)，注意只需要输出翻译后的结果，不要额外解释：\n\n\(text)"
    }
}
```

Implement:

- request payload model for `/v1/chat/completions`
- response decoding for `choices[0].message.content`
- `LocalTranslationClient.translate(text:direction:) async throws -> String`
- timeout and base URL usage from `AppConfig`

**Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/TranslationPromptBuilderTests -only-testing:HYMTQuickTranslateTests/LocalTranslationClientTests`
Expected: PASS

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add local omlx translation client"
```

### Task 4: Add the translate-clipboard workflow and floating panel states

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Workflow/TranslateClipboardWorkflow.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayPanelController.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayContentView.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/UI/OverlayViewModel.swift`
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslateTests/TranslateClipboardWorkflowTests.swift`

**Step 1: Write the failing tests**

```swift
func test_workflow_returns_error_when_clipboard_is_empty() async {
    let workflow = TranslateClipboardWorkflow(
        clipboard: StubClipboard(text: nil),
        client: StubClient(),
        policy: .init(softLimit: 2000, hardLimit: 8000)
    )
    let state = await workflow.handleShortcut()
    XCTAssertEqual(state, .error("Clipboard does not contain text."))
}

func test_workflow_requires_confirmation_for_medium_text() async {
    let text = String(repeating: "a", count: 2001)
    let workflow = ...
    let state = await workflow.handleShortcut()
    XCTAssertEqual(state, .confirmLongText(text))
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS' -only-testing:HYMTQuickTranslateTests/TranslateClipboardWorkflowTests`
Expected: FAIL because the workflow and overlay state model do not exist.

**Step 3: Write minimal implementation**

```swift
enum OverlayViewState: Equatable {
    case loading
    case confirmLongText(String)
    case result(String)
    case error(String)
}
```

Implement:

- workflow orchestration for clipboard read, threshold check, direction detection, and API call
- confirmation path that reuses the same overlay state
- AppKit-backed floating panel controller
- SwiftUI view for loading, confirm, result, and error states
- close on `Esc` and click-away

**Step 4: Run tests and manual build verification**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS

Run: `xcodebuild build -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add mac-app/HYMTQuickTranslate
git commit -m "feat: add floating quick translate workflow"
```

### Task 5: Add global shortcut wiring, usage docs, and end-to-end verification

**Files:**
- Create: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/Hotkey/GlobalHotkeyMonitor.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/AppDelegate.swift`
- Modify: `mac-app/HYMTQuickTranslate/HYMTQuickTranslate/App/HYMTQuickTranslateApp.swift`
- Modify: `README.md`

**Step 1: Write the failing test or verification harness**

If the shortcut layer is difficult to unit test directly, add a small seam around the callback registration and test that triggering the callback invokes `TranslateClipboardWorkflow.handleShortcut()`.

```swift
func test_hotkey_callback_invokes_workflow() {
    let recorder = WorkflowRecorder()
    let monitor = GlobalHotkeyMonitor(onTrigger: recorder.record)
    monitor.invokeForTesting()
    XCTAssertEqual(recorder.callCount, 1)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: FAIL because the hotkey monitor seam does not exist.

**Step 3: Write minimal implementation**

Implement:

- a global shortcut monitor with a fixed default shortcut
- callback registration in `AppDelegate`
- launch-time setup for the overlay controller and workflow
- README section that explains:
  - how to open the Xcode project
  - how to run the app locally
  - required local `oMLX` service state
  - the default shortcut
  - threshold behavior

**Step 4: Run final verification**

Run: `xcodebuild test -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: PASS

Run: `xcodebuild build -project mac-app/HYMTQuickTranslate/HYMTQuickTranslate.xcodeproj -scheme HYMTQuickTranslate -destination 'platform=macOS'`
Expected: BUILD SUCCEEDED

Run: `uv run pytest`
Expected: PASS for the existing Python tests.

Manual verification:

- start local `oMLX` service
- copy `Hello world`
- press the default shortcut
- confirm the panel shows Chinese output
- copy `你好，世界`
- press the shortcut
- confirm the panel shows English output
- copy text with `2001` characters
- confirm the panel asks before translating
- stop the service
- press the shortcut again
- confirm the panel shows a service-unavailable error

**Step 5: Commit**

```bash
git add README.md mac-app/HYMTQuickTranslate
git commit -m "feat: wire mac quick translate shortcut"
```
