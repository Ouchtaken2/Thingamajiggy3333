import UIKit

/// Thin native host for the 2.2 Fredsweeper renderer. It is a modal demo
/// entry point: the 2.1.5 web game stays bundled and untouched underneath.
final class FredsweeperViewController: UIViewController {

    var onDismiss: (() -> Void)?

    private let gameView = FredsweeperView()
    private let modeControl = UISegmentedControl(items: ["Fredsweeper", "Golden"])
    private let tilesLabel = UILabel()
    private let timerLabel = UILabel()
    private let flagButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let controlsStack = UIStackView()

    private let scheme = AppConfigStore.shared.fredsweeperScheme
    private var flagModeOn = false
    private var currentMode = 0

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 18/255, alpha: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildHeader()
        buildGameView()
        buildControls()
        gameView.configure(minigameID: minigameID(for: currentMode))
        updateStatusLabel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        gameView.suspend()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        gameView.resume()
    }

    /// Called by GameViewController while this modal is active so app
    /// backgrounding does not resume the web game underneath.
    func gameViewSuspend() {
        gameView.suspend()
    }

    func gameViewResume() {
        gameView.resume()
    }

    private func minigameID(for segment: Int) -> String {
        segment == 0 ? "fredsweeper" : "goldenFredsweeper"
    }

    // MARK: - Layout

    private func buildHeader() {
        modeControl.selectedSegmentIndex = currentMode
        modeControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(modeControl)

        tilesLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        tilesLabel.textColor = UIColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1)
        tilesLabel.text = "Tiles: --"

        timerLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timerLabel.textColor = UIColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1)
        timerLabel.text = "0:00"

        let externalHUD = AppConfigStore.shared.externalMinigameHUD
        tilesLabel.isHidden = !externalHUD
        timerLabel.isHidden = !externalHUD

        view.addSubview(tilesLabel)
        view.addSubview(timerLabel)

        let headerTop = view.safeAreaLayoutGuide.topAnchor
        NSLayoutConstraint.activate([
            modeControl.topAnchor.constraint(equalTo: headerTop, constant: 6),
            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.widthAnchor.constraint(equalToConstant: 300),

            tilesLabel.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 6),
            tilesLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),

            timerLabel.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 6),
            timerLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    private func buildGameView() {
        gameView.translatesAutoresizingMaskIntoConstraints = false
        gameView.onStatusChanged = { [weak self] tilesLeft, timer in
            self?.tilesLabel.text = "Tiles: \(tilesLeft)"
            self?.timerLabel.text = FredsweeperBoard.formatTimer(timer)
        }
        view.addSubview(gameView)

        NSLayoutConstraint.activate([
            gameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameView.topAnchor.constraint(equalTo: tilesLabel.bottomAnchor, constant: 6),
            gameView.bottomAnchor.constraint(equalTo: controlsStack.topAnchor, constant: -6)
        ])
    }

    private func buildControls() {
        controlsStack.axis = .vertical
        controlsStack.alignment = .center
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsStack)

        let primaryControls = UIStackView()
        primaryControls.axis = .horizontal
        primaryControls.alignment = .center
        primaryControls.spacing = 12

        configureFlagButton()
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = UIColor(white: 0.72, alpha: 1)

        closeButton.setTitle("CLOSE", for: .normal)
        closeButton.titleLabel?.font = .boldSystemFont(ofSize: 12)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor(red: 227/255, green: 36/255, blue: 27/255, alpha: 0.85)
        closeButton.layer.cornerRadius = 7
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 12)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        primaryControls.addArrangedSubview(flagButton)
        primaryControls.addArrangedSubview(statusLabel)
        primaryControls.addArrangedSubview(closeButton)
        controlsStack.addArrangedSubview(primaryControls)

        if scheme == .cursor {
            let pad = UIStackView()
            pad.axis = .horizontal
            pad.alignment = .center
            pad.spacing = 8

            pad.addArrangedSubview(controlButton("◀") { [weak self] in self?.gameView.moveCursor(dx: -1, dy: 0) })
            pad.addArrangedSubview(controlButton("▲") { [weak self] in self?.gameView.moveCursor(dx: 0, dy: -1) })
            pad.addArrangedSubview(controlButton("▼") { [weak self] in self?.gameView.moveCursor(dx: 0, dy: 1) })
            pad.addArrangedSubview(controlButton("▶") { [weak self] in self?.gameView.moveCursor(dx: 1, dy: 0) })
            pad.addArrangedSubview(controlButton("OPEN") { [weak self] in self?.gameView.activateCursor() })
            controlsStack.addArrangedSubview(pad)
        }

        NSLayoutConstraint.activate([
            controlsStack.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -10
            ),
            controlsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func controlButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 12)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        button.layer.cornerRadius = 7
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 10, bottom: 7, right: 10)
        button.addClosure(action)
        return button
    }

    private func configureFlagButton() {
        flagButton.titleLabel?.font = .boldSystemFont(ofSize: 12)
        flagButton.tintColor = .white
        flagButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        flagButton.layer.cornerRadius = 7
        flagButton.layer.borderWidth = 1
        flagButton.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        flagButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 10, bottom: 7, right: 10)

        switch scheme {
        case .flagToggle:
            flagButton.setTitle("FLAG: OFF", for: .normal)
            flagButton.addTarget(self, action: #selector(flagToggleTapped), for: .touchUpInside)
        case .flagModifier:
            flagButton.setTitle("HOLD FLAG", for: .normal)
            flagButton.addTarget(self, action: #selector(flagHoldDown), for: .touchDown)
            flagButton.addTarget(
                self,
                action: #selector(flagHoldUp),
                for: [.touchUpInside, .touchUpOutside, .touchCancel]
            )
        case .longPress:
            flagButton.setTitle("HOLD TILE", for: .normal)
            flagButton.isEnabled = false
            flagButton.alpha = 0.45
        case .cursor:
            flagButton.setTitle("FLAG @", for: .normal)
            flagButton.addTarget(self, action: #selector(flagCursorTapped), for: .touchUpInside)
        }
    }

    private func updateStatusLabel() {
        statusLabel.text = "\(scheme.title) • 2.2 assets"
    }

    // MARK: - Actions

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        currentMode = sender.selectedSegmentIndex
        gameView.configure(minigameID: minigameID(for: currentMode))
    }

    @objc private func flagToggleTapped() {
        flagModeOn.toggle()
        flagButton.setTitle(flagModeOn ? "FLAG: ON" : "FLAG: OFF", for: .normal)
        flagButton.tintColor = flagModeOn ? .systemYellow : .white
        gameView.setFlagMode(flagModeOn)
    }

    @objc private func flagHoldDown() {
        gameView.setFlagHeld(true)
        flagButton.tintColor = .systemYellow
    }

    @objc private func flagHoldUp() {
        gameView.setFlagHeld(false)
        flagButton.tintColor = .white
    }

    @objc private func flagCursorTapped() {
        gameView.toggleFlagAtCursor()
    }

    @objc private func closeTapped() {
        gameView.suspend()
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }
}

private extension UIButton {
    private struct FredsweeperClosureKey { static var closure: UInt8 = 0 }

    func addClosure(_ closure: @escaping () -> Void) {
        objc_setAssociatedObject(self, &FredsweeperClosureKey.closure, closure, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(self, action: #selector(runFredsweeperClosure), for: .touchUpInside)
    }

    @objc private func runFredsweeperClosure() {
        guard let closure = objc_getAssociatedObject(self, &FredsweeperClosureKey.closure) as? () -> Void else {
            return
        }
        closure()
    }
}
