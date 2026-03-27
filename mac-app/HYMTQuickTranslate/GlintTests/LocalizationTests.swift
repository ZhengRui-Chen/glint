import XCTest
@testable import Glint

final class LocalizationTests: XCTestCase {
    func test_localization_helper_returns_non_empty_strings_for_current_locale() {
        XCTAssertFalse(L10n.translateSelection.isEmpty)
        XCTAssertFalse(L10n.translateClipboard.isEmpty)
        XCTAssertFalse(L10n.translateOCRArea.isEmpty)
        XCTAssertFalse(L10n.keyboardShortcuts.isEmpty)
        XCTAssertFalse(L10n.serviceStatusChecking.isEmpty)
        XCTAssertFalse(L10n.serviceStatusAvailable.isEmpty)
        XCTAssertFalse(L10n.backendReachable.isEmpty)
        XCTAssertTrue(
            L10n.accessibilityPermission(status: L10n.accessibilityPermissionRequired)
                .contains(L10n.accessibilityPermissionRequired)
        )
        XCTAssertTrue(L10n.quitApp(appName: "Glint").contains("Glint"))
    }

    func test_app_bundle_declares_all_supported_localizations() {
        let bundle = Bundle(for: AppDelegate.self)

        XCTAssertTrue(bundle.localizations.contains("en"))
        XCTAssertTrue(bundle.localizations.contains("zh-Hans"))
        XCTAssertTrue(bundle.localizations.contains("zh-Hant"))
    }

    func test_backend_status_snapshot_uses_localized_headlines() {
        XCTAssertEqual(BackendStatusSnapshot.checking().headline, L10n.serviceStatusChecking)
        XCTAssertEqual(
            BackendStatusSnapshot.available(detail: "ok").headline,
            L10n.serviceStatusAvailable
        )
        XCTAssertEqual(
            BackendStatusSnapshot.starting(detail: "wait").headline,
            L10n.serviceStatusStarting
        )
        XCTAssertEqual(
            BackendStatusSnapshot.unavailable(detail: "down").headline,
            L10n.serviceStatusUnavailable
        )
        XCTAssertEqual(
            BackendStatusSnapshot.error(detail: "boom").headline,
            L10n.serviceStatusError
        )
    }
}
