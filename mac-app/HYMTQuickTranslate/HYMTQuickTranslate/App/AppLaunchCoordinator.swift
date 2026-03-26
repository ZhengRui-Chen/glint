protocol AppLaunchCoordinating: Sendable {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool
}

struct AppLaunchCoordinator: AppLaunchCoordinating {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool {
        immediatelyAfterLaunch == false
    }
}
