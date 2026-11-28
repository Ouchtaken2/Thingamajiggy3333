import Foundation

/// Describes the small, curated slice of recovered GameMaker assets that the
/// native port needs. Authoring paths in `source` are informational only;
/// runtime paths are relative to the bundled `PortAssets` directory.
struct PortManifest: Codable {
    let schemaVersion: Int
    let displayName: String
    let source: PortManifestSource
    let rooms: [String: String]
    let minigames: [String: PortMinigame]
}

struct PortManifestSource: Codable {
    let build: String
    let gameDirectory: String
    let codeDirectory: String
    let codeReferenceDirectory: String?
    let assemblyDirectory: String
    let textureGroupsGlob: String
}

struct PortMinigame: Codable {
    let displayName: String
    let surfaceWidth: Int
    let surfaceHeight: Int
    let boardWidth: Int
    let boardHeight: Int
    let tileSize: Int
    let mines: Int
    let code: [String: String]
    let spriteSets: [PortSpriteSet]
    let fontSets: [PortSpriteSet]
    let audio: [PortAudioAsset]
}

struct PortSpriteSet: Codable {
    let id: String
    let folder: String
    let framePrefix: String
    let frameCount: Int
}

struct PortAudioAsset: Codable {
    let id: String
    let file: String
}

/// Loads `PortAssets/manifest.json` from the app bundle and resolves asset URLs.
final class PortManifestStore {
    static let shared = PortManifestStore()

    let manifest: PortManifest?
    private let rootURL: URL?

    init(bundle: Bundle = .main) {
        let manifestURL = bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "PortAssets")
            ?? bundle.url(forResource: "PortAssets/manifest", withExtension: "json")

        guard let manifestURL else {
            DiagnosticLog.shared.add("PortAssets/manifest.json not found in bundle",
                                     level: "ERROR", source: "native")
            self.manifest = nil
            self.rootURL = nil
            return
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let decoded = try JSONDecoder().decode(PortManifest.self, from: data)
            self.manifest = decoded
            self.rootURL = manifestURL.deletingLastPathComponent()
        } catch {
            DiagnosticLog.shared.add("PortAssets manifest load failed: \(error)",
                                     level: "ERROR", source: "native")
            self.manifest = nil
            self.rootURL = nil
        }
    }

    func minigame(_ id: String) -> PortMinigame? {
        manifest?.minigames[id]
    }

    func roomURL(_ id: String) -> URL? {
        guard let path = manifest?.rooms[id] else { return nil }
        return rootURL?.appendingPathComponent(path)
    }

    func audioURL(_ id: String, in minigameID: String) -> URL? {
        guard let asset = minigame(minigameID)?.audio.first(where: { $0.id == id }) else { return nil }
        return rootURL?.appendingPathComponent(asset.file)
    }

    func spriteURLs(_ setID: String, in minigameID: String) -> [URL] {
        guard let set = minigame(minigameID)?.spriteSets.first(where: { $0.id == setID }),
              let rootURL else { return [] }

        let folder = rootURL.appendingPathComponent(set.folder, isDirectory: true)
        return (0..<set.frameCount).compactMap { frame in
            let name = "\(set.framePrefix)\(frame).png"
            let url = folder.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    func fontURLs(_ setID: String, in minigameID: String) -> [URL] {
        guard let set = minigame(minigameID)?.fontSets.first(where: { $0.id == setID }),
              let rootURL else { return [] }

        let folder = rootURL.appendingPathComponent(set.folder, isDirectory: true)
        return (0..<set.frameCount).compactMap { frame in
            let name = "\(set.framePrefix)\(frame).png"
            let url = folder.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }
}
