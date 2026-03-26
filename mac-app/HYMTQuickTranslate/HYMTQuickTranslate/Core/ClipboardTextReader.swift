import AppKit

protocol ClipboardTextReading {
    func readString() -> String?
}

struct ClipboardTextReader: ClipboardTextReading {
    func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }
}
