import Foundation

/// Small, shareable diagnostic log. It captures native events plus JS console
/// output, page errors, failed fetches and loading status. Lines are capped so
/// a long session cannot grow without bound, and mirrored to Documents so the
/// file is also visible from the iOS Files app.
final class DiagnosticLog {

    static let shared = DiagnosticLog()

    private let queue = DispatchQueue(label: "com.fanport.frickbears3.diagnostics", qos: .utility)
    private let maxLines = 3000

    private lazy var fileURL: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("frickbears3-diagnostic.log")
    }()

    private var lines: [String]

    private init() {
        lines = [Self.stamp() + " [INFO] [native] diagnostic log opened"]
        flush()
    }

    func add(_ message: String, level: String = "INFO", source: String = "native") {
        let clipped = String(message.prefix(4000))
        let line = Self.stamp() + " [\(level)] [\(source)] " + clipped
        queue.async {
            self.lines.append(line)
            if self.lines.count > self.maxLines {
                self.lines.removeFirst(self.lines.count - self.maxLines)
            }
            self.flush()
        }
    }

    func currentText() -> String {
        queue.sync { joinedText() }
    }

    func exportFileURL() -> URL {
        queue.sync {
            flush()
            return fileURL
        }
    }

    func clear() {
        queue.async {
            self.lines = [Self.stamp() + " [INFO] [native] diagnostic log cleared"]
            self.flush()
        }
    }

    private func joinedText() -> String {
        guard !lines.isEmpty else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Called inside `queue`. Never call `currentText()` from here.
    private func flush() {
        try? joinedText().write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.string(from: Date())
    }
}
