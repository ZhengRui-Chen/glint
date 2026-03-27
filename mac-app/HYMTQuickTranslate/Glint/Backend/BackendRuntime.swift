import Foundation

protocol BackendRuntimeBuilding {
    func makeRuntime(settings: BackendSettings) -> BackendRuntime
}

struct BackendRuntime {
    let settings: BackendSettings
    let appConfig: AppConfig
    let translationClient: any TranslationClienting
    let statusMonitor: BackendStatusMonitor
}

struct DefaultBackendRuntimeBuilder: BackendRuntimeBuilding {
    let urlSession: URLSession
    let commandRunner: any ShellCommandRunning
    let now: @Sendable () -> Date
    let startupGracePeriod: TimeInterval
    let backendStatusMonitorOverride: BackendStatusMonitor?

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
    }

    func makeRuntime(settings: BackendSettings) -> BackendRuntime {
        let appConfig = AppConfig(settings: settings)
        let translationClient = LocalTranslationClient(settings: settings, session: urlSession)
        let statusMonitor = backendStatusMonitorOverride ?? BackendStatusMonitor(
            apiChecker: BackendAPIHealthChecker(urlSession: urlSession, config: appConfig),
            processChecker: processChecker(),
            now: now,
            startupGracePeriod: startupGracePeriod,
            checksProcessWhenAPIIsUnreachable: false
        )

        return BackendRuntime(
            settings: settings,
            appConfig: appConfig,
            translationClient: translationClient,
            statusMonitor: statusMonitor
        )
    }

    private func processChecker() -> any BackendProcessChecking {
        StaticBackendProcessChecker(isRunning: false)
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
