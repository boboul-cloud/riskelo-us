//
//  DuelOverlay.swift
//  Riskelo US
//
//  The duel, full screen.
//
//  It takes the whole screen because it replaces the roll of the dice: this
//  is the moment the game is decided, and nothing else should be readable at
//  that instant. The board reappears once the question is settled.
//

import SwiftUI

struct DuelOverlay: View {

    let session: GameSession

    var body: some View {
        if let stage = session.stage, stage != .announcing {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content(stage)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: 620)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                            .fill(Palette.panel)
                            .shadow(color: .black.opacity(0.5), radius: 14, y: -4)
                    )
                    .overlay(alignment: .top) {
                        // The grab handle: it says this is a sheet laid over
                        // the board, and not a screen that replaced it.
                        Capsule().fill(Palette.dim.opacity(0.5))
                            .frame(width: 34, height: 4).padding(.top, 7)
                    }
                    .frame(maxWidth: .infinity)
                    .coversBottom()
            }
            // No veil over the board: that is the whole point of the sheet.
            // You have to see the troops fall while you answer.
            .contentShape(Rectangle())
            .onTapGesture { if session.canSkip { session.skipAhead() } }
            .transition(.move(edge: .bottom))
        }
    }

    @ViewBuilder
    private func content(_ stage: GameSession.Stage) -> some View {
        switch stage {
        case .announcing: EmptyView()
        case .handover: handover
        case .opponentAnswering: opponentAnswering
        case .asking, .revealed: question
        case .summary: summary
        }
    }

    // MARK: - "Ready?"

    @ViewBuilder private var handover: some View {
        if let a = session.assault, let duel = session.duel,
           let attacker = session.player(a.attacker), let defender = session.player(a.defender),
           let who = session.responder, let responder = session.player(who) {
            // In a showdown, whoever has to answer is no longer necessarily
            // the defender: they are the one to name, and the one whose color
            // is taken, or you hand the device to the wrong player.
            let showdown = session.game.rules.mode == .showdown
            VStack(spacing: 26) {
                Image(systemName: who == a.defender ? "shield.lefthalf.filled" : "flag.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Palette.side(responder.id))
                VStack(spacing: 8) {
                    Text("\(attacker.name) attacks \(session.game.name(a.to))")
                        .font(.title3.weight(.semibold))
                    Text("\(duel.question.category.asQuestion)"
                         + " — \(duel.question.difficulty.label.lowercased())")
                        .foregroundStyle(Palette.dim)
                    if showdown, a.defenderAnswer != nil {
                        // We say they have answered, never what they answered.
                        Text("\(defender.name) has answered. The same question is yours.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    } else if showdown {
                        Text("You both answer the same question.")
                            .font(.footnote)
                            .foregroundStyle(Palette.dim)
                    }
                    if a.stake > 1 {
                        Label("Stake doubled: two troops", systemImage: "arrow.up.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.lostBright)
                    }
                }
                .multilineTextAlignment(.center)

                hourglass(duel.allowance, siege: duel.siege)

                Text("\(responder.name) to answer.")
                    .font(.headline)
                Button {
                    withAnimation { session.beginAnswering() }
                } label: {
                    Text("I'm ready")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.side(responder.id))
            }
            .foregroundStyle(Palette.ink)
        }
    }

    /// While the other player answers. We give their name, the theme, and
    /// what is coming — never the prompt, which would arrive twice.
    @ViewBuilder private var opponentAnswering: some View {
        if let duel = session.duel, let who = session.responder,
           let responder = session.player(who) {
            VStack(spacing: 14) {
                Image(systemName: "ellipsis.bubble")
                    .font(.system(size: 38))
                    .foregroundStyle(Palette.side(responder.id))
                Text(session.assault?.defenderAnswer != nil
                     ? "Answer taken. \(responder.name) is answering…"
                     : "\(responder.name) is answering…")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Label(duel.question.category.label, systemImage: duel.question.category.symbol)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Palette.category(duel.question.category).opacity(0.25),
                                in: Capsule())
                    .foregroundStyle(Palette.category(duel.question.category))
                Text(session.assault?.defenderAnswer != nil
                     ? "Your answer is taken. \(responder.name) is now answering "
                       + "the same question: the surer wins, and if you both know, "
                       + "the faster."
                     : "You will get the same question right after: in a showdown "
                       + "the attacker answers too. The surer wins, and if you both "
                       + "know, the faster.")
                    .font(.footnote).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func hourglass(_ allowance: TimeInterval, siege: Int) -> some View {
        VStack(spacing: 4) {
            Label("\(Int(allowance.rounded())) seconds", systemImage: "hourglass")
                .font(.subheadline.weight(.medium))
            if siege > 0 {
                Text("Question \(siege + 1) on this place this turn — the clock tightens")
                    .font(.caption)
                    .foregroundStyle(Palette.lostBright.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - The question

    /// The question the screen has to show.
    ///
    /// It is not always the one the engine is holding ready. As soon as an
    /// answer reaches it, it carries on: it counts the loss and immediately
    /// draws the next question of the volley. The screen is still revealing
    /// the previous one — and so it was showing the next, its correct answer
    /// already marked in green, before anyone had answered it.
    ///
    /// While a report is there, its question reigns. The engine will wait.
    private var shownDuel: Duel? {
        if let r = session.report {
            return Duel(question: r.question, allowance: r.allowance, siege: 0)
        }
        return session.duel
    }

    @ViewBuilder private var question: some View {
        if let duel = shownDuel {
            VStack(spacing: 18) {
                header(duel)
                countdown(duel.allowance)

                Text(duel.question.prompt)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)

                VStack(spacing: 8) {
                    ForEach(Array(duel.question.choices.enumerated()), id: \.offset) { i, choice in
                        choiceRow(i, choice, duel: duel)
                    }
                }

                if session.canIRaise {
                    Button { withAnimation { session.raise() } } label: {
                        Label("Double the stake", systemImage: "arrow.up.circle")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.lostBright)
                    .transition(.opacity)
                } else if let a = session.assault, a.stake > 1, session.report == nil {
                    Label("Stake doubled: two troops", systemImage: "arrow.up.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.lostBright)
                }

                if session.thinking {
                    Label(session.networked ? "Your opponent is answering…"
                                            : "Your opponent is thinking…",
                          systemImage: "ellipsis.bubble")
                        .font(.subheadline)
                        .foregroundStyle(Palette.dim)
                } else if let r = session.report {
                    verdict(r)
                }

                // The prompt only appears once the first instant has passed:
                // shown right away, it would push you to cut short what you
                // have only just opened.
                if session.canSkip, session.waitPart < 0.8 {
                    Text("Tap to continue")
                        .font(.caption2)
                        .foregroundStyle(Palette.dim.opacity(0.8))
                        .transition(.opacity)
                }
            }
        }
    }

    private func header(_ duel: Duel) -> some View {
        HStack {
            Label(duel.question.category.label, systemImage: duel.question.category.symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Palette.category(duel.question.category).opacity(0.25), in: Capsule())
                .foregroundStyle(Palette.category(duel.question.category))
            Spacer()
            if let a = session.assault {
                Text("\(session.game.name(a.from)) → \(session.game.name(a.to))")
                    .font(.caption)
                    .foregroundStyle(Palette.dim)
                // Once the answer is given, the engine has already counted
                // the question: the counter showed "2/1". It is the one just
                // settled that has to be shown, not the next.
                Text("· \(min(max(session.report == nil ? a.asked + 1 : a.asked, 1), a.volley))/\(a.volley)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.dim)
            }
        }
    }

    /// The top bar says two different things depending on who is answering,
    /// and they have to be told apart: the defender's hourglass, which
    /// decides the outcome, is in color; the reading time, which decides
    /// nothing, stays grey.
    ///
    /// In both cases it descends only once per question. When a human has
    /// answered, it freezes where it was — the time they had left is
    /// information, not a countdown to replay.
    private func countdown(_ allowance: TimeInterval) -> some View {
        let live = session.myTurnToAnswer
        let part = live
            ? max(0, min(1, session.remaining / max(allowance, 0.001)))
            : session.waitPart
        let tint: Color = live
            ? (part > 0.5 ? Palette.held : (part > 0.25 ? Color.orange : Palette.lost))
            : Palette.dim.opacity(0.45)
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.panel)
                Capsule().fill(tint).frame(width: g.size.width * part)
            }
        }
        .frame(height: 7)
        .animation(.linear(duration: 0.1), value: part)
    }

    private func choiceRow(_ index: Int, _ text: String, duel: Duel) -> some View {
        let r = session.report
        let picked: Int? = { if case let .chosen(i, _) = myAnswer { return i } else { return nil } }()
        let isRight = index == duel.question.answer
        let background: Color = {
            guard r != nil else { return Palette.panel }
            if isRight { return Palette.held.opacity(0.85) }
            if index == picked { return Palette.lost.opacity(0.8) }
            return Palette.panel
        }()
        return Button {
            session.answer(index)
        } label: {
            HStack {
                Text(text)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                Spacer()
                if r != nil, isRight { Image(systemName: "checkmark") }
                if r != nil, index == picked, !isRight { Image(systemName: "xmark") }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        // Not answering is not the same as being washed out. A "disabled"
        // button loses its contrast, and the attacker — who does not answer —
        // could no longer read the choices. Yet reading them and answering in
        // their head is their whole game during that duel.
        .allowsHitTesting(session.stage == .asking && session.report == nil
                          && !session.thinking && session.myTurnToAnswer)
        .animation(.easeOut(duration: 0.2), value: session.report)
    }

    /// Green or red according to what happens **to you**, and not according
    /// to the side that holds. "Khanate holds" showed in green while the
    /// sentence cost you a troop: the color said the opposite of the text,
    /// and it is the color you read first. With two humans on one device
    /// there is no "you": the sentence then stays white.
    private func verdictColor(_ r: DuelReport) -> Color {
        guard let a = session.assault else { return Palette.ink }
        let iAmAttacker: Bool
        if session.networked {
            iAmAttacker = a.attacker == session.mySeat
        } else {
            let attackerIsHuman = !(session.player(a.attacker)?.isBot ?? true)
            let defenderIsHuman = !(session.player(a.defender)?.isBot ?? true)
            guard attackerIsHuman != defenderIsHuman else { return Palette.ink }
            iAmAttacker = attackerIsHuman
        }
        let iWin = iAmAttacker
            ? r.outcome == .attackerBreaks
            : r.outcome == .defenderHolds
        return iWin ? Palette.held : Palette.lostBright
    }

    /// What the answer was worth, said in Risk's terms.
    private func verdict(_ r: DuelReport) -> some View {
        VStack(spacing: 10) {
            if r.verdict == .answered {
                HStack(spacing: 14) {
                    die(r.dice.attacker, label: "assault")
                    Image(systemName: r.outcome == .defenderHolds ? "lessthan" : "greaterthan")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Palette.dim)
                    die(r.dice.defender, label: "defense")
                }
            } else {
                showdownRows(r)
            }
            Text(verdictText(r))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                // Without this the sentence gets truncated onto one line: the
                // text is the only thing on screen with no imposed width, and
                // SwiftUI clips it rather than wrapping it.
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(verdictColor(r))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    /// Who answered, and what it costs.
    ///
    /// The sentence did not say who it was talking about. When you are the
    /// one attacking, it is your opponent who answers: reading "correct
    /// answer" and then losing a troop is taken for a bug in the app. Naming
    /// whoever answers removes all doubt, and the place named says where the
    /// troop falls.
    private func verdictText(_ r: DuelReport) -> String {
        let defName = session.assault.flatMap { session.player($0.defender)?.name } ?? "The defender"
        let attName = session.assault.flatMap { session.player($0.attacker)?.name } ?? "The attacker"
        let place = session.assault.map { session.game.name($0.to) } ?? "The place"
        let cost = r.stake > 1 ? "two troops" : "a troop"

        switch r.verdict {
        case .answered:
            let mine = session.myTurnToAnswer
            if r.correct {
                return (mine ? "You answered correctly" : "\(defName) answered correctly")
                    + ": \(place) holds, the attacker leaves \(cost)."
            }
            let fault = r.answer == .timeout
                ? (mine ? "You did not answer in time" : "\(defName) did not answer in time")
                : (mine ? "You got it wrong" : "\(defName) got it wrong")
            return fault + ": \(place) loses \(cost)."

        case .onlyOne:
            return r.correct
                ? "\(defName) knew, \(attName) did not: \(place) holds, the attacker leaves \(cost)."
                : "\(attName) knew, \(defName) did not: \(place) loses \(cost)."

        case .speed:
            return r.outcome == .defenderHolds
                ? "Both knew. \(defName) was quicker: \(place) holds, "
                    + "the attacker leaves \(cost)."
                : "Both knew. \(attName) was quicker: \(place) loses \(cost)."

        case .tie:
            return "Nobody knew. As on a tie of dice, \(place) holds "
                + "and the attacker leaves \(cost)."
        }
    }

    /// My own answer, so we know where to put the cross. In a showdown both
    /// players have ticked a box: showing the defender's to the attacker
    /// would make them think they had got it wrong.
    private var myAnswer: Answer? {
        guard let r = session.report else { return nil }
        guard r.verdict != .answered, let a = session.assault else { return r.answer }
        let iDefend = session.networked
            ? a.defender == session.mySeat
            : !(session.player(a.defender)?.isBot ?? true)
        return iDefend ? r.answer : r.attackerAnswer
    }

    /// The two answers side by side, with each one's time.
    ///
    /// This is the piece the showdown was missing. Four exchanges out of ten
    /// are decided on the clock: without seeing the two times, you lose a
    /// place having answered correctly, and can only believe the game got it
    /// wrong.
    @ViewBuilder private func showdownRows(_ r: DuelReport) -> some View {
        if let a = session.assault {
            VStack(spacing: 4) {
                sideRow(a.attacker, r.attackerAnswer, correct: r.attackerCorrect, of: r,
                        wins: r.outcome == .attackerBreaks)
                sideRow(a.defender, r.answer, correct: r.correct, of: r,
                        wins: r.outcome == .defenderHolds)
            }
        }
    }

    private func sideRow(_ player: PlayerID, _ answer: Answer?, correct: Bool,
                         of r: DuelReport, wins: Bool) -> some View {
        let name = session.player(player)?.name ?? "?"
        var text = "no answer"
        var time: String?
        if case let .chosen(i, e)? = answer {
            if r.question.choices.indices.contains(i) { text = r.question.choices[i] }
            time = String(format: "%.1fs", min(e, r.allowance))
        }
        return HStack(spacing: 7) {
            Circle().fill(Palette.side(player)).frame(width: 7, height: 7)
            Text(name).font(.caption.weight(.semibold))
                .foregroundStyle(Palette.side(player))
            Image(systemName: correct ? "checkmark" : "xmark")
                .font(.caption2.weight(.bold))
                .foregroundStyle(correct ? Palette.held : Palette.lostBright)
            Text(text).font(.caption).foregroundStyle(Palette.ink)
                .lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 4)
            if let time {
                Text(time).font(.caption2.monospacedDigit()).foregroundStyle(Palette.dim)
            }
            Image(systemName: "crown.fill")
                .font(.caption2)
                .foregroundStyle(wins ? Palette.held : .clear)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(wins ? Palette.held.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8))
    }

    private func die(_ face: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: "die.face.\(min(6, max(1, face)))")
                .font(.system(size: 34))
                .foregroundStyle(Palette.ink)
            Text(label).font(.caption2).foregroundStyle(Palette.dim)
        }
    }

    // MARK: - The assault summary

    @ViewBuilder private var summary: some View {
        if let a = session.assault {
            VStack(spacing: 22) {
                Image(systemName: a.conquered ? "flag.fill" : "shield.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(a.conquered ? Palette.side(a.attacker) : Palette.dim)
                Text(a.conquered
                     ? "\(session.game.name(a.to)) is taken."
                     : "\(session.game.name(a.to)) holds.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 28) {
                    tally("Attacker", a.attackerLosses, a.attacker)
                    tally("Defender", a.defenderLosses, a.defender)
                }

                // The summary of an assault you are on the receiving end of
                // is read-only. Without this condition, a place taken by the
                // machine handed you **its** occupation panel: you would have
                // chosen how many of its troops advance into your land.
                if !session.myTurnToPlay {
                    Text("Tap to continue")
                        .font(.caption2)
                        .foregroundStyle(Palette.dim.opacity(0.8))
                } else if case let .occupation(from, to, minimum, maximum) = session.game.phase {
                    OccupationPanel(session: session, from: from, to: to,
                                    minimum: minimum, maximum: maximum)
                } else {
                    Button { withAnimation { session.closeAssault() } } label: {
                        Text("Continue").font(.headline)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.side(a.attacker))
                }
            }
        }
    }

    private func tally(_ title: String, _ losses: Int, _ side: PlayerID) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.caption).foregroundStyle(Palette.dim)
            Text("−\(losses)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(losses > 0 ? Palette.lostBright : Palette.dim)
            Circle().fill(Palette.side(side)).frame(width: 10, height: 10)
        }
    }
}

/// How many troops advance into the conquered place.
///
/// The number comes before the button, and not the other way round. The
/// choice used to sit in a `Stepper` — two grey arrows the size of a
/// fingernail — laid above a full-width button, full of the side's color: you
/// saw the button, you touched it, and a single troop advanced onto the place
/// you had just taken. The player only noticed the following turn, finding
/// their garrison left behind, and thought the app had decided for them.
///
/// Hence three changes that all pull the same way. The number is large and is
/// set by two round forty-four-point buttons — the floor for what can be
/// touched without missing, and here they are touched several times running.
/// Three shortcuts take the common cases, because nobody taps "plus" eleven
/// times. And the button **carries the chosen number**: the pressing finger
/// can still read what it is confirming.
struct OccupationPanel: View {
    let session: GameSession
    let from: TerritoryID
    let to: TerritoryID
    let minimum: Int
    let maximum: Int
    @State private var count = 1

    /// The top of the range. The engine always gives a maximum at least equal
    /// to the minimum, but a range that inverts brings the screen down: we do
    /// not rely on it.
    private var top: Int { max(minimum, maximum) }
    private var side: PlayerID { session.game.currentPlayer.id }
    /// What is left at the starting place. The troops have not moved yet —
    /// the engine only moves them on confirmation.
    private var left: Int { max(1, session.game.armies(from) - count) }

    var body: some View {
        VStack(spacing: 12) {
            if top > minimum {
                picker
            } else {
                // Nothing to choose: say so, rather than hand over a setting
                // that does not move.
                Text(minimum > 1
                     ? "\(minimum) troops advance — that is all the starting place can spare."
                     : "One troop advances — that is all the starting place can spare.")
                    .font(.footnote).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }

            Button { withAnimation { session.occupy(count) } } label: {
                Text(count > 1 ? "Advance \(count) troops" : "Advance 1 troop")
                    .font(.headline)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.side(side))
        }
        .onAppear { count = minimum }
    }

    /// The choice, in its frame. The frame is not an ornament: it gives the
    /// setting the weight the button was taking from it, and the side's color
    /// as an outline says this is still your move — the ground itself stays
    /// matte.
    private var picker: some View {
        VStack(spacing: 10) {
            Text("How many troops advance?")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)

            HStack(spacing: 16) {
                step(-1, "minus")
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.brightSide(side))
                        .contentTransition(.numericText())
                    Text("of \(top)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.dim)
                }
                .frame(minWidth: 84)
                step(+1, "plus")
            }

            HStack(spacing: 8) {
                shortcut("Minimum", minimum)
                if let half { shortcut("Half", half) }
                shortcut("All", top)
            }

            moveSummary
            if minimum > 1 {
                Text("At least \(minimum): as many as there were questions.")
                    .font(.caption).foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(Palette.brightSide(side).opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Palette.brightSide(side).opacity(0.65), lineWidth: 1.5))
    }

    /// What the move leaves on each side, kept up to date with the chosen
    /// number.
    ///
    /// The sheet covers the bottom of the map at the very moment you decide,
    /// so you could no longer see **where** the troops advance — nor what
    /// would be left behind. Both places are named here, with the garrison
    /// each will have once the move is made: that is what you are deciding
    /// about, and it does not depend on any reframing.
    private var moveSummary: some View {
        HStack(spacing: 12) {
            place(session.game.name(from), left, tint: Palette.ink.opacity(0.85))
            Image(systemName: "arrow.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.dim)
            place(session.game.name(to), count, tint: Palette.brightSide(side))
        }
    }

    private func place(_ name: String, _ troops: Int, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.caption2).foregroundStyle(Palette.dim)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text("\(troops)")
                .font(.headline.monospacedDigit()).foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: 120)
    }

    /// One notch up or down. The button dims when it is at the end of the
    /// range instead of disappearing: the pair stays symmetrical, and the
    /// finger does not go looking for where the "minus" went.
    private func step(_ delta: Int, _ icon: String) -> some View {
        let wanted = min(max(count + delta, minimum), top)
        let dead = wanted == count
        return Button {
            withAnimation(.snappy(duration: 0.12)) { count = wanted }
        } label: {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(dead ? 0.03 : 0.08)))
                .overlay(Circle().strokeBorder(dead ? Palette.dim.opacity(0.3)
                                                    : Palette.brightSide(side).opacity(0.8),
                                               lineWidth: 1.5))
                .foregroundStyle(dead ? Palette.dim.opacity(0.45) : Palette.brightSide(side))
        }
        .buttonStyle(.plain)
        .disabled(dead)
    }

    /// The common cases, in one tap.
    private func shortcut(_ title: String, _ value: Int) -> some View {
        let chosen = count == value
        return Button {
            withAnimation(.snappy(duration: 0.12)) { count = value }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold)).lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(chosen ? Palette.brightSide(side).opacity(0.28)
                                                  : Color.white.opacity(0.06)))
                .overlay(Capsule().strokeBorder(chosen ? Palette.brightSide(side)
                                                       : Palette.dim.opacity(0.45),
                                                lineWidth: 1))
                .foregroundStyle(chosen ? Palette.ink : Palette.dim)
        }
        .buttonStyle(.plain)
    }

    /// Half, and only when it says something other than the two ends.
    private var half: Int? {
        let m = min(top, max(minimum, (top + 1) / 2))
        return m > minimum && m < top ? m : nil
    }
}
