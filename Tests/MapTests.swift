//
//  MapTests.swift
//  RiskeloUSTests
//
//  The board is generated from a drawing in plain characters, not typed in
//  territory by territory. That is exactly why it has to be checked: a letter
//  moved in the plan does not show, and can isolate a territory or cut a
//  continent in two. A game could no longer finish, and nothing would say so.
//

import CoreGraphics
import Testing
@testable import RiskeloUS

/// The same checks apply to every board in the catalogue: a board added must
/// not be able to get in without passing them.
struct MapTests {

    let board = Boards.ring.board

    @Test(arguments: Boards.allCases)
    func everyBoardHoldsTogether(_ p: Boards) {
        let m = p.board.map
        #expect(m.isConnected, "\(p.label) is in pieces")
        #expect(m.order.count >= 20, "\(p.label) is too small")
        #expect(m.continentsInOrder.count >= 4)
        for id in m.order {
            #expect(!m.neighbors(of: id).isEmpty, "\(p.label): \(id) touches nothing")
            for neighbor in m.neighbors(of: id) {
                #expect(m.areAdjacent(neighbor, id), "\(p.label): one-way adjacency")
            }
        }
        let names = m.order.compactMap { m[$0]?.name }
        #expect(Set(names).count == names.count, "\(p.label): two territories share a name")

        for continent in m.continentsInOrder {
            let inside = Set(continent.territories)
            var seen: Set<TerritoryID> = [continent.territories[0]]
            var stack = [continent.territories[0]]
            while let id = stack.popLast() {
                for n in m.neighbors(of: id) where inside.contains(n) && !seen.contains(n) {
                    seen.insert(n); stack.append(n)
                }
            }
            #expect(seen.count == inside.count, "\(p.label): \(continent.name) is in pieces")
            let doors = Set(continent.territories.filter { id in
                m.neighbors(of: id).contains { m[$0]?.continent != continent.id }
            })
            #expect(doors.count >= 1, "\(p.label): \(continent.name) is unreachable")
        }

        // A continent with a single door is unassailable once held, and
        // decides the game on its own: that is Risk's Australia. A board is
        // allowed one — it is a design choice — but never two, or the game
        // comes down to who takes them.
        let fortresses = m.continentsInOrder.filter { c in
            Set(c.territories.filter { id in
                m.neighbors(of: id).contains { m[$0]?.continent != c.id }
            }).count == 1
        }
        #expect(fortresses.count <= 1,
                "\(p.label): \(fortresses.map(\.name).joined(separator: ", ")) all have a single door")
    }

    @Test func theBoardIsInOnePiece() {
        #expect(board.map.isConnected)
        #expect(board.map.order.count == 28)
        #expect(board.map.continentsInOrder.count == 5)
    }

    @Test func adjacencyIsReciprocal() {
        for id in board.map.order {
            for neighbor in board.map.neighbors(of: id) {
                #expect(board.map.areAdjacent(neighbor, id),
                        "\(id) touches \(neighbor), but not the other way round")
            }
        }
    }

    @Test func nobodyIsIsolated() {
        for id in board.map.order {
            #expect(!board.map.neighbors(of: id).isEmpty, "\(id) touches nothing")
        }
    }

    @Test func everyContinentIsInOnePiece() {
        for continent in board.map.continentsInOrder {
            let inside = Set(continent.territories)
            var seen: Set<TerritoryID> = [continent.territories[0]]
            var stack = [continent.territories[0]]
            while let id = stack.popLast() {
                for n in board.map.neighbors(of: id) where inside.contains(n) && !seen.contains(n) {
                    seen.insert(n)
                    stack.append(n)
                }
            }
            #expect(seen.count == inside.count, "\(continent.name) is in pieces")
        }
    }

    /// A continent with a single door is unassailable, and decides the game on
    /// its own — that is the flaw of Australia in the original Risk.
    @Test func noContinentHasASingleDoor() {
        for continent in board.map.continentsInOrder {
            let doors = Set(continent.territories.filter { id in
                board.map.neighbors(of: id).contains { board.map[$0]?.continent != continent.id }
            })
            #expect(doors.count >= 2, "\(continent.name) has only \(doors.count) door")
        }
    }

    @Test func everyTerritoryHasANameAndAPlace() {
        for id in board.map.order {
            let t = board.map[id]
            #expect(t != nil)
            #expect(!(t?.name.isEmpty ?? true))
            let center = board.layout.centers[id]
            #expect(center != nil)
            #expect((0...1).contains(center?.x ?? -1))
            #expect((center?.y ?? -1) >= 0 && (center?.y ?? 99) <= board.layout.aspect)
        }
    }

    /// A cell has six sides; those that do not face a neighbor in the same
    /// continent are borders. Crossings go through no side at all — that is
    /// the whole point of them — and so are set aside.
    @Test(arguments: Boards.allCases)
    func everyBoardKnowsWhereItsBordersAre(_ p: Boards) {
        let m = p.board.map
        for id in m.order {
            let overseas = Set(p.board.layout.seaRoutes.compactMap { r -> TerritoryID? in
                r.from == id ? r.to : (r.to == id ? r.from : nil)
            })
            let sameContinent = m.neighbors(of: id).filter {
                !overseas.contains($0) && m[$0]?.continent == m[id]?.continent
            }.count
            #expect(p.board.layout.frontierEdges[id]?.count == 6 - sameContinent,
                    "\(p.label): \(m[id]?.name ?? id)")
        }
    }

    /// A crossing has to be reciprocal and lead somewhere. Written by hand,
    /// it is the only part of the board that can be wrong.
    @Test(arguments: Boards.allCases)
    func crossingsAreReciprocal(_ p: Boards) {
        let m = p.board.map
        for route in p.board.layout.seaRoutes {
            #expect(m[route.from] != nil, "\(p.label): crossing from nowhere")
            #expect(m[route.to] != nil, "\(p.label): crossing to nowhere")
            #expect(m.areAdjacent(route.from, route.to), "\(p.label): one-way crossing")
            #expect(m.areAdjacent(route.to, route.from), "\(p.label): one-way crossing")
            #expect(route.from != route.to)
        }
    }

    /// The border lines are computed once, when the plan is built, and the
    /// board draws them without thinking. If a letter of the plan moves and
    /// that computation shifts, the continents will look wrong without
    /// anything crashing — the player will think they have to take a
    /// territory that is not part of it.
    ///
    /// The invariant is simple: a cell has six sides; those that do not face
    /// a neighbor in the same continent are borders.
    @Test func bordersMatchTheContinents() {
        for id in board.map.order {
            let sameContinent = board.map.neighbors(of: id).filter {
                board.map[$0]?.continent == board.map[id]?.continent
            }.count
            let lines = board.layout.frontierEdges[id]?.count ?? -1
            #expect(lines == 6 - sameContinent,
                    "\(board.map[id]?.name ?? id): \(lines) lines for \(6 - sameContinent) expected")
        }
    }

    @Test func namesAreUnique() {
        let names = board.map.order.compactMap { board.map[$0]?.name }
        #expect(Set(names).count == names.count)
    }
}

// MARK: - Framing

/// How far the board can move under a panel eating its bottom.
///
/// The reframing aimed true and the bound stopped it on the way: the two
/// places of an assault stayed under the panel, on a phone where it covers
/// three quarters of the map. So you could no longer see where you were
/// fighting at the moment of deciding how many troops advance — and a
/// screenshot taken by hand was the only way to notice. This is arithmetic:
/// it gets checked here.
struct FramingTests {

    /// The measurements of an ordinary iPhone at the moment of choosing: the
    /// board has 587 points of height, the map takes 400 of them, and the
    /// panel covers three quarters of what is left.
    let view: CGFloat = 587, board: CGFloat = 400, covered: CGFloat = 0.75

    /// A place at the bottom of the map has to be able to come up into the
    /// free band. That is the case that failed twice running.
    @Test func aPlaceAtTheBottomCanComeUpIntoTheFreeBand() {
        let middleOfBand = view * (1 - covered) / 2
        // A place four fifths of the way down the map, seen from its top.
        let place = (view - board) / 2 + board * 0.8
        let aim = middleOfBand - place
        let bounds = Framing.verticalBounds(viewHeight: view, boardHeight: board,
                                            covered: covered)
        #expect(bounds.contains(aim),
                "the reframing aims at \(aim) and the bound stops it at \(bounds.lowerBound)")
    }

    /// We do not lose the board for all that: lifted as far as it goes, a
    /// margin of it stays below the top of the screen; pushed down as far as
    /// it goes, its top stays within the band nothing covers.
    @Test func theBoardNeverLeavesEntirely() {
        for covered in [CGFloat(0), 0.4, 0.75, 0.9] {
            let bounds = Framing.verticalBounds(viewHeight: view, boardHeight: board,
                                                covered: covered)
            let bottomOfBoard = (view + board) / 2 + bounds.lowerBound
            #expect(bottomOfBoard >= Framing.margin - 0.01,
                    "covered \(covered): only \(bottomOfBoard) points of board are left")
            let topOfBoard = (view - board) / 2 + bounds.upperBound
            #expect(topOfBoard <= view * (1 - covered) - Framing.margin + 0.01,
                    "covered \(covered): the top of the board passes under the free band")
        }
    }

    /// A map larger than the view wanders further.
    @Test func aLargeBoardWandersFurther() {
        let small = Framing.verticalBounds(viewHeight: view, boardHeight: 300, covered: 0)
        let large = Framing.verticalBounds(viewHeight: view, boardHeight: 900, covered: 0)
        #expect(large.lowerBound < small.lowerBound)
        #expect(large.upperBound > small.upperBound)
    }

    /// And with nothing covering, the map wanders both ways.
    @Test func withNoPanelTheMoveStaysTwoSided() {
        let bounds = Framing.verticalBounds(viewHeight: view, boardHeight: board,
                                            covered: 0)
        #expect(bounds.lowerBound < 0 && bounds.upperBound > 0)
    }
}
