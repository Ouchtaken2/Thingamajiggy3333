import UIKit
import WebKit

final class GameViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {

    private static let scheme = "fb3"
    private static let statsHandler = "fb3stats"

    private var webView: WKWebView!
    private var intro: UIView!
    private var overlay: TouchControlOverlay!
    private var hudLabel: UILabel!

    /// Mutually exclusive input layer: tap-to-mouse, or tap/drag-to-pan while
    /// the canvas is zoomed. Nil when neither applies.
    private var inputCapture: UIView?
    private var mouseEnabled = false

    // Zoom state (session-only, not persisted).
    private let zoomLevels: [CGFloat] = [1, 2, 3]
    private var zoomIndex = 0
    private var panX: CGFloat = 0
    private var panY: CGFloat = 0

    // Stats HUD state.
    private var currentFPS = 0
    private var statsTimer: Timer?

    private var didStart = false
    private var paused = false

    private let config = AppConfigStore.shared

    deinit {
        statsTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
        webView?.configuration.userContentController
            .removeScriptMessageHandler(forName: Self.statsHandler)
        AppConfigStore.shared.onChange = nil
    }

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
        buildWebView()
        buildIntro()
        buildOverlay()
        buildHUD()
        applyHUDVisibility()
        registerLifecycle()

        // GameViewController is the sole owner of this closure; after any
        // setting change it refreshes the overlay, HUD and game speed.
        config.onChange = { [weak self] in
            guard let self else { return }
            self.applyGameSpeed()
            self.applyHUDVisibility()
            self.overlay.refreshConfig()
            if !self.config.showZoomButton && self.zoomIndex != 0 {
                self.zoomIndex = 0
                self.applyZoom()
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Web view

    private func buildWebView() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(GameURLSchemeHandler(), forURLScheme: Self.scheme)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Always-on helpers injected before the page scripts run.
        let userContent = config.userContentController
        userContent.add(self, name: Self.statsHandler)
        // The bundled 4LD loader has its own click-to-start overlay and tries
        // to use the Fullscreen API. Neither applies inside a native app.
        userContent.addUserScript(WKUserScript(
            source: "window.__FB3_EMBED = true;",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        userContent.addUserScript(WebBridge.speedScript(initialSpeed: self.config.gameSpeed))
        userContent.addUserScript(WebBridge.statsScript())

        // Stop Safari-style scrolling / zoom / callouts on the game canvas.
        let css = "html,body{margin:0;padding:0;overflow:hidden;touch-action:none;" +
                  "-webkit-user-select:none;user-select:none}" +
                  "canvas{touch-action:none;-webkit-touch-callout:none}"
        let cssScript = WKUserScript(
            source: "var s=document.createElement('style');s.textContent='\(css)';" +
                    "(document.head||document.documentElement).appendChild(s);",
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        userContent.addUserScript(cssScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.contentMode = .scaleAspectFit

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.webView = webView

        webView.load(URLRequest(url: URL(string: "\(Self.scheme)://local/index.html")!))
    }

    // MARK: - Stats

    private func buildHUD() {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.textAlignment = .center
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.isHidden = true
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),
            label.heightAnchor.constraint(equalToConstant: 24)
        ])
        self.hudLabel = label
    }

    private func applyHUDVisibility() {
        let show = config.showFPS || config.showRAM
        hudLabel.isHidden = !show
        if show {
            refreshHUDText()
            if statsTimer == nil {
                statsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.refreshHUDText()
                }
            }
        } else {
            statsTimer?.invalidate()
            statsTimer = nil
        }
    }

    private func refreshHUDText() {
        var parts: [String] = []
        if config.showFPS { parts.append("\(currentFPS) FPS") }
        if config.showRAM {
            let mb = MemoryMonitor.usedMegabytes()
            parts.append(mb >= 0 ? String(format: "%.0f MB", mb) : "RAM n/a")
        }
        hudLabel.text = parts.joined(separator: "  •  ")
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == Self.statsHandler,
              let body = message.body as? [String: Any],
              let fps = (body["fps"] as? NSNumber)?.intValue else { return }
        currentFPS = fps
        if !hudLabel.isHidden { refreshHUDText() }
    }

    // MARK: - Game speed

    private func applyGameSpeed() {
        WebBridge.setSpeed(webView, speed: config.gameSpeed)
    }

    // MARK: - Intro

    private func buildIntro() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 18/255, alpha: 1)

        let title = UILabel()
        title.text = "Frickbear's 3\nFour Layers Down 2.1.5"
        title.textColor = .white
        title.font = .boldSystemFont(ofSize: 32)
        title.textAlignment = .center
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "Unofficial iOS wrapper • Fan-made • Landscape\nInternet required on first launch (several hundred MB)"
        subtitle.textColor = UIColor(white: 0.75, alpha: 1)
        subtitle.font = .systemFont(ofSize: 13)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0

        let note = UILabel()
        note.text = "Personal use only. Game by SpookyRick,\n4LD web port by Reeyuki. See CREDITS."
        note.textColor = UIColor(white: 0.5, alpha: 1)
        note.font = .systemFont(ofSize: 11)
        note.textAlignment = .center
        note.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("TAP TO START", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = UIColor(red: 227/255, green: 36/255, blue: 27/255, alpha: 1)
        button.tintColor = .white
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        button.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, subtitle, button, note])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])

        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.intro = container
    }

    @objc private func startTapped() {
        startGame()
    }

    private func startGame() {
        guard !didStart else { return }
        didStart = true

        intro.removeFromSuperview()
        overlay.isHidden = false
        WebBridge.start(webView)

        // The page may still be booting; re-apply start helpers once settled.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            WebBridge.start(self.webView)
            self.applyGameSpeed()
            self.applyZoom()
        }
    }

    // MARK: - Zoom & input capture

    private func applyZoom() {
        let scale = zoomLevels[zoomIndex]
        if scale == 1 { panX = 0; panY = 0 }
        WebBridge.setZoom(webView, scale: scale, tx: panX, ty: panY)
        overlay.setZoomLabel(scale == 1 ? "🔍 1×" : "🔍 \(Int(scale))×")
        applyInputCapture()
    }

    /// Zoom wins over mouse mode: while zoomed, a tap clicks and a drag pans.
    private func applyInputCapture() {
        inputCapture?.removeFromSuperview()
        inputCapture = nil

        if zoomLevels[zoomIndex] > 1 {
            let capture = ZoomPanView()
            capture.translatesAutoresizingMaskIntoConstraints = false
            capture.onTap = { [weak self] x, y in
                guard let self else { return }
                WebBridge.injectMouse(self.webView, type: "mousedown", x: x, y: y)
                WebBridge.injectMouse(self.webView, type: "mouseup", x: x, y: y)
            }
            capture.onPan = { [weak self] dx, dy in
                guard let self else { return }
                self.panX += dx
                self.panY += dy
                WebBridge.setZoom(self.webView,
                                  scale: self.zoomLevels[self.zoomIndex],
                                  tx: self.panX, ty: self.panY)
            }
            installCapture(capture)
        } else if mouseEnabled {
            let capture = MouseCaptureView()
            capture.translatesAutoresizingMaskIntoConstraints = false
            capture.onEvent = { [weak self] type, x, y in
                guard let self else { return }
                WebBridge.injectMouse(self.webView, type: type, x: x, y: y)
            }
            installCapture(capture)
        }
    }

    private func installCapture(_ capture: UIView) {
        view.insertSubview(capture, belowSubview: overlay)
        NSLayoutConstraint.activate([
            capture.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            capture.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            capture.topAnchor.constraint(equalTo: view.topAnchor),
            capture.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        inputCapture = capture
    }

    // MARK: - Touch controls

    private func buildOverlay() {
        let overlay = TouchControlOverlay()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isHidden = true

        overlay.onKey = { [weak self] entry, down in
            guard let self, self.didStart else { return }
            WebBridge.injectKey(self.webView, entry: entry, down: down)
        }

        overlay.onPauseToggle = { [weak self] in
            guard let self, self.didStart else { return }
            self.paused.toggle()
            if self.paused {
                WebBridge.pause(self.webView)
            } else {
                WebBridge.resume(self.webView)
            }
        }

        overlay.onSettings = { [weak self] in
            guard let self, self.didStart else { return }
            let wasPaused = self.paused
            WebBridge.pause(self.webView)

            let settings = SettingsViewController()
            settings.onDismiss = { [weak self] in
                guard let self, !wasPaused else { return }
                WebBridge.resume(self.webView)
            }
            let navigation = UINavigationController(rootViewController: settings)
            settings.onInspect = { [weak self, weak navigation] in
                guard let self, let navigation else { return }
                WebBridge.inspect(self.webView) { text in
                    DispatchQueue.main.async {
                        navigation.pushViewController(
                            InspectViewController(text: text),
                            animated: true
                        )
                    }
                }
            }
            navigation.modalPresentationStyle = .overFullScreen
            self.present(navigation, animated: true)
        }

        overlay.onZoomToggle = { [weak self] in
            guard let self, self.didStart else { return }
            self.zoomIndex = (self.zoomIndex + 1) % self.zoomLevels.count
            self.applyZoom()
        }

        overlay.onMouseModeChanged = { [weak self] enabled in
            guard let self else { return }
            self.mouseEnabled = enabled
            self.applyInputCapture()
        }

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.overlay = overlay
    }

    // MARK: - Navigation

    /// The HTML shell is local, but the pinned 4LD 2.1.5 runtime and game data
    /// come from jsDelivr / GitHub raw. Allow HTTPS subresources while still
    /// refusing to navigate the main frame to an external page.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == Self.scheme || scheme == "about" || scheme == "data" {
            decisionHandler(.allow)
        } else if scheme == "https" && navigationAction.targetFrame?.isMainFrame != true {
            decisionHandler(.allow)
        } else {
            NSLog("[fb3] blocked external navigation: %@", url.absoluteString)
            decisionHandler(.cancel)
        }
    }

    // MARK: - Lifecycle

    private func registerLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResign),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecome),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func willResign() {
        guard didStart else { return }
        WebBridge.pause(webView)
    }

    @objc private func didBecome() {
        guard didStart else { return }
        paused = false
        WebBridge.resume(webView)
    }
}
