import SwiftUI

@main
struct HYMTQuickTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            VStack(alignment: .leading, spacing: 8) {
                Text(AppBranding.displayName)
                    .font(.headline)
                Text("Use the global shortcut to translate the clipboard.")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 320)
        }
    }
}
