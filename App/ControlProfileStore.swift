import Foundation

/// Which rule set the overlay is currently using. The web shell cannot detect
/// GameMaker rooms reliably, so the user can switch manually; the native
/// engine will switch these automatically.
enum ControlContext: String, Codable, CaseIterable {
    case freeRoam
    case office
    case minigame

    var title: String {
        switch self {
        case .freeRoam: return "Free Roam"
        case .office:   return "Office"
        case .minigame: return "Minigames"
        }
    }

    var detail: String {
        switch self {
        case .freeRoam: return "Movement, turning and camera look"
        case .office:   return "Doors, monitor, mask and camera tabs"
        case .minigame: return "Board controls and pointer/tap input"
        }
    }
}

enum CameraMode: String, Codable, CaseIterable {
    case none
    case twinStick
    case drag
    case hybrid
    case dpad

    var title: String {
        switch self {
        case .none:      return "None"
        case .twinStick: return "Twin-stick"
        case .drag:      return "Drag to look"
        case .hybrid:    return "Hybrid"
        case .dpad:      return "D-pad turn"
        }
    }

    var detail: String {
        switch self {
        case .none:      return "No camera control in this profile"
        case .twinStick: return "Move with left pad, turn with right pad"
        case .drag:      return "Move with D-pad, drag empty space to look"
        case .hybrid:    return "D-pad for coarse turns, drag for fine aim"
        case .dpad:      return "Fixed-angle turns, most predictable"
        }
    }
}

enum FredsweeperTouchScheme: String, Codable, CaseIterable {
    case flagToggle
    case flagModifier
    case longPress
    case cursor

    var title: String {
        switch self {
        case .flagToggle:    return "FLAG toggle"
        case .flagModifier:  return "Hold FLAG + tap"
        case .longPress:     return "Long-press flag"
        case .cursor:        return "D-pad cursor"
        }
    }

    var detail: String {
        switch self {
        case .flagToggle:
            return "Tap tiles to reveal. Toggle FLAG to mark. Tap a revealed number to chord."
        case .flagModifier:
            return "Hold FLAG with one thumb and tap tiles to mark. Fastest for high-level play."
        case .longPress:
            return "Tap to reveal, hold about 250 ms to flag. Simple but slower."
        case .cursor:
            return "Move a highlight with the D-pad. Best for Golden Fredsweeper."
        }
    }
}

struct ControlProfile: Codable {
    var cameraMode: CameraMode
    var uiScale: Double
    var buttonOpacity: Double
    var showDpad: Bool
    var showActionButtons: Bool
    var mappings: [String: TouchEntry]

    func entry(for action: TouchAction) -> TouchEntry? {
        mappings[action.rawValue]
    }

    mutating func setEntry(_ entry: TouchEntry, for action: TouchAction) {
        mappings[action.rawValue] = entry
    }
}

/// Persisted per-context control profiles. Values are stored as JSON so new
/// fields can be added without breaking existing settings.
final class ControlProfileStore {
    static let shared = ControlProfileStore()

    private let defaultsKey = "frickbears3.control-profiles.v1"
    private let activeKey = "frickbears3.control-profile.active.v1"
    private let userDefaults: UserDefaults

    private(set) var profiles: [ControlContext: ControlProfile]

    var activeContext: ControlContext {
        didSet {
            userDefaults.set(activeContext.rawValue, forKey: activeKey)
            onChange?()
        }
    }

    var onChange: (() -> Void)?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.profiles = Self.defaultProfiles

        if let data = userDefaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: ControlProfile].self, from: data) {
            for (raw, profile) in decoded {
                guard let context = ControlContext(rawValue: raw) else { continue }
                profiles[context] = profile
            }
        }

        if let raw = userDefaults.string(forKey: activeKey),
           let context = ControlContext(rawValue: raw) {
            self.activeContext = context
        } else {
            self.activeContext = .freeRoam
        }
    }

    func profile(for context: ControlContext? = nil) -> ControlProfile {
        profiles[context ?? activeContext] ?? Self.defaultProfiles[context ?? activeContext]!
    }

    func setActiveContext(_ context: ControlContext) {
        activeContext = context
    }

    func update(_ context: ControlContext, _ mutate: (inout ControlProfile) -> Void) {
        var profile = profile(for: context)
        mutate(&profile)
        profiles[context] = profile
        save()
    }

    func entry(for action: TouchAction, context: ControlContext? = nil) -> TouchEntry {
        profile(for: context).entry(for: action)
            ?? TouchMappingStore.defaultEntries[action]!
    }

    func setEntry(_ entry: TouchEntry, for action: TouchAction, context: ControlContext? = nil) {
        let target = context ?? activeContext
        update(target) { $0.setEntry(entry, for: action) }
    }

    func label(for action: TouchAction, context: ControlContext? = nil) -> String {
        let entry = entry(for: action, context: context)
        return TouchMappingStore.availableKeys.first {
            $0.keyCode == entry.keyCode && $0.code == entry.code
        }?.label ?? (entry.key == " " ? "Space" : entry.key.uppercased())
    }

    func resetAll() {
        profiles = Self.defaultProfiles
        activeContext = .freeRoam
        save()
    }

    private func save() {
        var raw: [String: ControlProfile] = [:]
        for (context, profile) in profiles { raw[context.rawValue] = profile }
        guard let data = try? JSONEncoder().encode(raw) else { return }
        userDefaults.set(data, forKey: defaultsKey)
        onChange?()
    }

    static let uiScaleOptions: [Double] = [0.8, 0.9, 1.0, 1.15, 1.3, 1.5]
    static let opacityOptions: [Double] = [0.4, 0.6, 0.8, 1.0]

    static let defaultProfiles: [ControlContext: ControlProfile] = {
        var mappings: [String: TouchEntry] = [:]
        for (action, entry) in TouchMappingStore.defaultEntries {
            mappings[action.rawValue] = entry
        }

        return [
            .freeRoam: ControlProfile(
                cameraMode: .twinStick,
                uiScale: 1.0,
                buttonOpacity: 1.0,
                showDpad: true,
                showActionButtons: true,
                mappings: mappings
            ),
            .office: ControlProfile(
                cameraMode: .dpad,
                uiScale: 1.1,
                buttonOpacity: 0.8,
                showDpad: true,
                showActionButtons: true,
                mappings: mappings
            ),
            .minigame: ControlProfile(
                cameraMode: .none,
                uiScale: 1.0,
                buttonOpacity: 0.85,
                showDpad: false,
                showActionButtons: false,
                mappings: mappings
            )
        ]
    }()
}
