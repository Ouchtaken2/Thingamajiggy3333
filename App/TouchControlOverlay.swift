import UIKit

/// Translucent on-screen gamepad. Only the buttons intercept touches; all
/// other touches fall through to the WKWebView underneath.
final class TouchControlOverlay: UIView {

    var onKey: ((_ entry: TouchEntry, _ down: Bool) -> Void)?
    var onMouseModeChanged: ((_ enabled: Bool) -> Void)?
    var onPauseToggle: (() -> Void)?
    var onSettings: (() -> Void)?
    var onZoomToggle: (() -> Void)?
    var onNativeDemo: (() -> Void)?

    private var actionButtons: [ActionButton] = []
    private var sizedControls: [SizedControl] = []
    private var mouseEnabled = false
    private var mouseButton: UIButton!
    private var zoomButton: UIButton!

    private struct SizedControl {
        let view: UIButton
        let baseSize: CGFloat
        let width: NSLayoutConstraint
        let height: NSLayoutConstraint
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        buildControls()

        TouchMappingStore.shared.onChange = { [weak self] in
            self?.refreshTitles()
        }
        ControlProfileStore.shared.onChange = { [weak self] in
            self?.refreshConfig()
        }
    }

    /// Called by GameViewController when app config changes (it owns the
    /// single AppConfigStore.onChange closure).
    func refreshConfig() {
        let config = AppConfigStore.shared
        let profile = ControlProfileStore.shared.profile()
        let scale = config.uiScale * profile.uiScale

        zoomButton.isHidden = !config.showZoomButton

        for control in sizedControls {
            control.width.constant = control.baseSize * scale
            control.height.constant = control.baseSize * scale
            control.view.alpha = profile.buttonOpacity
        }

        for button in actionButtons {
            switch button.action {
            case .up, .down, .left, .right:
                button.isHidden = !profile.showDpad
            default:
                button.isHidden = !profile.showActionButtons
            }
        }
    }

    func setZoomLabel(_ text: String) {
        zoomButton.setTitle(text, for: .normal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The overlay covers the whole screen, but only its buttons should take
    /// taps. Returning nil for the overlay itself lets taps in empty areas
    /// fall through to the WKWebView (needed for the game's own on-screen
    /// prompts, doors, monitor tabs, etc.).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit === self ? nil : hit
    }

    private func buildControls() {
        // D-pad (left side)
        addButton(.up,    glyph: "▲", x: -0.060, y: -0.085)
        addButton(.down,  glyph: "▼", x: -0.060, y:  0.085)
        addButton(.left,  glyph: "◀", x: -0.115, y:  0.000)
        addButton(.right, glyph: "▶", x: -0.005, y:  0.000)

        // Action cluster (right side)
        addButton(.x,  glyph: "X", x:  0.005, y: -0.085)
        addButton(.y,  glyph: "Y", x: -0.060, y:  0.000)
        addButton(.a,  glyph: "A", x:  0.060, y:  0.000)
        addButton(.b,  glyph: "B", x:  0.005, y:  0.085)
        addButton(.l1, glyph: "L", x:  0.060, y: -0.085)
        addButton(.r1, glyph: "R", x:  0.115, y:  0.000)

        // Utilities
        place(utilityButton("II") { [weak self] in self?.onPauseToggle?() },
              x: -0.44, y: -0.45, size: 38)

        place(utilityButton("2.2 DEMO") { [weak self] in self?.onNativeDemo?() },
              x: -0.22, y: -0.45, size: 74)

        place(utilityButton("⚙") { [weak self] in self?.onSettings?() },
              x: 0.0, y: -0.45, size: 38)

        zoomButton = utilityButton("🔍 1×") { [weak self] in self?.onZoomToggle?() }
        place(zoomButton, x: 0.22, y: -0.45, size: 58)

        mouseButton = utilityButton("MOUSE: OFF") { [weak self] in
            guard let self else { return }
            self.mouseEnabled.toggle()
            self.mouseButton.setTitle(self.mouseEnabled ? "MOUSE: ON" : "MOUSE: OFF", for: .normal)
            self.mouseButton.tintColor = self.mouseEnabled ? .systemGreen : .white
            self.onMouseModeChanged?(self.mouseEnabled)
        }
        place(mouseButton, x: 0.44, y: -0.45, size: 104)

        refreshTitles()
        refreshConfig()
    }

    /// Creates and places in one step. Kept separate from `place` so the two
    /// calls don't share `x:`/`y:` labels (which confuses Swift overload
    /// resolution when nested).
    private func addButton(_ action: TouchAction, glyph: String, x: CGFloat, y: CGFloat) {
        let button = ActionButton(action: action, glyph: glyph)
        button.addTarget(self, action: #selector(keyDown(_:)), for: .touchDown)
        button.addTarget(
            self,
            action: #selector(keyUp(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        actionButtons.append(button)
        place(button, x: x, y: y)
    }

    private func utilityButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 12)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        button.addClosure(action)
        return button
    }

    @discardableResult
    private func place(_ button: UIButton, x: CGFloat, y: CGFloat, size: CGFloat = 54)
        -> (width: NSLayoutConstraint, height: NSLayoutConstraint) {
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)

        let width = button.widthAnchor.constraint(equalToConstant: size)
        let height = button.heightAnchor.constraint(equalToConstant: size)

        // Use multipliers against the overlay's own centre. Multiplying
        // UIScreen.main.bounds at build time breaks in landscape: the screen
        // reports portrait dimensions before layout settles and every control
        // ends up crammed near the centre. The item-based NSLayoutConstraint
        // API is used because NSLayoutYAxisAnchor has no public
        // constraint(equalTo:multiplier:) overload.
        let centerX = NSLayoutConstraint(
            item: button, attribute: .centerX,
            relatedBy: .equal,
            toItem: self, attribute: .centerX,
            multiplier: 1 + 2 * x, constant: 0
        )
        let centerY = NSLayoutConstraint(
            item: button, attribute: .centerY,
            relatedBy: .equal,
            toItem: self, attribute: .centerY,
            multiplier: 1 + 2 * y, constant: 0
        )
        NSLayoutConstraint.activate([width, height, centerX, centerY])

        sizedControls.append(SizedControl(
            view: button,
            baseSize: size,
            width: width,
            height: height
        ))
        return (width, height)
    }

    private func refreshTitles() {
        for button in actionButtons {
            let label = TouchMappingStore.shared.label(for: button.action)
            let attributed = NSMutableAttributedString()
            attributed.append(NSAttributedString(
                string: button.glyph + "\n",
                attributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.white]
            ))
            attributed.append(NSAttributedString(
                string: label,
                attributes: [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor(white: 0.78, alpha: 1)]
            ))
            button.setAttributedTitle(attributed, for: .normal)
        }
    }

    @objc private func keyDown(_ sender: ActionButton) {
        fire(sender, down: true)
    }

    @objc private func keyUp(_ sender: ActionButton) {
        fire(sender, down: false)
    }

    private func fire(_ sender: ActionButton, down: Bool) {
        let entry = TouchMappingStore.shared.entry(for: sender.action)
        onKey?(entry, down)
    }
}

// MARK: - Buttons

final class ActionButton: UIButton {
    let action: TouchAction
    let glyph: String

    init(action: TouchAction, glyph: String) {
        self.action = action
        self.glyph = glyph
        super.init(frame: .zero)
        titleLabel?.numberOfLines = 2
        titleLabel?.textAlignment = .center
        tintColor = .white
        backgroundColor = UIColor.black.withAlphaComponent(0.42)
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private extension UIButton {
    private struct AssociatedKey { static var closure: UInt8 = 0 }

    func addClosure(_ closure: @escaping () -> Void) {
        objc_setAssociatedObject(self, &AssociatedKey.closure, closure, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(self, action: #selector(runClosure), for: .touchUpInside)
    }

    @objc private func runClosure() {
        guard let closure = objc_getAssociatedObject(self, &AssociatedKey.closure) as? () -> Void else { return }
        closure()
    }
}

/// Captures taps in empty game areas and turns them into synthetic mouse
/// events, needed for doors / monitor tabs in the office.
final class MouseCaptureView: UIView {
    var onEvent: ((_ type: String, _ x: Int, _ y: Int) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, "mousedown")
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, "mousemove")
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, "mouseup")
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        send(touches, "mouseup")
    }

    private func send(_ touches: Set<UITouch>, _ type: String) {
        guard let point = touches.first?.location(in: self) else { return }
        onEvent?(type, Int(point.x), Int(point.y))
    }
}
