import Foundation
import WebKit

/// Serves the bundled GameMaker HTML5 build from the app bundle through a
/// custom `fb3://` scheme. Using a custom scheme (instead of `file://`) avoids
/// WKWebView's local-file fetch/CORS/WebAssembly restrictions.
final class GameURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let fileManager = FileManager.default
    private let log = DiagnosticLog.shared

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        let rawPath = url.path.removingPercentEncoding ?? url.path
        let relative = rawPath.hasPrefix("/") ? String(rawPath.dropFirst()) : rawPath
        let rangeHeader = urlSchemeTask.request.value(forHTTPHeaderField: "Range")
        log.add("GET /\(relative) range=\(rangeHeader ?? "-")", source: "scheme")

        // The CDN page references a second QR image that is not bundled. Serve
        // the real one so the log stays clean and no request fails needlessly.
        let resourceName = relative == "runnerLocal.svg" ? "runner.svg" : relative

        guard let file = resolve(resourceName), fileManager.fileExists(atPath: file.path) else {
            log.add("404 /\(relative)", level: "WARN", source: "scheme")
            respond(
                task: urlSchemeTask, url: url, status: 404,
                headers: ["Content-Type": "text/plain; charset=utf-8"],
                data: Data("Not found: \(relative)".utf8)
            )
            return
        }

        do {
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            var headers = mimeHeaders(for: file.pathExtension)
            headers["Cache-Control"] = "no-store"
            headers["Access-Control-Allow-Origin"] = "*"
            headers["Accept-Ranges"] = "bytes"

            let range = byteRange(from: rangeHeader, count: data.count)
            if let range {
                let slice = data.subdata(in: range)
                headers["Content-Range"] = "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(data.count)"
                headers["Content-Length"] = String(slice.count)
                log.add("206 /\(relative) bytes=\(slice.count)/\(data.count)", source: "scheme")
                respond(task: urlSchemeTask, url: url, status: 206, headers: headers, data: slice)
            } else {
                headers["Content-Length"] = String(data.count)
                log.add("200 /\(relative) bytes=\(data.count)", source: "scheme")
                respond(task: urlSchemeTask, url: url, status: 200, headers: headers, data: data)
            }
        } catch {
            log.add("read failed /\(relative): \(error.localizedDescription)",
                    level: "ERROR", source: "scheme")
            respond(
                task: urlSchemeTask, url: url, status: 500,
                headers: ["Content-Type": "text/plain; charset=utf-8"],
                data: Data("Read failed: \(relative)".utf8)
            )
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Nothing to cancel: files are read synchronously from the bundle.
    }

    private func respond(
        task: WKURLSchemeTask,
        url: URL,
        status: Int,
        headers: [String: String],
        data: Data
    ) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    private func byteRange(from header: String?, count: Int) -> Range<Int>? {
        guard let header, header.hasPrefix("bytes="), count > 0 else { return nil }
        let spec = header.dropFirst(6).trimmingCharacters(in: .whitespaces)
        let parts = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        if parts[0].isEmpty {
            guard let suffix = Int(parts[1]), suffix > 0 else { return nil }
            return max(0, count - suffix)..<count
        }

        guard let start = Int(parts[0]), start >= 0, start < count else { return nil }
        let end: Int
        if parts[1].isEmpty {
            end = count - 1
        } else if let parsed = Int(parts[1]) {
            end = parsed
        } else {
            return nil
        }
        guard end >= start else { return nil }
        return start..<min(end + 1, count)
    }

    private func resolve(_ relative: String) -> URL? {
        guard !relative.isEmpty else { return nil }

        let candidates = [
            Bundle.main.resourceURL?
                .appendingPathComponent("Game", isDirectory: true)
                .appendingPathComponent(relative),
            Bundle.main.resourceURL?.appendingPathComponent(relative),
            Bundle.main.bundleURL
                .appendingPathComponent("Game", isDirectory: true)
                .appendingPathComponent(relative),
            Bundle.main.bundleURL.appendingPathComponent(relative)
        ]

        return candidates.compactMap { $0 }.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func mimeHeaders(for fileExtension: String) -> [String: String] {
        switch fileExtension.lowercased() {
        case "html", "htm":            return ["Content-Type": "text/html; charset=utf-8"]
        case "js":                     return ["Content-Type": "text/javascript; charset=utf-8"]
        case "wasm":                   return ["Content-Type": "application/wasm"]
        case "json", "webmanifest":    return ["Content-Type": "application/json; charset=utf-8"]
        case "css":                    return ["Content-Type": "text/css; charset=utf-8"]
        case "png":                    return ["Content-Type": "image/png"]
        case "jpg", "jpeg":            return ["Content-Type": "image/jpeg"]
        case "svg":                    return ["Content-Type": "image/svg+xml"]
        case "ogg":                    return ["Content-Type": "audio/ogg"]
        case "mp3":                    return ["Content-Type": "audio/mpeg"]
        case "wav":                    return ["Content-Type": "audio/wav"]
        default:                       return ["Content-Type": "application/octet-stream"]
        }
    }
}
