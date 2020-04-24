//
//  GameStatus.swift
//  Reversi
//
//  Created by tasshy on 2020/04/24.
//  Copyright © 2020 Yuta Koshizawa. All rights reserved.
//

import Foundation
import UIKit

protocol GameStatusDelegate: AnyObject {
    var boardView: BoardView! { get }
    var playerControls: [UISegmentedControl]! { get }
}

final class GameStatus {
    private weak var delegate: GameStatusDelegate?
    
    /// どちらの色のプレイヤーのターンかを表します。ゲーム終了時は `nil` です。
    var turn: Disk? = .dark
    
    init(delegate: GameStatusDelegate) {
        self.delegate = delegate
    }
}

// MARK: - Reversi logics
extension GameStatus {
    /// `side` で指定された色のディスクが盤上に置かれている枚数を返します。
    /// - Parameter side: 数えるディスクの色です。
    /// - Returns: `side` で指定された色のディスクの、盤上の枚数です。
    func countDisks(of side: Disk) -> Int {
        guard let boardView = delegate?.boardView else {
            fatalError("delegate missing.")
        }

        var count = 0
        
        for y in boardView.yRange {
            for x in boardView.xRange {
                if boardView.diskAt(x: x, y: y) == side {
                    count +=  1
                }
            }
        }
        
        return count
    }
    
    /// 盤上に置かれたディスクの枚数が多い方の色を返します。
    /// 引き分けの場合は `nil` が返されます。
    /// - Returns: 盤上に置かれたディスクの枚数が多い方の色です。引き分けの場合は `nil` を返します。
    func sideWithMoreDisks() -> Disk? {
        let darkCount = countDisks(of: .dark)
        let lightCount = countDisks(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }
    
    func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        guard let boardView = delegate?.boardView else {
            fatalError("delegate missing.")
        }

        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]
        
        guard boardView.diskAt(x: x, y: y) == nil else {
            return []
        }
        
        var diskCoordinates: [(Int, Int)] = []
        
        for direction in directions {
            var x = x
            var y = y
            
            var diskCoordinatesInLine: [(Int, Int)] = []
            flipping: while true {
                x += direction.x
                y += direction.y
                
                switch (disk, boardView.diskAt(x: x, y: y)) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append((x, y))
                case (_, .none):
                    break flipping
                }
            }
        }
        
        return diskCoordinates
    }
    
    /// `x`, `y` で指定されたセルに、 `disk` が置けるかを調べます。
    /// ディスクを置くためには、少なくとも 1 枚のディスクをひっくり返せる必要があります。
    /// - Parameter x: セルの列です。
    /// - Parameter y: セルの行です。
    /// - Returns: 指定されたセルに `disk` を置ける場合は `true` を、置けない場合は `false` を返します。
    func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }
    
    /// `side` で指定された色のディスクを置ける盤上のセルの座標をすべて返します。
    /// - Returns: `side` で指定された色のディスクを置ける盤上のすべてのセルの座標の配列です。
    func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        guard let boardView = delegate?.boardView else {
            fatalError("delegate missing.")
        }

        var coordinates: [(Int, Int)] = []
        
        for y in boardView.yRange {
            for x in boardView.xRange {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append((x, y))
                }
            }
        }
        
        return coordinates
    }
}

// MARK: - Save and Load
extension GameStatus {
    /// ゲームの状態を初期化し、新しいゲームを開始します。
    func newGame(completion: (() -> Void)) {
        guard let delegate = delegate else {
            fatalError("delegate missing.")
        }

        delegate.boardView.reset()
        turn = .dark
        
        for playerControl in delegate.playerControls {
            playerControl.selectedSegmentIndex = ViewController.Player.manual.rawValue
        }

        completion()
        
        try? saveGame()
    }

    private var path: String {
        (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")
    }
    
    /// ゲームの状態をファイルに書き出し、保存します。
    func saveGame() throws {
        guard let delegate = delegate else {
            fatalError("delegate missing.")
        }
        
        var output: String = ""
        output += turn.symbol
        for side in Disk.sides {
            output += delegate.playerControls[side.index].selectedSegmentIndex.description
        }
        output += "\n"
        
        for y in delegate.boardView.yRange {
            for x in delegate.boardView.xRange {
                output += delegate.boardView.diskAt(x: x, y: y).symbol
            }
            output += "\n"
        }
        
        do {
            try output.write(toFile: path, atomically: true, encoding: .utf8)
        } catch let error {
            throw FileIOError.read(path: path, cause: error)
        }
    }
    
    /// ゲームの状態をファイルから読み込み、復元します。
    func loadGame(completion: (() -> Void)) throws {
        guard let delegate = delegate else {
            fatalError("delegate missing.")
        }

        let input = try String(contentsOfFile: path, encoding: .utf8)
        var lines: ArraySlice<Substring> = input.split(separator: "\n")[...]
        
        guard var line = lines.popFirst() else {
            throw FileIOError.read(path: path, cause: nil)
        }
        
        do { // turn
            guard
                let diskSymbol = line.popFirst(),
                let disk = Optional<Disk>(symbol: diskSymbol.description)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            turn = disk
        }

        // players
        for side in Disk.sides {
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = ViewController.Player(rawValue: playerNumber)
            else {
                throw FileIOError.read(path: path, cause: nil)
            }
            delegate.playerControls[side.index].selectedSegmentIndex = player.rawValue
        }

        do { // board
            guard lines.count == delegate.boardView.height else {
                throw FileIOError.read(path: path, cause: nil)
            }
            
            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Disk?(symbol: "\(character)").flatMap { $0 }
                    delegate.boardView.setDisk(disk, atX: x, y: y, animated: false)
                    x += 1
                }
                guard x == delegate.boardView.width else {
                    throw FileIOError.read(path: path, cause: nil)
                }
                y += 1
            }
            guard y == delegate.boardView.height else {
                throw FileIOError.read(path: path, cause: nil)
            }
        }

        completion()
    }
    
    enum FileIOError: Error {
        case write(path: String, cause: Error?)
        case read(path: String, cause: Error?)
    }
}

// MARK: -
extension Optional where Wrapped == Disk {
    fileprivate init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .some(.dark)
        case "o":
            self = .some(.light)
        case "-":
            self = .none
        default:
            return nil
        }
    }
    
    fileprivate var symbol: String {
        switch self {
        case .some(.dark):
            return "x"
        case .some(.light):
            return "o"
        case .none:
            return "-"
        }
    }
}
