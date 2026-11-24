import Foundation

/// Small persisted preferences used by the in-app Settings screen.
final class AppConfigStore {
    static let shared = AppConfigStore()

    private let defaults: UserDefaults
    private let speedKey = "frickbears3.gamespeed.v1"
    private let fpsKey = "frickbears3.showfps.v1"
    private let ramKey = "frickbears3.showram.v1"
    private let zoomKey = "frickbears3.showzoom.v1"
    private let uiScaleKey = "frickbears3.uiscale.v1"
    private let minigameScaleKey = "frickbears3.minigamescale.v1"
    private let fredsweeperSchemeKey = "frickbears3.fredsweeper.scheme.v1"
    private let externalHUDKey = "frickbears3.minigame.externalhud.v1"
    private let hapticsKey = "frickbears3.haptics.v1"
    private let modsEnabledKey = "frickbears3.mods.enabled.v1"
    private let assetOverridesKey = "frickbears3.mods.assetoverrides.v1"
    private let modIndicatorKey = "frickbears3.mods.indicator.v1"

    var onChange: (() -> Void)?

    var gameSpeed: Double {
        didSet { defaults.set(gameSpeed, forKey: speedKey); onChange?() }
    }
    var showFPS: Bool {
        didSet { defaults.set(showFPS, forKey: fpsKey); onChange?() }
    }
    var showRAM: Bool {
        didSet { defaults.set(showRAM, forKey: ramKey); onChange?() }
    }
    var showZoomButton: Bool {
        didSet { defaults.set(showZoomButton, forKey: zoomKey); onChange?() }
    }
    var uiScale: Double {
        didSet { defaults.set(uiScale, forKey: uiScaleKey); onChange?() }
    }
    var minigameScale: Double {
        didSet { defaults.set(minigameScale, forKey: minigameScaleKey); onChange?() }
    }
    var fredsweeperScheme: FredsweeperTouchScheme {
        didSet { defaults.set(fredsweeperScheme.rawValue, forKey: fredsweeperSchemeKey); onChange?() }
    }
    var externalMinigameHUD: Bool {
        didSet { defaults.set(externalMinigameHUD, forKey: externalHUDKey); onChange?() }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: hapticsKey); onChange?() }
    }
    var modsEnabled: Bool {
        didSet { defaults.set(modsEnabled, forKey: modsEnabledKey); onChange?() }
    }
    var assetOverridesEnabled: Bool {
        didSet { defaults.set(assetOverridesEnabled, forKey: assetOverridesKey); onChange?() }
    }
    var showModIndicator: Bool {
        didSet { defaults.set(showModIndicator, forKey: modIndicatorKey); onChange?() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedSpeed = defaults.double(forKey: speedKey)
        self.gameSpeed = savedSpeed > 0 ? savedSpeed : 1.0
        self.showFPS = defaults.bool(forKey: fpsKey)
        self.showRAM = defaults.bool(forKey: ramKey)
        self.showZoomButton = defaults.object(forKey: zoomKey) == nil
            ? true
            : defaults.bool(forKey: zoomKey)

        let savedUIScale = defaults.double(forKey: uiScaleKey)
        self.uiScale = savedUIScale > 0 ? savedUIScale : 1.0

        let savedMinigameScale = defaults.double(forKey: minigameScaleKey)
        self.minigameScale = savedMinigameScale > 0 ? savedMinigameScale : 3.0

        if let rawScheme = defaults.string(forKey: fredsweeperSchemeKey),
           let scheme = FredsweeperTouchScheme(rawValue: rawScheme) {
            self.fredsweeperScheme = scheme
        } else {
            self.fredsweeperScheme = .flagToggle
        }

        self.externalMinigameHUD = defaults.object(forKey: externalHUDKey) == nil
            ? true
            : defaults.bool(forKey: externalHUDKey)
        self.hapticsEnabled = defaults.object(forKey: hapticsKey) == nil
            ? true
            : defaults.bool(forKey: hapticsKey)
        self.modsEnabled = defaults.bool(forKey: modsEnabledKey)
        self.assetOverridesEnabled = defaults.object(forKey: assetOverridesKey) == nil
            ? true
            : defaults.bool(forKey: assetOverridesKey)
        self.showModIndicator = defaults.object(forKey: modIndicatorKey) == nil
            ? true
            : defaults.bool(forKey: modIndicatorKey)
    }

    static let speedOptions: [Double] = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    static let uiScaleOptions = ControlProfileStore.uiScaleOptions
    static let minigameScaleOptions: [Double] = [2.0, 2.5, 3.0, 3.5, 4.0]

    func resetToDefaults() {
        gameSpeed = 1.0
        showFPS = false
        showRAM = false
        showZoomButton = true
        uiScale = 1.0
        minigameScale = 3.0
        fredsweeperScheme = .flagToggle
        externalMinigameHUD = true
        hapticsEnabled = true
        modsEnabled = false
        assetOverridesEnabled = true
        showModIndicator = true
    }
}
