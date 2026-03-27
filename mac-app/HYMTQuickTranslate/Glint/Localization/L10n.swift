import Foundation

enum L10n {
    static var translateSelection: String { String(localized: "Translate Selection", comment: "Action that translates selected text") }
    static var translateClipboard: String { String(localized: "Translate Clipboard", comment: "Action that translates clipboard text") }
    static var translateOCRArea: String { String(localized: "Translate OCR Area", comment: "Action that translates text from an OCR region") }

    static var startService: String { String(localized: "Start Service", comment: "Action that starts the backend service") }
    static var stopService: String { String(localized: "Stop Service", comment: "Action that stops the backend service") }
    static var restartService: String { String(localized: "Restart Service", comment: "Action that restarts the backend service") }
    static var refreshStatus: String { String(localized: "Refresh Status", comment: "Action that refreshes backend status") }
    static var keyboardShortcuts: String { String(localized: "Keyboard Shortcuts…", comment: "Menu entry that opens the keyboard shortcuts panel") }
    static var keyboardShortcutsTitle: String { String(localized: "Keyboard Shortcuts", comment: "Title for the keyboard shortcuts panel") }

    static var accessibilityPermissionGranted: String { String(localized: "Granted", comment: "Permission status when granted") }
    static var accessibilityPermissionRequired: String { String(localized: "Required", comment: "Permission status when required") }

    static func accessibilityPermission(status: String) -> String {
        format(
            String(localized: "Accessibility Permission: %@", comment: "Menu item showing accessibility permission status"),
            status
        )
    }

    static func quitApp(appName: String) -> String {
        format(
            String(localized: "Quit %@", comment: "Menu item that quits the app"),
            appName
        )
    }

    static var serviceStatusChecking: String { String(localized: "Service Status: Checking...", comment: "Backend status headline while checking") }
    static var serviceStatusAvailable: String { String(localized: "Service Status: Available", comment: "Backend status headline when available") }
    static var serviceStatusStarting: String { String(localized: "Service Status: Starting", comment: "Backend status headline when starting") }
    static var serviceStatusUnavailable: String { String(localized: "Service Status: Unavailable", comment: "Backend status headline when unavailable") }
    static var serviceStatusError: String { String(localized: "Service Status: Error", comment: "Backend status headline when errored") }

    static var checkingBackendAvailability: String { String(localized: "Checking backend availability", comment: "Backend status detail while checking") }
    static var backendReachable: String { String(localized: "Translation backend is reachable", comment: "Backend status detail when available") }
    static var backendStartingPleaseWait: String { String(localized: "Backend is starting, please wait", comment: "Backend status detail when starting") }
    static var backendCurrentlyUnavailable: String { String(localized: "Backend is currently unavailable", comment: "Backend status detail when unavailable") }
    static var unableVerifyBackendStatus: String { String(localized: "Unable to verify backend status", comment: "Backend status detail when refresh fails") }
    static var failedToStartService: String { String(localized: "Failed to start the service", comment: "Backend status detail when starting fails") }
    static var failedToStopService: String { String(localized: "Failed to stop the service", comment: "Backend status detail when stopping fails") }
    static var failedToRestartService: String { String(localized: "Failed to restart the service", comment: "Backend status detail when restarting fails") }

    static var noTextProvided: String { String(localized: "No text was provided.", comment: "Error when no text is available") }
    static var textExceedsMaximumLength: String { String(localized: "Text exceeds the maximum length.", comment: "Error when text exceeds the length limit") }
    static var noSelectedTextFound: String { String(localized: "No selected text was found.", comment: "Error when there is no selected text") }
    static var accessibilityPermissionNotGranted: String { String(localized: "Accessibility permission is not granted.", comment: "Error when accessibility permission is missing") }
    static var accessibilityPermissionRequiredForSelectionTranslation: String { String(localized: "Accessibility permission is required for selection translation.", comment: "Error when selection translation requires accessibility permission") }
    static var browserAutomationPermissionNotGranted: String { String(localized: "Browser automation permission is not granted.", comment: "Error when browser automation permission is missing") }
    static var browserAutomationPermissionRetry: String { String(localized: "Browser automation permission is not granted. Allow Glint to control the browser and try again.", comment: "Error asking the user to allow browser control") }
    static var unsupportedHostApp: String { String(localized: "Frontmost app does not expose selected text through Accessibility APIs.", comment: "Error when the current app does not expose selected text") }
    static var clipboardDoesNotContainText: String { String(localized: "Clipboard does not contain text.", comment: "Error when the clipboard has no text") }
    static var clipboardTextExceedsMaximumLength: String { String(localized: "Clipboard text exceeds the maximum length.", comment: "Error when clipboard text is too long") }
    static var localTranslationServiceInvalidResponse: String { String(localized: "Local translation service returned an invalid response.", comment: "Error when the translation service response is invalid") }
    static var localTranslationServiceUnavailable: String { String(localized: "Local translation service is unavailable.", comment: "Error when the translation service is unavailable") }
    static var translationRequestTimedOut: String { String(localized: "Translation request timed out.", comment: "Error when a translation request times out") }

    static var recognizedTextExceedsMaximumLength: String { String(localized: "Recognized text exceeds the maximum length.", comment: "Error when OCR text is too long") }
    static var noTextRecognizedInSelectedArea: String { String(localized: "No text was recognized in the selected area.", comment: "Error when OCR finds no text") }
    static var ocrUnavailableOnSystem: String { String(localized: "OCR is unavailable on this system.", comment: "Error when OCR is unavailable") }
    static var unableToCaptureSelectedArea: String { String(localized: "Unable to capture the selected area.", comment: "Error when the selected area cannot be captured") }

    static var translating: String { String(localized: "Translating...", comment: "Overlay loading state") }
    static var clipboardLongTextConfirmation: String { String(localized: "This clipboard text is longer than the quick-translate limit.", comment: "Confirmation text for long clipboard content") }
    static var preview: String { String(localized: "Preview:", comment: "Preview label") }
    static var cancel: String { String(localized: "Cancel", comment: "Cancel button title") }
    static var translate: String { String(localized: "Translate", comment: "Translate button title") }
    static var translation: String { String(localized: "Translation", comment: "Overlay title for a translation result") }
    static var close: String { String(localized: "Close", comment: "Close button title") }
    static var translationFailed: String { String(localized: "Translation failed", comment: "Overlay title when translation fails") }

    static var resetToDefaults: String { String(localized: "Reset to Defaults", comment: "Reset button title in the shortcut panel") }
    static var done: String { String(localized: "Done", comment: "Done button title in the shortcut panel") }
    static var shortcutPanelSubtitle: String { String(localized: "Set shortcuts for selection, clipboard, and OCR translation.", comment: "Subtitle in the shortcut panel") }
    static var chooseShortcutToEdit: String { String(localized: "Choose a shortcut to edit.", comment: "Idle hint in the shortcut panel") }
    static var pressKeys: String { String(localized: "Press keys", comment: "Hint while a shortcut is being recorded") }
    static var clickToChange: String { String(localized: "Click to change", comment: "Hint before editing a shortcut") }
    static var pressShortcutEscCancels: String { String(localized: "Press a shortcut. Esc cancels.", comment: "Status message shown while recording a shortcut") }
    static var defaultsRestored: String { String(localized: "Defaults restored", comment: "Status message after restoring defaults") }
    static var shortcutCouldNotBeRegisteredTryAnother: String { String(localized: "Shortcut could not be registered. Try another combination.", comment: "Error when a shortcut cannot be registered") }
    static var defaultsCouldNotBeRestored: String { String(localized: "Defaults could not be restored.", comment: "Error when defaults cannot be restored") }
    static var useAtLeastOneModifierKey: String { String(localized: "Use at least one modifier key.", comment: "Error when no modifier key is used for a shortcut") }
    static var shortcutAlreadyUsedByGlint: String { String(localized: "This shortcut is already used by Glint", comment: "Error when the shortcut duplicates another Glint shortcut") }
    static var shortcutSaved: String { String(localized: "Shortcut saved", comment: "Status message after saving a shortcut") }
    static var shortcutAlreadyInUseTryAnother: String { String(localized: "Shortcut already in use. Try another combination.", comment: "Error when the shortcut is already in use") }

    static var shortcutTargetClipboard: String { String(localized: "Clipboard", comment: "Shortcut target label for clipboard") }
    static var shortcutTargetSelection: String { String(localized: "Selection", comment: "Shortcut target label for selection") }
    static var shortcutTargetOCR: String { String(localized: "OCR", comment: "Shortcut target label for OCR") }

    static func shortcutResetToDefault(target: String) -> String {
        format(
            String(
                localized: "%@ shortcut was reset to the default because the saved combination could not be registered.",
                comment: "Status message when a saved shortcut falls back to the default value"
            ),
            target
        )
    }

    static func shortcutCouldNotBeRegisteredFromMenu(target: String) -> String {
        format(
            String(
                localized: "%@ shortcut could not be registered. Choose another combination from the menu bar.",
                comment: "Status message when a startup shortcut cannot be registered"
            ),
            target
        )
    }

    static func recordingShortcut(target: String) -> String {
        format(
            String(
                localized: "Recording %@ Shortcut. Press the new key combination.",
                comment: "Status message while recording a shortcut"
            ),
            target
        )
    }

    static var settingsClipboardHint: String { String(localized: "Use the global shortcut to translate the clipboard.", comment: "Settings scene hint text") }
    static var ocrSelectionTitle: String { String(localized: "OCR Selection", comment: "Title for the OCR selection overlay") }
    static var ocrSelectionHint: String { String(localized: "Drag to capture an area. Press Esc to cancel.", comment: "Hint for the OCR selection overlay") }

    private static func format(_ format: String, _ arguments: CVarArg...) -> String {
        String(format: format, locale: Locale.current, arguments: arguments)
    }
}
