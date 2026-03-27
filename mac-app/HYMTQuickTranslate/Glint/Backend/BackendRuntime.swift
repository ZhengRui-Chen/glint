import Foundation

protocol BackendRuntimeBuilding {
    func makeRuntime(settings: BackendSettings) -> BackendRuntime
}

struct BackendRuntime {
    let settings: BackendSettings
    let appConfig: AppConfig
    let translationClient: any TranslationClienting
    let statusMonitor: BackendStatusMonitor
    let controlService: (any BackendControlServicing)?

    var supportsManagedControlActions: Bool {
        controlService != nil
    }
}

struct DefaultBackendRuntimeBuilder: BackendRuntimeBuilding {
    let urlSession: URLSession
    let commandRunner: any ShellCommandRunning
    let now: @Sendable () -> Date
    let startupGracePeriod: TimeInterval
    let backendStatusMonitorOverride: BackendStatusMonitor?
    let backendControlServiceOverride: (any BackendControlServicing)?

    init(
        urlSession: URLSession = .shared,
        commandRunner: any ShellCommandRunning = ShellCommandRunner(),
        now: @escaping @Sendable () -> Date = Date.init,
        startupGracePeriod: TimeInterval = 15,
        backendStatusMonitorOverride: BackendStatusMonitor? = nil,
        backendControlServiceOverride: (any BackendControlServicing)? = nil
    ) {
        self.urlSession = urlSession
        self.commandRunner = commandRunner
        self.now = now
        self.startupGracePeriod = startupGracePeriod
        self.backendStatusMonitorOverride = backendStatusMonitorOverride
        self.backendControlServiceOverride = backendControlServiceOverride
    }

    func makeRuntime(settings: BackendSettings) -> BackendRuntime {
        let appConfig = AppConfig(settings: settings)
        let translationClient = LocalTranslationClient(settings: settings, session: urlSession)
        let statusMonitor = backendStatusMonitorOverride ?? BackendStatusMonitor(
            apiChecker: BackendAPIHealthChecker(urlSession: urlSession, config: appConfig),
            processChecker: processChecker(for: settings),
            now: now,
            startupGracePeriod: startupGracePeriod,
            checksProcessWhenAPIIsUnreachable: settings.mode == .managedLocal
        )
        let controlService = controlService(for: settings)

        return BackendRuntime(
            settings: settings,
            appConfig: appConfig,
            translationClient: translationClient,
            statusMonitor: statusMonitor,
            controlService: controlService
        )
    }

    private func processChecker(for settings: BackendSettings) -> any BackendProcessChecking {
        switch settings.mode {
        case .managedLocal:
            BackendProcessChecker(commandRunner: commandRunner)
        case .externalAPI:
            StaticBackendProcessChecker(isRunning: false)
        }
    }

    private func controlService(
        for settings: BackendSettings
    ) -> (any BackendControlServicing)? {
        switch settings.mode {
        case .managedLocal:
            backendControlServiceOverride ?? BackendControlService()
        case .externalAPI:
            nil
        }
    }
}

extension AppConfig {
    init(settings: BackendSettings) {
        self.init(
            baseURL: settings.baseURL,
            model: settings.model,
            apiKey: settings.apiKey,
            requestTimeout: AppConfig.default.requestTimeout,
            backendStatusRefreshInterval: AppConfig.default.backendStatusRefreshInterval,
            backendAPITimeout: AppConfig.default.backendAPITimeout
        )
    }
}
