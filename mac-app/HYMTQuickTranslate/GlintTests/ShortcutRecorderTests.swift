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
        XCTAssertEqual(
            ocrMonitor.events,
            [.start(ShortcutSettings.default.ocrShortcut)]
        )
        XCTAssertNotNil(reflectedValue(named: "clipboardHotkeyMonitor", from: appDelegate))
        XCTAssertNotNil(reflectedValue(named: "selectionHotkeyMonitor", from: appDelegate))
        XCTAssertNotNil(reflectedValue(named: "ocrHotkeyMonitor", from: appDelegate))
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
            reflectedValue(named: "shortcutStatusLabel", from: appDelegate) as? String,
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
            reflectedValue(named: "shortcutStatusLabel", from: appDelegate) as? String,
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

private func reflectedValue(named label: String, from appDelegate: AppDelegate) -> Any? {
    Mirror(reflecting: appDelegate).children
        .first { $0.label == label }?
        .value
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

    var initialShortcut = GlobalHotkeyShortcut.default
    private(set) var events: [Event] = []
    private var startResults: [Bool]
    private var reloadResults: [Bool]

    init(startResults: [Bool] = [], reloadResults: [Bool] = []) {
        self.startResults = startResults
        self.reloadResults = reloadResults
    }

    func start() -> Bool {
        events.append(.start(initialShortcut))
        if startResults.isEmpty {
            return true
        }
        return startResults.removeFirst()
    }

    func stop() {
        events.append(.stop)
    }

    func reload(shortcut: GlobalHotkeyShortcut) -> Bool {
        events.append(.reload(shortcut))
        if reloadResults.isEmpty {
            return true
        }
        return reloadResults.removeFirst()
    }
}
