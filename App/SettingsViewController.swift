import UIKit

/// Root settings screen. Game speed, HUD counters, zoom and the new
/// profile/scaling options are all persisted by AppConfigStore.
final class SettingsViewController: UITableViewController {

    private let config = AppConfigStore.shared
    private let cellIdentifier = "SettingsCell"
    var onDismiss: (() -> Void)?
    var onInspect: (() -> Void)?

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Reset All",
            style: .plain,
            target: self,
            action: #selector(resetTapped)
        )

        let note = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 76))
        note.text = "Game Speed is experimental: the engine has no official speed control, so it works by scaling the game's clock. Set it back to 1.0× if anything behaves oddly."
        note.numberOfLines = 0
        note.font = .systemFont(ofSize: 12)
        note.textColor = .secondaryLabel
        note.textAlignment = .center
        tableView.tableFooterView = note
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @objc private func doneTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    @objc private func resetTapped() {
        config.resetToDefaults()
        TouchMappingStore.shared.resetToDefaults()
        ControlProfileStore.shared.resetAll()
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 5 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3  // controls
        case 1: return 2  // gameplay
        case 2: return 3  // diagnostics
        case 3: return 4  // minigames
        default: return 3 // mods
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Controls"
        case 1: return "Gameplay"
        case 2: return "Diagnostics"
        case 3: return "Minigames"
        default: return "Mods"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.accessoryView = nil
        cell.accessoryType = .none
        cell.detailTextLabel?.text = nil
        cell.detailTextLabel?.textColor = .systemBlue

        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            cell.textLabel?.text = "Button Mapping"
            cell.accessoryType = .disclosureIndicator
        case (0, 1):
            cell.textLabel?.text = "Control Profiles"
            cell.detailTextLabel?.text = ControlProfileStore.shared.activeContext.title
            cell.accessoryType = .disclosureIndicator
        case (0, 2):
            cell.textLabel?.text = "Overlay Scale"
            cell.detailTextLabel?.text = String(format: "%.2f×", config.uiScale)
            cell.accessoryType = .disclosureIndicator

        case (1, 0):
            cell.textLabel?.text = "Game Speed"
            cell.detailTextLabel?.text = String(format: "%.2f×", config.gameSpeed)
            cell.accessoryType = .disclosureIndicator
        case (1, 1):
            cell.textLabel?.text = "Haptics"
            cell.accessoryView = makeSwitch(config.hapticsEnabled) { [weak self] in
                self?.config.hapticsEnabled = $0
            }

        case (2, 0):
            cell.textLabel?.text = "FPS Counter"
            cell.accessoryView = makeSwitch(config.showFPS) { [weak self] in
                self?.config.showFPS = $0
            }
        case (2, 1):
            cell.textLabel?.text = "Memory Counter"
            cell.accessoryView = makeSwitch(config.showRAM) { [weak self] in
                self?.config.showRAM = $0
            }
        case (2, 2):
            cell.textLabel?.text = "Inspect Page"
            cell.accessoryType = .disclosureIndicator

        case (3, 0):
            cell.textLabel?.text = "Fredsweeper Controls"
            cell.detailTextLabel?.text = config.fredsweeperScheme.title
            cell.accessoryType = .disclosureIndicator
        case (3, 1):
            cell.textLabel?.text = "Minigame Board Scale"
            cell.detailTextLabel?.text = String(format: "%.1f×", config.minigameScale)
            cell.accessoryType = .disclosureIndicator
        case (3, 2):
            cell.textLabel?.text = "External Minigame HUD"
            cell.accessoryView = makeSwitch(config.externalMinigameHUD) { [weak self] in
                self?.config.externalMinigameHUD = $0
            }
        case (3, 3):
            cell.textLabel?.text = "Minigame Zoom Button"
            cell.accessoryView = makeSwitch(config.showZoomButton) { [weak self] in
                self?.config.showZoomButton = $0
            }

        case (4, 0):
            cell.textLabel?.text = "Enable Mods"
            cell.accessoryView = makeSwitch(config.modsEnabled) { [weak self] in
                self?.config.modsEnabled = $0
            }
        case (4, 1):
            cell.textLabel?.text = "Asset Overrides"
            cell.accessoryView = makeSwitch(config.assetOverridesEnabled) { [weak self] in
                self?.config.assetOverridesEnabled = $0
            }
        case (4, 2):
            cell.textLabel?.text = "Mod Indicator"
            cell.accessoryView = makeSwitch(config.showModIndicator) { [weak self] in
                self?.config.showModIndicator = $0
            }

        default:
            break
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            navigationController?.pushViewController(
                RemapViewController(),
                animated: true
            )
        case (0, 1):
            navigationController?.pushViewController(
                ControlProfilesViewController(),
                animated: true
            )
        case (0, 2):
            let current = AppConfigStore.uiScaleOptions.firstIndex {
                abs($0 - config.uiScale) < 0.001
            } ?? 2
            pushChoicePicker(
                title: "Overlay Scale",
                options: AppConfigStore.uiScaleOptions.map { String(format: "%.2f×", $0) },
                selected: current
            ) { [weak self] index in
                self?.config.uiScale = AppConfigStore.uiScaleOptions[index]
            }
        case (1, 0):
            navigationController?.pushViewController(SpeedPickerViewController(), animated: true)
        case (2, 2):
            onInspect?()
        case (3, 0):
            let schemes = FredsweeperTouchScheme.allCases
            let current = schemes.firstIndex(of: config.fredsweeperScheme) ?? 0
            pushChoicePicker(
                title: "Fredsweeper Controls",
                options: schemes.map(\.title),
                details: schemes.map(\.detail),
                selected: current
            ) { [weak self] index in
                self?.config.fredsweeperScheme = schemes[index]
            }
        case (3, 1):
            let scales = AppConfigStore.minigameScaleOptions
            let current = scales.firstIndex { abs($0 - config.minigameScale) < 0.001 } ?? 2
            pushChoicePicker(
                title: "Minigame Board Scale",
                options: scales.map { String(format: "%.1f×", $0) },
                selected: current
            ) { [weak self] index in
                self?.config.minigameScale = scales[index]
            }
        default:
            break
        }
    }

    private func makeSwitch(_ value: Bool, _ changed: @escaping (Bool) -> Void) -> ConfigSwitch {
        let toggle = ConfigSwitch()
        toggle.isOn = value
        toggle.valueChanged = changed
        return toggle
    }

    private func pushChoicePicker(
        title: String,
        options: [String],
        details: [String]? = nil,
        selected: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        let picker = ChoicePickerViewController(
            title: title,
            options: options,
            details: details,
            selected: selected,
            onSelect: onSelect
        )
        navigationController?.pushViewController(picker, animated: true)
    }
}

// MARK: - Speed picker

final class SpeedPickerViewController: UITableViewController {

    private let config = AppConfigStore.shared
    private let cellIdentifier = "SpeedCell"
    private let speeds = AppConfigStore.speedOptions

    init() {
        super.init(style: .insetGrouped)
        title = "Game Speed"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        speeds.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let speed = speeds[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)
        cell.textLabel?.text = String(format: "%.2f×%@", speed, speed == 1.0 ? "  (normal)" : "")
        cell.accessoryType = abs(config.gameSpeed - speed) < 0.001 ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        config.gameSpeed = speeds[indexPath.row]
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Generic choice picker

final class ChoicePickerViewController: UITableViewController {

    private let options: [String]
    private let details: [String]?
    private let selected: Int
    private let onSelect: (Int) -> Void
    private let cellIdentifier = "ChoiceCell"

    init(
        title: String,
        options: [String],
        details: [String]?,
        selected: Int,
        onSelect: @escaping (Int) -> Void
    ) {
        self.options = options
        self.details = details
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        options.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        cell.textLabel?.text = options[indexPath.row]
        cell.detailTextLabel?.text = details?[indexPath.row]
        cell.detailTextLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .systemFont(ofSize: 11)
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.accessoryType = indexPath.row == selected ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect(indexPath.row)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Control profiles

final class ControlProfilesViewController: UITableViewController {

    private let store = ControlProfileStore.shared
    private let cellIdentifier = "ProfileCell"

    init() {
        super.init(style: .insetGrouped)
        title = "Control Profiles"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : ControlContext.allCases.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "Active" : "Edit Profile"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: cellIdentifier)

        if indexPath.section == 0 {
            cell.textLabel?.text = "Current Profile"
            cell.detailTextLabel?.text = store.activeContext.title
            cell.accessoryType = .disclosureIndicator
        } else {
            let context = ControlContext.allCases[indexPath.row]
            let profile = store.profile(for: context)
            cell.textLabel?.text = context.title
            cell.detailTextLabel?.text = profile.cameraMode.title
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            let contexts = ControlContext.allCases
            let picker = ChoicePickerViewController(
                title: "Current Profile",
                options: contexts.map(\.title),
                details: contexts.map(\.detail),
                selected: contexts.firstIndex(of: store.activeContext) ?? 0
            ) { [weak self] index in
                self?.store.setActiveContext(contexts[index])
                self?.tableView.reloadData()
            }
            navigationController?.pushViewController(picker, animated: true)
        } else {
            let context = ControlContext.allCases[indexPath.row]
            navigationController?.pushViewController(
                ProfileDetailViewController(context: context),
                animated: true
            )
        }
    }
}

final class ProfileDetailViewController: UITableViewController {

    private let context: ControlContext
    private let store = ControlProfileStore.shared
    private let cellIdentifier = "ProfileDetailCell"

    init(context: ControlContext) {
        self.context = context
        super.init(style: .insetGrouped)
        title = context.title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 6 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: cellIdentifier)
        let profile = store.profile(for: context)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Camera Mode"
            cell.detailTextLabel?.text = profile.cameraMode.title
            cell.accessoryType = .disclosureIndicator
        case 1:
            cell.textLabel?.text = "Button Size"
            cell.detailTextLabel?.text = String(format: "%.2f×", profile.uiScale)
            cell.accessoryType = .disclosureIndicator
        case 2:
            cell.textLabel?.text = "Button Opacity"
            cell.detailTextLabel?.text = String(format: "%.0f%%", profile.buttonOpacity * 100)
            cell.accessoryType = .disclosureIndicator
        case 3:
            cell.textLabel?.text = "Show D-pad"
            let toggle = ConfigSwitch()
            toggle.isOn = profile.showDpad
            toggle.valueChanged = { [weak self] value in
                guard let self else { return }
                self.store.update(self.context) { $0.showDpad = value }
            }
            cell.accessoryView = toggle
        case 4:
            cell.textLabel?.text = "Show Action Buttons"
            let toggle = ConfigSwitch()
            toggle.isOn = profile.showActionButtons
            toggle.valueChanged = { [weak self] value in
                guard let self else { return }
                self.store.update(self.context) { $0.showActionButtons = value }
            }
            cell.accessoryView = toggle
        default:
            cell.textLabel?.text = "Button Mapping"
            cell.detailTextLabel?.text = nil
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let profile = store.profile(for: context)

        switch indexPath.row {
        case 0:
            let modes = CameraMode.allCases
            let picker = ChoicePickerViewController(
                title: "Camera Mode",
                options: modes.map(\.title),
                details: modes.map(\.detail),
                selected: modes.firstIndex(of: profile.cameraMode) ?? 0
            ) { [weak self] index in
                guard let self else { return }
                self.store.update(self.context) { $0.cameraMode = modes[index] }
            }
            navigationController?.pushViewController(picker, animated: true)
        case 1:
            let scales = ControlProfileStore.uiScaleOptions
            let picker = ChoicePickerViewController(
                title: "Button Size",
                options: scales.map { String(format: "%.2f×", $0) },
                details: nil,
                selected: scales.firstIndex { abs($0 - profile.uiScale) < 0.001 } ?? 2
            ) { [weak self] index in
                guard let self else { return }
                self.store.update(self.context) { $0.uiScale = scales[index] }
            }
            navigationController?.pushViewController(picker, animated: true)
        case 2:
            let opacities = ControlProfileStore.opacityOptions
            let picker = ChoicePickerViewController(
                title: "Button Opacity",
                options: opacities.map { String(format: "%.0f%%", $0 * 100) },
                details: nil,
                selected: opacities.firstIndex { abs($0 - profile.buttonOpacity) < 0.001 } ?? 3
            ) { [weak self] index in
                guard let self else { return }
                self.store.update(self.context) { $0.buttonOpacity = opacities[index] }
            }
            navigationController?.pushViewController(picker, animated: true)
        case 5:
            navigationController?.pushViewController(
                RemapViewController(context: context),
                animated: true
            )
        default:
            break
        }
    }
}

// MARK: - Page inspector

/// Read-only, shareable dump of the live WKWebView page. This is purely a
/// troubleshooting aid — it reports what the browser is actually rendering.
final class InspectViewController: UIViewController {

    private let text: String

    init(text: String) {
        self.text = text
        super.init(nibName: nil, bundle: nil)
        title = "Page Inspect"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBackground
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = text
        textView.font = .systemFont(ofSize: 11)
        textView.isEditable = false
        textView.isSelectable = true
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    @objc private func shareTapped() {
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activity, animated: true)
    }
}

// MARK: - Switch

private final class ConfigSwitch: UISwitch {
    var valueChanged: ((Bool) -> Void)?

    init() {
        super.init(frame: .zero)
        addTarget(self, action: #selector(changed), for: .valueChanged)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func changed() { valueChanged?(isOn) }
}
