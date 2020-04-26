import UIKit

class ViewController: UIViewController {
    @IBOutlet private(set) var boardView: BoardView!
    
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    /// Storyboard 上で設定されたサイズを保管します。
    /// 引き分けの際は `messageDiskView` の表示が必要ないため、
    /// `messageDiskSizeConstraint.constant` を `0` に設定します。
    /// その後、新しいゲームが開始されたときに `messageDiskSize` を
    /// 元のサイズで表示する必要があり、
    /// その際に `messageDiskSize` に保管された値を使います。
    private var messageDiskSize: CGFloat!
    
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!
    
    private lazy var gameStatus = GameStatus(delegate: self)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messageDiskSize = messageDiskSizeConstraint.constant
        
        do {
            try gameStatus.loadGame() {
                updateMessageViews()
                updateCountLabels()
            }
        } catch _ {
            gameStatus.newGame() {
                updateMessageViews()
                updateCountLabels()
            }
        }
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if viewHasAppeared { return }
        viewHasAppeared = true
        gameStatus.waitForPlayer()
    }
}

// MARK: - GameStatusDelegate
extension ViewController: GameStatusDelegate {
    /// 指定された色の SegmentControl から、手動かコンピューターかを取得する
    func player(for side: Disk) -> GameStatus.Player {
        GameStatus.Player(rawValue: playerControls[side.index].selectedSegmentIndex)!
    }
    
    /// 指定された色のプレイヤーが手動かコンピューターかを設定する
    func set(player: GameStatus.Player, for side: Disk) {
        playerControls[side.index].selectedSegmentIndex = player.rawValue
    }
    
    func startPlayerActivityIndicator(for index: Int) {
        playerActivityIndicators[index].startAnimating()
    }
    
    func stopPlayerActivityIndicator(for index: Int) {
        playerActivityIndicators[index].stopAnimating()
    }
    
    /// 各プレイヤーの獲得したディスクの枚数を表示します。
    func updateCountLabels() {
        for side in Disk.sides {
            countLabels[side.index].text = "\(gameStatus.countDisks(of: side))"
        }
    }
    
    /// 現在の状況に応じてメッセージを表示します。
    func updateMessageViews() {
        switch gameStatus.turn {
        case .some(let side):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side
            messageLabel.text = "'s turn"
        case .none:
            if let winner = gameStatus.sideWithMoreDisks() {
                messageDiskSizeConstraint.constant = messageDiskSize
                messageDiskView.disk = winner
                messageLabel.text = " won"
            } else {
                messageDiskSizeConstraint.constant = 0
                messageLabel.text = "Tied"
            }
        }
    }
    
    // 駒を置けない場合に表示するAlert
    func showNoPlaceAlert(completion: @escaping(() -> Void)) {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in
            completion()
        })
        present(alertController, animated: true)
    }
}

// MARK: - UI Inputs
extension ViewController {
    /// リセットボタンが押された場合に呼ばれるハンドラーです。
    /// アラートを表示して、ゲームを初期化して良いか確認し、
    /// "OK" が選択された場合ゲームを初期化します。
    @IBAction func pressResetButton(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.gameStatus.resetGame()
        })
        present(alertController, animated: true)
    }
    
    /// プレイヤーのモードが変更された場合に呼ばれるハンドラーです。
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        let side: Disk = Disk(index: playerControls.firstIndex(of: sender)!)
        
        gameStatus.changePlayer(for: side)
    }
}
