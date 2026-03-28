import SwiftUI
#if canImport(Translation)
@preconcurrency import Translation
#endif

struct OverlayContentView: View {
    static let usesAnimatedStateTransitions = false

    @ObservedObject var viewModel: OverlayViewModel
    @ObservedObject var backdropState: OverlayBackdropState
    private let visualStyle = OverlayVisualStyle.current

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
                .id(stateTransitionKey)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 460)
        .background(
            OverlayBackgroundView(
                visualStyle: visualStyle,
                averageLuminance: backdropState.averageLuminance
            )
        )
        .background(SystemTranslationTaskHost())
        .clipShape(RoundedRectangle(cornerRadius: OverlayVisualStyle.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView(L10n.translating)
                .progressViewStyle(.circular)
        case let .confirmLongText(text):
            Text(L10n.clipboardLongTextConfirmation)
                .font(.headline)
            Text(L10n.preview)
                .font(.subheadline)
                .foregroundStyle(visualStyle.secondaryTextColor)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 160)
            HStack {
                secondaryButton(L10n.cancel) {
                    viewModel.close()
                }
                primaryButton(L10n.translate) {
                    viewModel.confirmLongText()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .result(text):
            Text(L10n.translation)
                .font(.headline)
            SelectableTextView(text: text, visualStyle: visualStyle)
                .frame(maxHeight: 200)
            HStack {
                Spacer()
                primaryButton(L10n.close) {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        case let .error(message):
            Text(L10n.translationFailed)
                .font(.headline)
            SelectableTextView(text: message, visualStyle: visualStyle)
                .frame(minHeight: 72, maxHeight: 220)
            HStack {
                Spacer()
                primaryButton(L10n.close) {
                    viewModel.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var stateTransitionKey: String {
        switch viewModel.state {
        case .loading:
            return "loading"
        case let .confirmLongText(text):
            return "confirm-\(text)"
        case let .result(text):
            return "result-\(text)"
        case let .error(message):
            return "error-\(message)"
        }
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *), visualStyle == .liquidGlass {
            Button(title, action: action)
                .buttonStyle(.glassProminent)
        } else {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26, *), visualStyle == .liquidGlass {
            Button(title, action: action)
                .buttonStyle(.glass)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
        }
    }
}

enum SystemTranslationAvailabilityState: Equatable, Sendable {
    case installed
    case supported
    case unsupported
    case unavailable

    var localizedStatus: String {
        switch self {
        case .installed:
            L10n.systemTranslationStatusInstalled
        case .supported:
            L10n.systemTranslationStatusAvailableAfterDownload
        case .unsupported:
            L10n.systemTranslationStatusUnsupported
        case .unavailable:
            L10n.systemTranslationStatusUnavailable
        }
    }
}

struct SystemTranslationAvailabilityReport: Equatable, Sendable {
    let summary: String
    let detailLines: [String]
    let enToZh: SystemTranslationAvailabilityState
    let zhToEn: SystemTranslationAvailabilityState

    func state(for direction: TranslationDirection) -> SystemTranslationAvailabilityState {
        switch direction {
        case .enToZh:
            enToZh
        case .zhToEn:
            zhToEn
        }
    }

    static func checking() -> Self {
        Self(
            summary: L10n.systemTranslationAvailabilityChecking,
            detailLines: [],
            enToZh: .unavailable,
            zhToEn: .unavailable
        )
    }

    static func make(
        enToZh: SystemTranslationAvailabilityState,
        zhToEn: SystemTranslationAvailabilityState
    ) -> Self {
        let summary: String
        if enToZh == .unavailable || zhToEn == .unavailable {
            summary = L10n.systemTranslationAvailabilityUnavailable
        } else if enToZh == .unsupported || zhToEn == .unsupported {
            summary = L10n.systemTranslationAvailabilityUnsupported
        } else if enToZh == .installed && zhToEn == .installed {
            summary = L10n.systemTranslationAvailabilityReady
        } else {
            summary = L10n.systemTranslationAvailabilityDownloadRequired
        }

        return Self(
            summary: summary,
            detailLines: [
                "\(TranslationDirection.enToZh.systemTranslationAvailabilityLabel): \(enToZh.localizedStatus)",
                "\(TranslationDirection.zhToEn.systemTranslationAvailabilityLabel): \(zhToEn.localizedStatus)"
            ],
            enToZh: enToZh,
            zhToEn: zhToEn
        )
    }
}

protocol SystemTranslationAvailabilityInspecting: Sendable {
    func availabilityReport() async -> SystemTranslationAvailabilityReport
}

struct SystemTranslationAvailabilityInspector: SystemTranslationAvailabilityInspecting, Sendable {
    func availabilityReport() async -> SystemTranslationAvailabilityReport {
        guard #available(macOS 15.0, *) else {
            return .make(enToZh: .unavailable, zhToEn: .unavailable)
        }

        #if canImport(Translation)
        let availability = LanguageAvailability()
        let enToZhStatus = await availability.status(
            from: TranslationDirection.enToZh.sourceLocaleLanguage,
            to: TranslationDirection.enToZh.targetLocaleLanguage
        )
        let zhToEnStatus = await availability.status(
            from: TranslationDirection.zhToEn.sourceLocaleLanguage,
            to: TranslationDirection.zhToEn.targetLocaleLanguage
        )
        return .make(
            enToZh: Self.map(enToZhStatus),
            zhToEn: Self.map(zhToEnStatus)
        )
        #else
        return .make(enToZh: .unavailable, zhToEn: .unavailable)
        #endif
    }

    #if canImport(Translation)
    @available(macOS 15.0, *)
    private static func map(
        _ status: LanguageAvailability.Status
    ) -> SystemTranslationAvailabilityState {
        switch status {
        case .installed:
            return .installed
        case .supported:
            return .supported
        case .unsupported:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }
    #endif
}

@MainActor
@available(macOS 15.0, *)
final class SystemTranslationSessionBroker: ObservableObject {
    static let shared = SystemTranslationSessionBroker()
    private static let requestTimeout: Duration = .seconds(3)

    #if canImport(Translation)
    @Published fileprivate var configuration: TranslationSession.Configuration?
    #endif

    private var pendingRequest: PendingRequest?
    private var pendingTimeoutTask: Task<Void, Never>?
    private var activeHostID: UUID?

    private init() {}

    func translate(text: String, direction: TranslationDirection) async throws -> String {
        #if canImport(Translation)
        let availabilityState = await SystemTranslationAvailabilityInspector()
            .availabilityReport()
            .state(for: direction)
        if availabilityState == .unsupported || availabilityState == .unavailable {
            throw LocalTranslationClientError.systemTranslationUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            if let pendingRequest {
                pendingRequest.continuation.resume(
                    throwing: LocalTranslationClientError.systemTranslationFailed
                )
                self.pendingRequest = nil
            }

            let request = PendingRequest(
                id: UUID(),
                text: text,
                continuation: continuation
            )
            pendingRequest = request
            configuration = Self.nextConfiguration(from: configuration, for: direction)
            pendingTimeoutTask?.cancel()
            pendingTimeoutTask = makeTimeoutTask(for: request.id)
        }
        #else
        _ = text
        _ = direction
        throw LocalTranslationClientError.systemTranslationUnavailable
        #endif
    }

    #if canImport(Translation)
    @available(macOS 15.0, *)
    nonisolated static func makeConfiguration(
        for direction: TranslationDirection
    ) -> TranslationSession.Configuration {
        TranslationSession.Configuration(target: direction.targetLocaleLanguage)
    }

    @available(macOS 15.0, *)
    nonisolated static func nextConfiguration(
        from current: TranslationSession.Configuration?,
        for direction: TranslationDirection
    ) -> TranslationSession.Configuration {
        let desired = makeConfiguration(for: direction)
        guard var current else {
            return desired
        }

        if current.source == desired.source, current.target == desired.target {
            current.invalidate()
            return current
        }

        return desired
    }

    @available(macOS 15.0, *)
    nonisolated static func configurationAfterCompletedRequest(
        _ current: TranslationSession.Configuration?
    ) -> TranslationSession.Configuration? {
        current
    }

    nonisolated static func shouldCancelPendingRequest(
        for disappearingHostID: UUID,
        activeHostID: UUID?
    ) -> Bool {
        activeHostID == disappearingHostID
    }

    @available(macOS 15.0, *)
    fileprivate func handle(session: TranslationSession) async {
        guard let pendingRequest else {
            return
        }

        self.pendingRequest = nil
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = nil
        do {
            let response = try await session.translate(pendingRequest.text)
            pendingRequest.continuation.resume(returning: response.targetText)
        } catch let error as TranslationError {
            pendingRequest.continuation.resume(throwing: map(error))
        } catch {
            pendingRequest.continuation.resume(
                throwing: LocalTranslationClientError.systemTranslationFailed
            )
        }

        configuration = Self.configurationAfterCompletedRequest(configuration)
    }

    @available(macOS 15.0, *)
    private func map(_ error: TranslationError) -> LocalTranslationClientError {
        if #available(macOS 26.0, *), case .alreadyCancelled = error {
            return .systemTranslationFailed
        }

        switch error {
        case .unsupportedSourceLanguage,
             .unsupportedTargetLanguage,
             .unsupportedLanguagePairing,
             .unableToIdentifyLanguage,
             .nothingToTranslate,
             .internalError:
            return .systemTranslationFailed
        default:
            return .systemTranslationUnavailable
        }
    }
    #endif

    private func makeTimeoutTask(for requestID: UUID) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: Self.requestTimeout)
            await MainActor.run {
                guard let self,
                      let pendingRequest = self.pendingRequest,
                      pendingRequest.id == requestID else {
                    return
                }

                self.pendingRequest = nil
                self.pendingTimeoutTask = nil
                self.configuration = nil
                pendingRequest.continuation.resume(
                    throwing: LocalTranslationClientError.systemTranslationUnavailable
                )
            }
        }
    }

    fileprivate func activateHost(_ hostID: UUID) {
        activeHostID = hostID
    }

    fileprivate func deactivateHost(_ hostID: UUID) {
        guard Self.shouldCancelPendingRequest(
            for: hostID,
            activeHostID: activeHostID
        ) else {
            return
        }

        activeHostID = nil
        configuration = nil
        cancelPendingRequestIfNeeded()
    }

    private func cancelPendingRequestIfNeeded() {
        guard let pendingRequest else {
            return
        }

        self.pendingRequest = nil
        pendingTimeoutTask?.cancel()
        pendingTimeoutTask = nil
        configuration = nil
        pendingRequest.continuation.resume(
            throwing: LocalTranslationClientError.systemTranslationUnavailable
        )
    }

    private struct PendingRequest {
        let id: UUID
        let text: String
        let continuation: CheckedContinuation<String, Error>
    }
}

struct SystemTranslationTaskHost: View {
    var body: some View {
        Group {
            #if canImport(Translation)
            if #available(macOS 15.0, *) {
                SystemTranslationTaskHostContent()
            } else {
                EmptyView()
            }
            #else
            EmptyView()
            #endif
        }
    }
}

@available(macOS 15.0, *)
private struct SystemTranslationTaskHostContent: View {
    @ObservedObject private var broker = SystemTranslationSessionBroker.shared
    @State private var hostID = UUID()

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(broker.configuration) { session in
                await broker.handle(session: session)
            }
            .onAppear {
                broker.activateHost(hostID)
            }
            .onDisappear {
                broker.deactivateHost(hostID)
            }
    }
}
