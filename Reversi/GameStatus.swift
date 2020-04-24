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

// MARK: Save and Load
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
