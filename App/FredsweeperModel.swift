import Foundation

/// Board lifecycle. `waiting` means mines have not been placed yet, matching
/// GameMaker's `WaitForClick` flag in the recovered Fredsweeper GML.
enum FredsweeperPhase {
    case waiting
    case playing
    case won
    case lost
}

struct FredsweeperRevealResult {
    var changed = false
    var mineHit = false
}

struct FredsweeperChordResult {
    var triggered = false
    var mineHit = false
}

/// Swift port of the custom `Code/Reference` Fredsweeper logic. Values follow
/// the original GameMaker semantics: tiles 0-8 are numbers, 9 is a mine;
/// covers 1 = hidden, 2 = flagged, 0 = revealed.
final class FredsweeperBoard {

    let width: Int
    let height: Int
    let tileSize: Int
    let mines: Int

    private(set) var tiles: [Int]
    private(set) var covers: [Int]
    private(set) var phase: FredsweeperPhase = .waiting
    private(set) var timer: TimeInterval = 0
    private(set) var deathFrames: TimeInterval = 0
    private(set) var tilesCleared = 0
    private(set) var cursorX: Int
    private(set) var cursorY: Int

    init(width: Int, height: Int, tileSize: Int, mines: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
        self.tileSize = max(1, tileSize)
        let safeBoardSize = max(1, self.width * self.height)
        self.mines = max(0, min(mines, safeBoardSize - 1))
        self.tiles = Array(repeating: 0, count: safeBoardSize)
        self.covers = Array(repeating: 1, count: safeBoardSize)
        self.cursorX = self.width / 2
        self.cursorY = self.height / 2
    }

    var boardSize: Int { width * height }

    var tilesLeft: Int { boardSize - mines - tilesCleared }

    var cursorIndex: Int { cursorY * width + cursorX }

    func reset() {
        tiles = Array(repeating: 0, count: boardSize)
        covers = Array(repeating: 1, count: boardSize)
        phase = .waiting
        timer = 0
        deathFrames = 0
        tilesCleared = 0
        cursorX = width / 2
        cursorY = height / 2
    }

    private func index(x: Int, y: Int) -> Int? {
        guard x >= 0, x < width, y >= 0, y < height else { return nil }
        return (y * width) + x
    }

    private func coordinates(of index: Int) -> (x: Int, y: Int) {
        (index % width, index / width)
    }

    private func neighborIndices(x: Int, y: Int) -> [Int] {
        var result: [Int] = []
        for dy in -1...1 {
            for dx in -1...1 {
                if dx == 0 && dy == 0 { continue }
                if let index = self.index(x: x + dx, y: y + dy) {
                    result.append(index)
                }
            }
        }
        return result
    }

    func tile(x: Int, y: Int) -> Int? {
        guard let index = index(x: x, y: y) else { return nil }
        return tiles[index]
    }

    func cover(x: Int, y: Int) -> Int? {
        guard let index = index(x: x, y: y) else { return nil }
        return covers[index]
    }

    /// Places mines after the first reveal, avoiding the 5x3 safe zone used by
    /// `initialize_board` in the reference GML.
    func initializeMines(nearX: Int, nearY: Int) {
        guard phase == .waiting else { return }

        func isSafe(_ index: Int) -> Bool {
            let point = coordinates(of: index)
            let dx = Double(point.x - nearX)
            let dy = Double(point.y - nearY)
            return sqrt((dx * dx) + (dy * dy)) >= 2
        }

        var placed = 0
        var attempts = 0
        let attemptLimit = boardSize * 24
        while placed < mines && attempts < attemptLimit {
            let target = Int.random(in: 0..<boardSize)
            if tiles[target] == 0 && isSafe(target) {
                tiles[target] = 9
                placed += 1
            }
            attempts += 1
        }

        // Extremely small boards can make the safe radius impossible; fill
        // remaining mines without the radius rather than looping forever.
        if placed < mines {
            for index in 0..<boardSize where placed < mines && tiles[index] == 0 {
                tiles[index] = 9
                placed += 1
            }
        }

        for index in 0..<boardSize where tiles[index] != 9 {
            let point = coordinates(of: index)
            tiles[index] = neighborIndices(x: point.x, y: point.y)
                .filter { tiles[$0] == 9 }
                .count
        }
    }

    @discardableResult
    func reveal(x: Int, y: Int) -> FredsweeperRevealResult {
        guard let index = index(x: x, y: y) else { return FredsweeperRevealResult() }

        if phase == .waiting {
            initializeMines(nearX: x, nearY: y)
            phase = .playing
        }
        guard phase == .playing else { return FredsweeperRevealResult() }

        let mineHit = revealIndex(index)
        recomputeTilesCleared()
        checkWin()
        return FredsweeperRevealResult(changed: true, mineHit: mineHit)
    }

    /// Internal reveal used by both direct clicks and chord expansion.
    /// Returns true when a mine was uncovered.
    @discardableResult
    private func revealIndex(_ start: Int) -> Bool {
        guard covers[start] == 1 else { return false }
        covers[start] = 0

        if tiles[start] == 9 {
            phase = .lost
            return true
        }

        if tiles[start] == 0 {
            var pending = [start]
            while let current = pending.popLast() {
                let point = coordinates(of: current)
                for neighbor in neighborIndices(x: point.x, y: point.y) {
                    guard covers[neighbor] == 1, tiles[neighbor] != 9 else { continue }
                    covers[neighbor] = 0
                    if tiles[neighbor] == 0 {
                        pending.append(neighbor)
                    }
                }
            }
        }

        return false
    }

    @discardableResult
    func toggleFlag(x: Int, y: Int) -> Bool {
        guard phase == .waiting || phase == .playing else { return false }
        guard let index = index(x: x, y: y) else { return false }

        if covers[index] == 1 {
            covers[index] = 2
            return true
        } else if covers[index] == 2 {
            covers[index] = 1
            return true
        }
        return false
    }

    /// Toggles the flag at the current cursor position. Used by the D-pad
    /// cursor scheme on Golden Fredsweeper.
    @discardableResult
    func toggleFlagAtCursor() -> Bool {
        toggleFlag(x: cursorX, y: cursorY)
    }

    @discardableResult
    func chord(x: Int, y: Int) -> FredsweeperChordResult {
        guard phase == .playing,
              let center = index(x: x, y: y),
              covers[center] == 0 else {
            return FredsweeperChordResult()
        }

        let number = tiles[center]
        guard (1...8).contains(number) else { return FredsweeperChordResult() }

        var adjacentFlags = 0
        var candidates: [Int] = []
        for neighbor in neighborIndices(x: x, y: y) {
            if covers[neighbor] == 2 {
                adjacentFlags += 1
            } else if covers[neighbor] == 1 {
                candidates.append(neighbor)
            }
        }

        guard adjacentFlags == number, !candidates.isEmpty else {
            return FredsweeperChordResult()
        }

        var result = FredsweeperChordResult(triggered: true, mineHit: false)
        for candidate in candidates where covers[candidate] == 1 {
            if revealIndex(candidate) {
                result.mineHit = true
            }
        }

        recomputeTilesCleared()
        if phase != .lost {
            checkWin()
        }
        return result
    }

    func advance(_ dt: TimeInterval) {
        if phase == .won || phase == .lost {
            deathFrames += dt
            if phase == .lost && deathFrames > 1 && tilesLeft > 0 {
                revealAllCovers()
            }
            if deathFrames > 3 {
                reset()
            }
            return
        }

        if phase == .playing {
            timer += dt
        }
    }

    func revealAllCovers() {
        covers = Array(repeating: 0, count: boardSize)
    }

    func moveCursor(dx: Int, dy: Int) {
        cursorX = min(max(cursorX + dx, 0), width - 1)
        cursorY = min(max(cursorY + dy, 0), height - 1)
    }

    private func recomputeTilesCleared() {
        guard !tiles.isEmpty else { return }
        tilesCleared = zip(covers, tiles).filter { cover, tile in
            cover == 0 && tile != 9
        }.count
    }

    private func checkWin() {
        guard phase == .playing, tilesLeft == 0 else { return }
        phase = .won
    }

    static func formatTimer(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total / 60) % 60
        let secs = total % 60
        let secondsText = String(format: "%02d", secs)

        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(secondsText)"
        }
        return "\(minutes):\(secondsText)"
    }
}
