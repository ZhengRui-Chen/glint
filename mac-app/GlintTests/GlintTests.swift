import XCTest
@testable import Glint
#if canImport(Translation)
import Translation
#endif

final class GlintTests: XCTestCase {
    func test_app_branding_uses_glint_display_name() {
        XCTAssertEqual(AppBranding.displayName, "Glint")
    }

    func test_app_config_defaults_to_empty_runtime_api_settings() {
        let userDefaults = UserDefaults(suiteName: UUID().uuidString)!
        let config = AppConfig(settings: APISettingsStore(userDefaults: userDefaults).load())
        XCTAssertEqual(config.provider, .customAPI)
        XCTAssertEqual(config.baseURLString, "")
        XCTAssertEqual(config.apiKey, "")
        XCTAssertEqual(config.model, "")
    }

    #if canImport(Translation)
    @available(macOS 15.0, *)
    func test_system_translation_configuration_uses_automatic_source_language_detection() {
        let configuration = SystemTranslationSessionBroker.makeConfiguration(for: .zhToEn)

        XCTAssertNil(configuration.source)
        XCTAssertEqual(configuration.target, TranslationDirection.zhToEn.targetLocaleLanguage)
    }

    @available(macOS 15.0, *)
    func test_system_translation_configuration_invalidates_when_reusing_same_direction() {
        let current = SystemTranslationSessionBroker.makeConfiguration(for: .zhToEn)
        let next = SystemTranslationSessionBroker.nextConfiguration(
            from: current,
            for: .zhToEn
        )

        XCTAssertEqual(next.source, current.source)
        XCTAssertEqual(next.target, current.target)
        XCTAssertGreaterThan(next.version, current.version)
    }

    func test_system_translation_report_marks_downloadable_language_data() {
        let report = SystemTranslationAvailabilityReport.make(
            enToZh: .installed,
            zhToEn: .supported
        )

        XCTAssertEqual(
            report.summary,
            L10n.systemTranslationAvailabilityDownloadRequired
        )
        XCTAssertEqual(
            report.detailLines,
            [
                "\(L10n.systemTranslationDirectionEnglishToChinese): \(L10n.systemTranslationStatusInstalled)",
                "\(L10n.systemTranslationDirectionChineseToEnglish): \(L10n.systemTranslationStatusAvailableAfterDownload)"
            ]
        )
    }

    func test_system_translation_report_returns_direction_specific_state() {
        let report = SystemTranslationAvailabilityReport.make(
            enToZh: .installed,
            zhToEn: .supported
        )

        XCTAssertEqual(report.state(for: .enToZh), .installed)
        XCTAssertEqual(report.state(for: .zhToEn), .supported)
    }

    @available(macOS 15.0, *)
    func test_system_translation_only_cancels_for_active_host() {
        let activeHostID = UUID()
        let staleHostID = UUID()

        XCTAssertFalse(
            SystemTranslationSessionBroker.shouldCancelPendingRequest(
                for: staleHostID,
                activeHostID: activeHostID
            )
        )
        XCTAssertTrue(
            SystemTranslationSessionBroker.shouldCancelPendingRequest(
                for: activeHostID,
                activeHostID: activeHostID
            )
        )
    }

    @available(macOS 15.0, *)
    func test_system_translation_completed_request_keeps_configuration_for_reuse() {
        let current = SystemTranslationSessionBroker.makeConfiguration(for: .zhToEn)
        let next = SystemTranslationSessionBroker.configurationAfterCompletedRequest(current)

        XCTAssertNotNil(next)
        XCTAssertEqual(next?.source, current.source)
        XCTAssertEqual(next?.target, current.target)
        XCTAssertEqual(next?.version, current.version)
    }
    #endif
}
