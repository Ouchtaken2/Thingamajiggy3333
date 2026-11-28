import UIKit

/// Native CoreGraphics renderer for the recovered 2.2 Fredsweeper assets.
/// It intentionally draws the original 160x144 minigame surface, then scales
/// that surface to fit while preserving pixel art with nearest-neighbour
/// interpolation.
final class FredsweeperView: UIView {

    var onStatusChanged: ((_ tilesLeft: Int, _ timer: TimeInterval) -> Void)?
    var showInternalHUD = true

    private(set) var board: FredsweeperBoard!
    private(set) var minigameID = "fredsweeper"

    private var surfaceWidth: CGFloat = 160
    private var surfaceHeight: CGFloat = 144
    private var sprites: [CGImage] = []
    private var fontFrames: [CGImage] = []

    private var displayLink: CADisplayLink?
    private var origin = CGPoint.zero
    private var scale: CGFloat = 1

    private var activeTouch: UITouch?
    private var activeTile: Int?
    private var previewOrigin: Int?
    private var touchStartedAt = Date()
    private var longPressTile: Int?
    private var longPressFired = false

    private var flagMode = false
    private(set) var flagHeld = false
    private var scheme: FredsweeperTouchScheme = AppConfigStore.shared.fredsweeperScheme

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    private let notifyFeedback = UINotificationFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 18/255, alpha: 1)
        contentMode = .redraw
        isMultipleTouchEnabled = false
        startDisplayLink()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Configuration

    func configure(minigameID: String) {
        self.minigameID = minigameID
        self.scheme = AppConfigStore.shared.fredsweeperScheme
        self.showInternalHUD = !AppConfigStore.shared.externalMinigameHUD
        clearTouchState()

        guard let minigame = PortManifestStore.shared.minigame(minigameID) else {
            DiagnosticLog.shared.add(
                "native minigame manifest missing for \(minigameID); using built-in fallback",
                level: "WARN",
                source: "native"
            )
            surfaceWidth = 160
            surfaceHeight = 144
            board = FredsweeperBoard(width: 10, height: 8, tileSize: 16, mines: 10)
            sprites = []
            fontFrames = []
            publishStatus()
            setNeedsDisplay()
            return
        }

        surfaceWidth = CGFloat(minigame.surfaceWidth)
        surfaceHeight = CGFloat(minigame.surfaceHeight)
        board = FredsweeperBoard(
            width: minigame.boardWidth,
            height: minigame.boardHeight,
            tileSize: minigame.tileSize,
            mines: minigame.mines
        )

        let tileSetID = minigame.spriteSets.contains(where: { $0.id == "tiles" }) ? "tiles" : "tilesSmall"
        sprites = loadImages(PortManifestStore.shared.spriteURLs(tileSetID, in: minigameID))
        fontFrames = loadImages(PortManifestStore.shared.fontURLs("gameboy", in: minigameID))

        DiagnosticLog.shared.add(
            "native \(minigameID): board \(minigame.boardWidth)x\(minigame.boardHeight), " +
            "mines \(minigame.mines), tile frames \(sprites.count), font frames \(fontFrames.count)",
            source: "native"
        )

        updateTransform()
        publishStatus()
        setNeedsDisplay()
    }

    private func loadImages(_ urls: [URL]) -> [CGImage] {
        urls.compactMap { UIImage(contentsOfFile: $0.path)?.cgImage }
    }

    // MARK: - Display loop

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func suspend() {
        displayLink?.isPaused = true
    }

    func resume() {
        displayLink?.isPaused = false
        setNeedsDisplay()
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard let board else { return }

        let dt = link.duration > 0 ? min(link.duration, 1/15) : 1/60
        board.advance(dt)

        if scheme == .longPress, !longPressFired, let tile = longPressTile,
           let touch = activeTouch, Date().timeIntervalSince(touchStartedAt) >= 0.28 {
            longPressFired = true
            applyFlag(at: tile)
            previewOrigin = nil
        }

        publishStatus()
        setNeedsDisplay()
    }

    private func publishStatus() {
        guard let board else { return }
        onStatusChanged?(board.tilesLeft, board.timer)
    }

    // MARK: - Layout / rendering

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTransform()
        setNeedsDisplay()
    }

    private func updateTransform() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let fit = min(bounds.width / surfaceWidth, bounds.height / surfaceHeight)
        let requested = CGFloat(AppConfigStore.shared.minigameScale)
        scale = max(0.5, min(requested, fit))
        origin = CGPoint(
            x: (bounds.width - surfaceWidth * scale) / 2,
            y: (bounds.height - surfaceHeight * scale) / 2
        )
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let board else { return }
        updateTransform()

        context.saveGState()
        context.translateBy(x: origin.x, y: origin.y)
        context.scaleBy(x: scale, y: scale)
        context.setAllowsAntialiasing(false)
        context.interpolateQuality = .none

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: surfaceWidth, height: surfaceHeight))

        let tileSize = CGFloat(board.tileSize)
        for y in 0..<board.height {
            for x in 0..<board.width {
                let frame = CGRect(
                    x: CGFloat(x * board.tileSize),
                    y: CGFloat(y * board.tileSize) + 16,
                    width: tileSize,
                    height: tileSize
                )
                drawTile(context: context, x: x, y: y, frame: frame, board: board)
                drawCursorIfNeeded(context: context, x: x, y: y, frame: frame, board: board)
            }
        }

        if showInternalHUD {
            drawHUD(context: context, board: board)
        }

        context.restoreGState()
    }

    private func drawTile(context: CGContext, x: Int, y: Int, frame: CGRect, board: FredsweeperBoard) {
        let index = (y * board.width) + x
        let value = board.tiles[index]
        let cover = board.covers[index]

        var baseFrame = value
        if value == 9 {
            baseFrame = 9 + (Int(board.deathFrames * 8) % 2)
        }

        let previewed = isPreviewed(x: x, y: y, cover: cover)
        drawFrame(baseFrame, in: frame, context: context, fallback: fallbackColor(for: value))

        if cover != 0 && !previewed {
            let coverFrame = ((x + y) % 2) + 9 + (cover * 2)
            let coverColor: UIColor = cover == 2
                ? UIColor(red: 0.75, green: 0.62, blue: 0.20, alpha: 1)
                : UIColor(red: 0.12, green: 0.20, blue: 0.34, alpha: 1)
            drawFrame(coverFrame, in: frame, context: context, fallback: coverColor)
        }
    }

    private func isPreviewed(x: Int, y: Int, cover: Int) -> Bool {
        guard let previewOrigin, cover == 1, let board else { return false }
        let ox = previewOrigin % board.width
        let oy = previewOrigin / board.width
        return abs(x - ox) <= 1 && abs(y - oy) <= 1 && (x != ox || y != oy)
    }

    private func drawFrame(_ index: Int, in frame: CGRect, context: CGContext, fallback: UIColor) {
        if index >= 0, index < sprites.count {
            context.draw(sprites[index], in: frame)
        } else {
            context.setFillColor(fallback.cgColor)
            context.fill(frame)
        }
    }

    private func fallbackColor(for value: Int) -> UIColor {
        switch value {
        case 0: return UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)
        case 9: return UIColor(red: 0.78, green: 0.13, blue: 0.10, alpha: 1)
        default: return UIColor(red: 0.20, green: 0.34, blue: 0.56, alpha: 1)
        }
    }

    private func drawCursorIfNeeded(context: CGContext, x: Int, y: Int, frame: CGRect, board: FredsweeperBoard) {
        guard scheme == .cursor, x == board.cursorX, y == board.cursorY else { return }
        context.setStrokeColor(UIColor(red: 0.95, green: 0.88, blue: 0.30, alpha: 1).cgColor)
        context.setLineWidth(1)
        context.stroke(frame.insetBy(dx: 0.5, dy: 0.5))
    }

    // MARK: - HUD text

    private func drawHUD(context: CGContext, board: FredsweeperBoard) {
        let background = UIColor(red: 0, green: 47/255, blue: 51/255, alpha: 1)
        context.setFillColor(background.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: surfaceWidth, height: 16))

        let light = UIColor(red: 224/255, green: 248/255, blue: 208/255, alpha: 1)
        drawPixelText(context, "Tiles: \(board.tilesLeft)", at: CGPoint(x: 2, y: 4), color: light)

        let timer = FredsweeperBoard.formatTimer(board.timer)
        let timerX = 158 - pixelTextWidth(timer)
        drawPixelText(context, timer, at: CGPoint(x: timerX, y: 4), color: light)
    }

    private func pixelGlyphIndex(_ character: Character) -> Int? {
        guard let scalar = String(character).unicodeScalars.first?.value else { return nil }
        if scalar >= 65 && scalar <= 90 { return Int(scalar - 65) }
        if scalar >= 97 && scalar <= 122 { return 32 + Int(scalar - 97) }
        if scalar >= 48 && scalar <= 57 { return 64 + Int(scalar - 48) }
        if scalar == 58 { return 77 }
        return 79
    }

    private func pixelGlyphWidth(_ character: Character) -> CGFloat {
        guard let index = pixelGlyphIndex(character), index < fontFrames.count else { return 4 }
        return CGFloat(fontFrames[index].width)
    }

    private func pixelTextWidth(_ text: String) -> CGFloat {
        guard !fontFrames.isEmpty else { return CGFloat(text.count * 5) }
        let total = text.reduce(CGFloat(0)) { $0 + pixelGlyphWidth($1) + 1 }
        return max(0, total - 1)
    }

    private func drawPixelText(_ context: CGContext, _ text: String, at point: CGPoint, color: UIColor) {
        if fontFrames.isEmpty {
            NSString(string: text).draw(at: point, withAttributes: [
                .font: UIFont.systemFont(ofSize: 7, weight: .bold),
                .foregroundColor: color
            ])
            return
        }

        var cursorX = point.x
        for character in text {
            guard let index = pixelGlyphIndex(character), index < fontFrames.count else {
                cursorX += 4
                continue
            }
            let image = fontFrames[index]
            let glyphWidth = CGFloat(image.width)
            let glyphHeight = CGFloat(image.height)
            let glyphY = point.y + max(0, (7 - glyphHeight) / 2)
            context.draw(image, in: CGRect(x: cursorX, y: glyphY, width: glyphWidth, height: glyphHeight))
            cursorX += glyphWidth + 1
        }
    }

    // MARK: - Touch schemes

    private func tileIndex(at point: CGPoint) -> Int? {
        guard let board else { return nil }
        let localX = (point.x - origin.x) / scale
        let localY = (point.y - origin.y) / scale
        guard localX >= 0, localY >= 16 else { return nil }

        let x = Int(floor(localX / CGFloat(board.tileSize)))
        let y = Int(floor((localY - 16) / CGFloat(board.tileSize)))
        guard x >= 0, x < board.width, y >= 0, y < board.height else { return nil }
        return (y * board.width) + x
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let board,
              let index = tileIndex(at: touch.location(in: self)) else { return }

        activeTouch = touch
        activeTile = index
        longPressFired = false
        longPressTile = nil
        touchStartedAt = Date()

        let point = boardPoint(index)
        switch scheme {
        case .flagToggle:
            if flagMode {
                applyFlag(at: index)
            } else if isRevealedNumber(index, board: board) {
                previewOrigin = index
            }
        case .flagModifier:
            if flagHeld {
                applyFlag(at: index)
            } else if isRevealedNumber(index, board: board) {
                previewOrigin = index
            }
        case .longPress:
            if board.covers[index] == 1 {
                longPressTile = index
            } else if isRevealedNumber(index, board: board) {
                previewOrigin = index
            }
        case .cursor:
            board.cursorX = point.x
            board.cursorY = point.y
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch), let board else { return }
        guard let index = tileIndex(at: touch.location(in: self)) else { return }

        if index != activeTile {
            activeTile = index
        }

        if scheme == .cursor {
            let point = boardPoint(index)
            board.cursorX = point.x
            board.cursorY = point.y
        } else if previewOrigin != nil {
            // Keep chord preview anchored to the last revealed number under
            // the finger; dragging across numbers retargets the chord.
            if isRevealedNumber(index, board: board) {
                previewOrigin = index
            }
        }

        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let endTile = tileIndex(at: touch.location(in: self)) ?? activeTile

        switch scheme {
        case .flagToggle:
            if !flagMode { performPrimary(at: endTile) }
        case .flagModifier:
            if !flagHeld { performPrimary(at: endTile) }
        case .longPress:
            if !longPressFired { performPrimary(at: endTile) }
        case .cursor:
            break
        }

        clearTouchState()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearTouchState()
    }

    private func boardPoint(_ index: Int) -> (x: Int, y: Int) {
        guard let board else { return (0, 0) }
        return (index % board.width, index / board.width)
    }

    private func isRevealedNumber(_ index: Int, board: FredsweeperBoard) -> Bool {
        board.covers[index] == 0 && (1...8).contains(board.tiles[index])
    }

    private func performPrimary(at index: Int?) {
        guard let index, let board else { return }
        let point = boardPoint(index)

        if let previewOrigin {
            let originPoint = boardPoint(previewOrigin)
            let result = board.chord(x: originPoint.x, y: originPoint.y)
            if result.triggered { impactFeedback.impactOccurred() }
            if result.mineHit { notifyFeedback.notificationOccurred(.error) }
        } else if board.covers[index] == 1 {
            let result = board.reveal(x: point.x, y: point.y)
            if result.changed { impactFeedback.impactOccurred() }
            if result.mineHit { notifyFeedback.notificationOccurred(.error) }
        }

        if board.phase == .won {
            notifyFeedback.notificationOccurred(.success)
        }
    }

    private func applyFlag(at index: Int) {
        guard let board else { return }
        let point = boardPoint(index)
        if board.toggleFlag(x: point.x, y: point.y) {
            impactFeedback.impactOccurred()
        }
    }

    private func clearTouchState() {
        activeTouch = nil
        activeTile = nil
        previewOrigin = nil
        longPressTile = nil
        longPressFired = false
        setNeedsDisplay()
    }

    // MARK: - External control hooks

    /// Sticky FLAG mode used by `flagToggle` and the cursor scheme.
    func setFlagMode(_ enabled: Bool) {
        flagMode = enabled
        impactFeedback.impactOccurred()
    }

    /// Two-thumb speed scheme: hold FLAG with one finger, tap with the other.
    func setFlagHeld(_ held: Bool) {
        flagHeld = held
        if held { flagMode = false }
    }

    func moveCursor(dx: Int, dy: Int) {
        board?.moveCursor(dx: dx, dy: dy)
        setNeedsDisplay()
    }

    func activateCursor() {
        guard let board else { return }
        performPrimary(at: board.cursorIndex)
    }

    func toggleFlagAtCursor() {
        guard let board else { return }
        let point = boardPoint(board.cursorIndex)
        if board.toggleFlag(x: point.x, y: point.y) {
            impactFeedback.impactOccurred()
        }
    }
}
