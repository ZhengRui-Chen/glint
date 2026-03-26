import AppKit

protocol ClipboardTextReading: Sendable {
    func readString() -> String?
}

struct ClipboardTextReader: ClipboardTextReading {
    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
