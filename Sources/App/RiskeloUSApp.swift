//
//  RiskeloUSApp.swift
//  Riskelo US
//
//  A game of Risk where the die is replaced by a trivia question.
//
//  A single target for iPhone, iPad and Mac: nothing in the game depends on
//  one screen. The board is described in relative units, the panels are
//  bounded in width, and everything that can be touched can be clicked.
//

import SwiftUI

@main
struct RiskeloUSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var root = RootModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: root)
        }
        .onChange(of: scenePhase) { _, phase in
            // The app can be stopped with no more notice than this.
            if phase != .active { root.session?.saveNow() }
        }
        #if os(macOS)
        .defaultSize(width: 980, height: 760)
        #endif
    }
}

/// What outlives a view: the game in progress, and that alone.
@Observable
@MainActor
final class RootModel {
    var session: GameSession?
    /// The setup of a two-device game, when it is open.
    var lobby: (rules: Rules, board: Boards)?
    /// The table's settings, opened from the lobby. They live here and not in
    /// the lobby: the lobby is rebuilt with the settings just chosen, and a
    /// screen that is rebuilt loses what it was keeping.
    var lobbySettings = false
    var library = false
    /// The manual, opened from the home screen.
    var manual = false
    /// The settings, opened from the home screen. They used to be the home
    /// screen; they are now only a door off it.
    var settings = false
    /// The packs, opened from the home screen. They are not under the
    /// settings: a pack is owned, it is not set.
    var packs = false
    /// The opening — the two sides coming together — plays once per launch.
    var openingPlayed = false
}

struct RootView: View {
    @Bindable var model: RootModel

    var body: some View {
        ZStack {
            // The ground is laid down right away: without it, the home screen
            // would appear for one frame before the resumed game replaced it.
            Palette.sea.ignoresSafeArea()
            if let session = model.session {
                GameScreen(session: session) {
                    session.saveNow()
                    withAnimation { model.session = nil }
                }
            } else if model.library {
                ArchivesView(onOpen: { state in
                    withAnimation {
                        model.library = false
                        model.settings = false
                        // A fresh branch: going back to a game must not erase
                        // the game you are going back to.
                        model.session = GameSession(resuming: state, branch: UUID())
                    }
                }, onClose: { withAnimation { model.library = false } })
            } else if model.manual {
                ManualView(onClose: { withAnimation { model.manual = false } })
            } else if model.packs {
                PacksView(onClose: { withAnimation { model.packs = false } })
            } else if model.lobbySettings, let lobby = model.lobby {
                // The same settings, full screen like the rest of the app —
                // and cut down to what a multi-device table can decide.
                // Confirming comes back to the lobby with them.
                SetupView(forNetwork: true,
                          from: (lobby.rules, lobby.board),
                          onStart: { _, _, _ in },
                          onNetwork: { rules, board in
                              withAnimation {
                                  model.lobby = (rules, board)
                                  model.lobbySettings = false
                              }
                          },
                          // The manual lays itself over without undoing
                          // anything: the lobby and its settings stay open
                          // behind, and you land back on them when you close
                          // it.
                          onManual: { withAnimation { model.manual = true } },
                          onBack: { withAnimation { model.lobbySettings = false } })
                    .transition(.opacity)
            } else if let lobby = model.lobby {
                LobbyView(board: lobby.board, rules: lobby.rules,
                          onReady: { session in
                              withAnimation {
                                  model.lobby = nil
                                  model.settings = false
                                  model.session = session
                              }
                          },
                          // Giving up on the table hands back the settings as
                          // they were left, and not the home screen: you had
                          // just chosen a board and a mode there.
                          onCancel: { withAnimation { model.lobby = nil; model.lobbySettings = false } },
                          onSettings: { withAnimation { model.lobbySettings = true } })
            } else if model.settings {
                SetupView(onStart: { players, rules, board in
                    withAnimation {
                        model.settings = false
                        model.session = GameSession(players: players, rules: rules, board: board)
                    }
                }, onNetwork: { rules, board in
                    withAnimation { model.lobby = (rules, board) }
                },
                onManual: { withAnimation { model.manual = true } },
                onArchives: Archives.shared.list().isEmpty ? nil : {
                    withAnimation { model.library = true }
                },
                onBack: { withAnimation { model.settings = false } })
            } else {
                HomeView(
                    onQuickGame: {
                        fromHome {
                            model.session = GameSession(players: QuickGame.players(),
                                                        rules: QuickGame.rules(),
                                                        board: QuickGame.board)
                        }
                    },
                    // The table opens on the quick game's settings. Anyone
                    // wanting another board or another mode goes through
                    // "Settings", where the same button is waiting: this is
                    // not two paths, it is the same one in two places.
                    onNetwork: {
                        fromHome {
                            model.lobby = (QuickGame.rules(), QuickGame.board)
                        }
                    },
                    onSettings: { fromHome { model.settings = true } },
                    onPacks: { fromHome { model.packs = true } },
                    // The app used to resume the saved game by itself at
                    // launch. It no longer does: a home screen you never see
                    // is not a home screen. Resuming comes right after the
                    // table, and stays the only green button.
                    onResume: GameStore.shared.hasSavedGame ? {
                        if let saved = GameStore.shared.load() {
                            fromHome { model.session = GameSession(resuming: saved) }
                        }
                    } : nil,
                    onManual: { fromHome { model.manual = true } },
                    onArchives: Archives.shared.list().isEmpty ? nil : {
                        fromHome { model.library = true }
                    },
                    animated: !model.openingPlayed)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Leaving the home screen. We note in passing that the opening has been
    /// seen: without that, the two sides would come together again on every
    /// return from a game, and what charms at launch becomes a toll.
    private func fromHome(_ move: () -> Void) {
        model.openingPlayed = true
        withAnimation { move() }
    }
}

#Preview("Board") {
    GameScreen(session: GameSession(players: [
        Player(id: 0, name: "Blue"),
        Player(id: 1, name: "Red", kind: .machine(level: 0.65, style: .strong)),
    ], seed: 7), onQuit: {})
}
