import XCTest
@testable import HYMTQuickTranslate

final class AppLaunchCoordinatorTests: XCTestCase {
    func test_launch_coordinator_defers_hotkey_registration_until_app_is_ready() {
        let coordinator = AppLaunchCoordinator()
        XCTAssertFalse(coordinator.shouldRegisterHotkey(immediatelyAfterLaunch: true))
    }
}
