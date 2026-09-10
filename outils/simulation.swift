//
//  simulation.swift
//  Riskelo US — tool, outside the app
//
//  A thousand games in a second, machine against machine.
//
//  Not one setting in this game was chosen by eye: the clock, the victory
//  gap, the turn-order compensation, the opponent's boldness all come out of
//  this test bench. It is here so it can be done again — change one lever in
//  Rules.swift and know in ten seconds what it costs.
//
//  This file is not part of the target: the engine being pure Swift, it
//  compiles on its own.
//
//      swiftc -O -parse-as-library -o /tmp/sim \
//          Sources/Engine/*.swift outils/simulation.swift && /tmp/sim
//

import Foundation

func runGame(seed: UInt64, levels: [Double], rules: Rules, board: Boards = .ring,
             maxTurns: Int = 400, styles: [Bot.Style] = [])
-> (winner: Int?, turns: Int, duels: Int) {
    let players = levels.enumerated().map { i, n in
        Player(id: i, name: "P\(i)",
               kind: .machine(level: n,
                              style: i < styles.count ? styles[i] : .strong))
    }
    var g = GameState.start(board: board, players: players, rules: rules, seed: seed)
    var duels = 0, safety = 0
    while !g.isOver && g.turn <= maxTurns && safety < 500_000 {
        safety += 1
        let step = BotRunner.step(&g)
        if case .answered = step { duels += 1 }
        // A turn that stops moving gets settled: the machine has finished
        // playing.
        if step == .idle, g.phase == .fortify { g.endTurn() }
    }
    if case let .finished(w) = g.phase { return (w, g.turn, duels) }
    return (nil, g.turn, duels)
}

@discardableResult
func campaign(_ title: String, levels: [Double], n: Int, rules: Rules = Rules(),
              board: Boards = .ring, styles: [Bot.Style] = []) -> [Int] {
    var wins = [Int: Int](), unfinished = 0, totalTurns = 0, totalDuels = 0
    for i in 0 ..< n {
        let r = runGame(seed: UInt64(i &* 2_654_435_761 &+ 12_345), levels: levels,
                        rules: rules, board: board, styles: styles)
        if let w = r.winner { wins[w, default: 0] += 1 } else { unfinished += 1 }
        totalTurns += r.turns
        totalDuels += r.duels
    }
    let shares = levels.indices.map {
        "P\($0) \(Int(100.0 * Double(wins[$0] ?? 0) / Double(n)))%"
    }
    print("\(title.padding(toLength: 26, withPad: " ", startingAt: 0)) \(shares.joined(separator: " | "))"
          + "   unfinished \(unfinished)   turns ~\(totalTurns / n)   questions ~\(totalDuels / n)")
    return levels.indices.map { wins[$0] ?? 0 }
}

@main
struct Simulation {
    static func main() {
        // MARK: - The board and the bank

        let board = TestBoard.board
        print("BOARD — \(board.map.order.count) territories, "
              + "\(board.map.continentsInOrder.count) continents, "
              + "in one piece: \(board.map.isConnected)")
        for c in board.map.continentsInOrder {
            let doors = Set(c.territories.filter { id in
                board.map.neighbors(of: id).contains { board.map[$0]?.continent != c.id }
            })
            print("   \(c.name) — \(c.territories.count) territories, bonus \(c.bonus), \(doors.count) doors")
        }
        print("BANK — \(QuestionBank().count) questions: "
              + Themes.all.map { "\($0.label.prefix(4)) \(QuestionBank().count(in: $0))" }
                .joined(separator: ", "))

        // MARK: - The duel

        print("\nCLOCK —", (0..<6).map { String(format: "%.1f s", Rules().answerTime(siege: $0)) }
            .joined(separator: " → "))
        print("THE DEFENDER HOLDS (knowledge 0.70) —",
              (0..<6).map { s -> String in
                  let t = Rules().answerTime(siege: s)
                  let p = Difficulty.allCases.map {
                      Bot.probability(level: 0.70, difficulty: $0, allowance: t, rules: Rules())
                  }
                  return String(format: "%.0f%%", 100 * (0.4 * p[0] + 0.4 * p[1] + 0.2 * p[2]))
              }.joined(separator: " → "))

        for n in 2...5 {
            print("   \(n) players: start \(board.map.order.count / n) territories, "
                  + "victory at \(Rules().dominationThreshold(territories: board.map.order.count, playerCount: n)), "
                  + "compensation +\(Rules().compensation(playerCount: n)) per seat")
        }

        // MARK: - The strategist against the greedy machine

        print("\n=== THE STRATEGIST AGAINST THE GREEDY MACHINE, AT EQUAL KNOWLEDGE ===")
        print("   (P0 = strategist, P1 = greedy — then the reverse, to remove the seat advantage)")
        for kind in Boards.allCases {
            var r = Rules()
            for (name, styles) in [("strategist first", [Bot.Style.strong, .easy]),
                                   ("greedy first", [Bot.Style.easy, .strong])] {
                campaign("\(kind.label) — \(name)", levels: [0.70, 0.70], n: 400,
                         rules: r, board: kind, styles: styles)
            }
            r.territoryCards = true
            campaign("\(kind.label) — with cards", levels: [0.70, 0.70], n: 300,
                     rules: r, board: kind, styles: [.strong, .easy])
        }

        print("\n=== AND THE STRATEGIST AGAINST ITSELF (the balance has to hold) ===")
        campaign("2 p. equal knowledge", levels: [0.70, 0.70], n: 500)
        campaign("2 p. 0.75 / 0.70", levels: [0.75, 0.70], n: 500)
        campaign("3 p. equal knowledge", levels: [0.70, 0.70, 0.70], n: 300)
        campaign("4 p. equal knowledge", levels: [0.70, 0.70, 0.70, 0.70], n: 250)
    }
}
