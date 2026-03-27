import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Glint

final class ShortcutRecorderTests: XCTestCase {
    @MainActor
    func test_app_delegate_registers_selection_hotkeys_after_task6() {
        let clipboardMonitor = TestHotkeyMonitor()
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: #function)!,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        XCTAssertEqual(
            clipboardMonitor.events,
            [.start(ShortcutSettings.default.clipboardShortcut)]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [.start(ShortcutSettings.default.selectionShortcut)]
        )
        XCTAssertNotNil(appDelegate.clipboardHotkeyMonitorForTesting())
        XCTAssertNotNil(appDelegate.selectionHotkeyMonitorForTesting())
        XCTAssertEqual(
            ocrMonitor.events,
            [.start(ShortcutSettings.default.ocrShortcut)]
        )
        XCTAssertNotNil(appDelegate.ocrHotkeyMonitorForTesting())
    }

    func test_recorder_persists_updated_shortcut_settings() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let newShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let recorder = ShortcutRecorder(
            existingSettings: .default,
            userDefaults: userDefaults
        )

        let result = recorder.save(newShortcut, for: .ocr)
        let updatedSettings = try XCTUnwrap(try? result.get())

        XCTAssertEqual(updatedSettings.ocrShortcut, newShortcut)
        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), updatedSettings)
    }

    func test_recorder_rejects_duplicate_shortcuts() {
        let settings = ShortcutSettings.default
        let recorder = ShortcutRecorder(existingSettings: settings)
        let result = recorder.validate(settings.clipboardShortcut, for: .ocr)

        XCTAssertEqual(result, .failure(.duplicateShortcut))
    }

    func test_shortcut_from_rejects_bare_key_presses() throws {
        let event = try XCTUnwrap(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "t",
                charactersIgnoringModifiers: "t",
                isARepeat: false,
                keyCode: UInt16(kVK_ANSI_T)
            )
        )

        XCTAssertNil(ShortcutRecorder.shortcut(from: event))
    }

    @MainActor
    func test_recording_stops_active_clipboard_hotkey_and_restarts_it_on_cancel() {
        let clipboardMonitor = TestHotkeyMonitor()
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: UserDefaults(suiteName: #function)!,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        appDelegate.beginShortcutRecording(for: .selection)
        appDelegate.cancelShortcutRecording()

        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(ShortcutSettings.default.clipboardShortcut),
                .stop,
                .reload(ShortcutSettings.default.clipboardShortcut),
            ]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(ShortcutSettings.default.selectionShortcut),
                .stop,
                .reload(ShortcutSettings.default.selectionShortcut),
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(ShortcutSettings.default.ocrShortcut),
                .stop,
                .reload(ShortcutSettings.default.ocrShortcut),
            ]
        )
    }

    @MainActor
    func test_clipboard_shortcut_is_not_persisted_when_active_hotkey_apply_fails() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let candidateShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let clipboardMonitor = TestHotkeyMonitor(reloadResults: [false])
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        appDelegate.beginShortcutRecording(for: .clipboard)
        appDelegate.applyRecordedShortcut(candidateShortcut)

        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), .default)
        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(ShortcutSettings.default.clipboardShortcut),
                .stop,
                .reload(candidateShortcut),
            ]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(ShortcutSettings.default.selectionShortcut),
                .stop,
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(ShortcutSettings.default.ocrShortcut),
                .stop,
            ]
        )
    }

    @MainActor
    func test_shortcut_panel_save_persists_and_reloads_live_hotkey() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let candidateShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let clipboardMonitor = TestHotkeyMonitor()
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let panel = appDelegate.shortcutPanelControllerForTesting()
        panel.requestStartRecording(for: .clipboard)
        panel.requestApplyRecordedShortcut(candidateShortcut)

        XCTAssertEqual(
            ShortcutSettings.load(from: userDefaults),
            ShortcutSettings(
                clipboardShortcut: candidateShortcut,
                selectionShortcut: .selectionDefault
            )
        )
        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(ShortcutSettings.default.clipboardShortcut),
                .reload(candidateShortcut)
            ]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(ShortcutSettings.default.selectionShortcut)
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(ShortcutSettings.default.ocrShortcut)
            ]
        )

        let state = panel.testingSnapshot
        XCTAssertNil(state.recordingTarget)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            candidateShortcut.displayName
        )
        XCTAssertEqual(state.statusMessage, "Shortcut saved")
    }

    @MainActor
    func test_shortcut_panel_save_keeps_settings_unchanged_when_live_reload_fails() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let candidateShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_X),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
        let clipboardMonitor = TestHotkeyMonitor(reloadResults: [false])
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: .default,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let panel = appDelegate.shortcutPanelControllerForTesting()
        panel.requestStartRecording(for: .clipboard)
        panel.requestApplyRecordedShortcut(candidateShortcut)

        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), .default)
        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(ShortcutSettings.default.clipboardShortcut),
                .reload(candidateShortcut),
                .start(ShortcutSettings.default.clipboardShortcut)
            ]
        )

        let state = panel.testingSnapshot
        XCTAssertEqual(state.recordingTarget, .clipboard)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            ShortcutSettings.default.clipboardShortcut.displayName
        )
        XCTAssertEqual(
            state.statusMessage,
            "Shortcut could not be registered. Try another combination."
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(ShortcutSettings.default.selectionShortcut)
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(ShortcutSettings.default.ocrShortcut)
            ]
        )
    }

    @MainActor
    func test_shortcut_panel_reset_restores_defaults_and_live_registrations() throws {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let savedSettings = ShortcutSettings(
            clipboardShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_T),
                modifiers: UInt32(controlKey | optionKey)
            ),
            selectionShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_Y),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            )
        )
        savedSettings.save(to: userDefaults)

        let clipboardMonitor = TestHotkeyMonitor(startResults: [true], reloadResults: [true])
        let selectionMonitor = TestHotkeyMonitor(startResults: [true], reloadResults: [true])
        let ocrMonitor = TestHotkeyMonitor(startResults: [true], reloadResults: [true])
        let appDelegate = AppDelegate(
            shortcutSettings: savedSettings,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let panel = appDelegate.shortcutPanelControllerForTesting()
        panel.requestStartRecording(for: .clipboard)
        panel.requestResetToDefaults()

        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), .default)
        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(savedSettings.clipboardShortcut),
                .reload(ShortcutSettings.default.clipboardShortcut)
            ]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(savedSettings.selectionShortcut),
                .reload(ShortcutSettings.default.selectionShortcut)
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(savedSettings.ocrShortcut),
                .reload(ShortcutSettings.default.ocrShortcut)
            ]
        )
        XCTAssertTrue(clipboardMonitor.isRunningForTesting)
        XCTAssertTrue(selectionMonitor.isRunningForTesting)
        XCTAssertTrue(ocrMonitor.isRunningForTesting)
        XCTAssertEqual(clipboardMonitor.activeShortcutForTesting, ShortcutSettings.default.clipboardShortcut)
        XCTAssertEqual(selectionMonitor.activeShortcutForTesting, ShortcutSettings.default.selectionShortcut)
        XCTAssertEqual(ocrMonitor.activeShortcutForTesting, ShortcutSettings.default.ocrShortcut)

        let state = panel.testingSnapshot
        XCTAssertNil(state.recordingTarget)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            ShortcutSettings.default.clipboardShortcut.displayName
        )
        XCTAssertEqual(
            state.selectionShortcutLabel,
            ShortcutSettings.default.selectionShortcut.displayName
        )
        XCTAssertEqual(
            state.ocrShortcutLabel,
            ShortcutSettings.default.ocrShortcut.displayName
        )
        XCTAssertEqual(state.statusMessage, "Defaults restored")
    }

    @MainActor
    func test_shortcut_panel_reset_preserves_live_consistency_when_clipboard_rollback_fails() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let savedSettings = ShortcutSettings(
            clipboardShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_T),
                modifiers: UInt32(controlKey | optionKey)
            ),
            selectionShortcut: GlobalHotkeyShortcut(
                keyCode: UInt32(kVK_ANSI_Y),
                modifiers: UInt32(controlKey | optionKey | cmdKey)
            )
        )
        savedSettings.save(to: userDefaults)

        let clipboardMonitor = TestHotkeyMonitor(reloadResults: [true, false, true])
        let selectionMonitor = TestHotkeyMonitor(
            startResults: [true, false],
            reloadResults: [false, true]
        )
        let ocrMonitor = TestHotkeyMonitor(
            startResults: [true, false],
            reloadResults: [false, true]
        )
        let appDelegate = AppDelegate(
            shortcutSettings: savedSettings,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        let panel = appDelegate.shortcutPanelControllerForTesting()
        panel.requestResetToDefaults()

        XCTAssertEqual(
            ShortcutSettings.load(from: userDefaults),
            savedSettings
        )
        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(savedSettings.clipboardShortcut),
                .reload(ShortcutSettings.default.clipboardShortcut),
                .reload(savedSettings.clipboardShortcut),
                .start(ShortcutSettings.default.clipboardShortcut),
                .stop,
                .start(savedSettings.clipboardShortcut)
            ]
        )
        XCTAssertEqual(
            selectionMonitor.events,
            [
                .start(savedSettings.selectionShortcut),
                .reload(ShortcutSettings.default.selectionShortcut),
                .start(savedSettings.selectionShortcut),
                .reload(savedSettings.selectionShortcut),
                .stop,
                .start(savedSettings.selectionShortcut)
            ]
        )
        XCTAssertEqual(
            ocrMonitor.events,
            [
                .start(savedSettings.ocrShortcut),
                .reload(ShortcutSettings.default.ocrShortcut),
                .start(savedSettings.ocrShortcut),
                .start(savedSettings.ocrShortcut),
                .stop,
                .start(savedSettings.ocrShortcut)
            ]
        )
        XCTAssertTrue(clipboardMonitor.isRunningForTesting)
        XCTAssertTrue(selectionMonitor.isRunningForTesting)
        XCTAssertTrue(ocrMonitor.isRunningForTesting)
        XCTAssertEqual(clipboardMonitor.activeShortcutForTesting, savedSettings.clipboardShortcut)
        XCTAssertEqual(selectionMonitor.activeShortcutForTesting, savedSettings.selectionShortcut)
        XCTAssertEqual(ocrMonitor.activeShortcutForTesting, savedSettings.ocrShortcut)

        let state = panel.testingSnapshot
        XCTAssertNil(state.recordingTarget)
        XCTAssertEqual(
            state.clipboardShortcutLabel,
            savedSettings.clipboardShortcut.displayName
        )
        XCTAssertEqual(
            state.selectionShortcutLabel,
            savedSettings.selectionShortcut.displayName
        )
        XCTAssertEqual(
            state.ocrShortcutLabel,
            savedSettings.ocrShortcut.displayName
        )
        XCTAssertEqual(state.statusMessage, "Defaults could not be restored.")
    }

    @MainActor
    func test_launch_resets_clipboard_shortcut_to_default_when_saved_shortcut_cannot_be_registered() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let savedShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(controlKey | optionKey)
        )
        let savedSettings = ShortcutSettings(
            clipboardShortcut: savedShortcut,
            selectionShortcut: .selectionDefault
        )
        savedSettings.save(to: userDefaults)

        let clipboardMonitor = TestHotkeyMonitor(startResults: [false], reloadResults: [true])
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: savedSettings,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(savedShortcut),
                .reload(.default),
            ]
        )
        XCTAssertEqual(
            ShortcutSettings.load(from: userDefaults),
            ShortcutSettings(
                clipboardShortcut: .default,
                selectionShortcut: .selectionDefault
            )
        )
        XCTAssertEqual(
            appDelegate.shortcutStatusLabelForTesting(),
            "Clipboard shortcut was reset to the default because the saved combination could not be registered."
        )
    }

    @MainActor
    func test_launch_shows_error_when_clipboard_shortcut_and_default_both_fail() {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer {
            userDefaults.removePersistentDomain(forName: #function)
        }

        let savedShortcut = GlobalHotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(controlKey | optionKey)
        )
        let savedSettings = ShortcutSettings(
            clipboardShortcut: savedShortcut,
            selectionShortcut: .selectionDefault
        )

        let clipboardMonitor = TestHotkeyMonitor(startResults: [false], reloadResults: [false])
        let selectionMonitor = TestHotkeyMonitor()
        let ocrMonitor = TestHotkeyMonitor()
        let appDelegate = AppDelegate(
            shortcutSettings: savedSettings,
            launchCoordinator: ImmediateLaunchCoordinator(),
            shortcutRecorderUserDefaults: userDefaults,
            hotkeyMonitorFactory: { identifier, shortcut, _ in
                let monitor = switch identifier {
                case 1:
                    clipboardMonitor
                case 2:
                    selectionMonitor
                default:
                    ocrMonitor
                }
                monitor.initialShortcut = shortcut
                return monitor
            }
        )

        appDelegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            appDelegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
        }

        XCTAssertEqual(
            clipboardMonitor.events,
            [
                .start(savedShortcut),
                .reload(.default),
            ]
        )
        XCTAssertEqual(ShortcutSettings.load(from: userDefaults), .default)
        XCTAssertEqual(
            appDelegate.shortcutStatusLabelForTesting(),
            "Clipboard shortcut could not be registered. Choose another combination from the menu bar."
        )
    }

    @MainActor
    func test_overlay_panel_uses_nonactivating_panel_style() throws {
        let controller = OverlayPanelController()

        let panel = try XCTUnwrap(
            Mirror(reflecting: controller).children
                .first { $0.label == "panel" }?
                .value as? NSPanel
        )

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    }
}

private struct ImmediateLaunchCoordinator: AppLaunchCoordinating {
    func shouldRegisterHotkey(immediatelyAfterLaunch: Bool) -> Bool {
        true
    }
}

private final class TestHotkeyMonitor: GlobalHotkeyMonitoring {
    enum Event: Equatable {
        case start(GlobalHotkeyShortcut)
        case stop
        case reload(GlobalHotkeyShortcut)
    }

    var initialShortcut = GlobalHotkeyShortcut.default {
        didSet {
            activeShortcutForTesting = initialShortcut
        }
    }
    private(set) var activeShortcutForTesting = GlobalHotkeyShortcut.default
    private(set) var isRunningForTesting = false
    private(set) var events: [Event] = []
    private var startResults: [Bool]
    private var reloadResults: [Bool]

    var isRunning: Bool {
        isRunningForTesting
    }

    var configuredShortcut: GlobalHotkeyShortcut {
        activeShortcutForTesting
    }

    init(
        startResults: [Bool] = [],
        reloadResults: [Bool] = []
    ) {
        self.startResults = startResults
        self.reloadResults = reloadResults
    }

    func start() -> Bool {
        events.append(.start(activeShortcutForTesting))
        let didStart = if startResults.isEmpty {
            true
        } else {
            startResults.removeFirst()
        }
        if didStart {
            isRunningForTesting = true
        } else {
            isRunningForTesting = false
        }
        return didStart
    }

    func stop() {
        events.append(.stop)
        isRunningForTesting = false
    }

    func reload(shortcut: GlobalHotkeyShortcut) -> Bool {
        let previousShortcut = activeShortcutForTesting
        let wasRunning = isRunningForTesting
        events.append(.reload(shortcut))
        let didReload = if reloadResults.isEmpty {
            true
        } else {
            reloadResults.removeFirst()
        }
        if didReload {
            activeShortcutForTesting = shortcut
            isRunningForTesting = true
            return true
        }
        activeShortcutForTesting = shortcut
        isRunningForTesting = false
        if wasRunning {
            activeShortcutForTesting = previousShortcut
            _ = start()
        }
        return false
    }
}
