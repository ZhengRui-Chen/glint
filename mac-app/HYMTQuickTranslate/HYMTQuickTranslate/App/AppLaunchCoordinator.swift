struct AppLaunchCoordinator {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool {
        immediatelyAfterLaunch == false
    }
}
