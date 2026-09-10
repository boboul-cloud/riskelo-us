//
//  icone.swift
//  Riskelo — outil, hors application
//
//  L'icône, dessinée en code.
//
//  Elle dit la règle en un glyphe : un hexagone du plateau, partagé entre les
//  deux camps, et le point d'interrogation qui les départage. L'hexagone est
//  la forme même des territoires et découpe une silhouette reconnaissable
//  entre des carrés arrondis ; le partage dit l'affrontement ; le « ? » à
//  cheval sur les deux moitiés dit ce qui tranche.
//
//  Écrite plutôt que peinte pour deux raisons : les couleurs sont exactement
//  celles des camps sur le plateau — si la palette bouge, on régénère — et
//  les deux systèmes n'attendent pas la même chose. iOS veut un carré plein,
//  qu'il masque lui-même ; macOS veut un galet arrondi posé dans un carré
//  transparent, aux proportions de la grille d'Apple.
//
//      swiftc -O -parse-as-library -o /tmp/icone outils/icone.swift && /tmp/icone
//

import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

enum Icone {

    enum Machine { case ios, mac }

    // Les couleurs des camps, reprises telles quelles de Palette.sides.
    //
    // La version française prend le premier camp et le deuxième, bleu et
    // rouge ; celle-ci prend le troisième et le deuxième, vert et rouge. Ce
    // ne sont pas des couleurs inventées pour l'occasion : ce sont deux camps
    // du plateau, et l'icône continue donc de dire vrai. Deux icônes qui ne
    // se confondent pas dans un dock, sans qu'aucune des deux mente.
    static let campVert  = CGColor(red: 0.36, green: 0.60, blue: 0.36, alpha: 1)
    static let campRouge = CGColor(red: 0.80, green: 0.31, blue: 0.24, alpha: 1)
    static let cielHaut  = CGColor(red: 0.12, green: 0.16, blue: 0.21, alpha: 1)
    static let cielBas   = CGColor(red: 0.06, green: 0.08, blue: 0.11, alpha: 1)
    static let liseré    = CGColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 0.34)

    /// Hexagone pointe en haut, centré. Le partage vertical passe par les deux
    /// pointes : c'est la seule coupe qui laisse les deux camps identiques.
    static func hexagone(centre c: CGPoint, rayon r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        for i in 0 ..< 6 {
            let a = Double(i) * .pi / 3 + .pi / 2      // première pointe en haut
            let point = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        p.closeSubpath()
        return p
    }

    static func dessine(_ ctx: CGContext, cote: CGFloat, machine: Machine) {
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        // Le corps de l'icône. Sur Mac, un galet posé dans un carré transparent,
        // aux proportions de la grille d'Apple : 824 sur 1024, rayon 185.
        let corps: CGRect
        if machine == .mac {
            let marge = cote * 100 / 1024
            corps = CGRect(x: marge, y: marge, width: cote - 2 * marge, height: cote - 2 * marge)
            let galet = CGPath(roundedRect: corps,
                               cornerWidth: cote * 185 / 1024, cornerHeight: cote * 185 / 1024,
                               transform: nil)
            ctx.addPath(galet)
            ctx.clip()
        } else {
            corps = CGRect(x: 0, y: 0, width: cote, height: cote)
        }

        // Le ciel : la nuit du plateau, un peu levée vers le haut.
        let degrade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [cielHaut, cielBas] as CFArray,
                                 locations: [0, 1])!
        ctx.drawLinearGradient(degrade,
                               start: CGPoint(x: corps.midX, y: corps.maxY),
                               end: CGPoint(x: corps.midX, y: corps.minY),
                               options: [])

        let centre = CGPoint(x: corps.midX, y: corps.midY)
        let rayon = corps.width * 0.375
        let hexa = hexagone(centre: centre, rayon: rayon)

        // Les six voisins, esquissés très en retrait. Sans eux, l'hexagone
        // n'est qu'une forme ; avec eux, c'est une case au milieu d'un
        // plateau. Ils s'effacent d'eux-mêmes aux petites tailles, où ils
        // n'auraient été que du bruit.
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 0.11))
        ctx.setLineWidth(cote * 0.011)
        for i in 0 ..< 6 {
            let a = Double(i) * .pi / 3
            let voisin = CGPoint(x: centre.x + rayon * 3.0.squareRoot() * cos(a),
                                 y: centre.y + rayon * 3.0.squareRoot() * sin(a))
            ctx.addPath(hexagone(centre: voisin, rayon: rayon))
        }
        ctx.strokePath()
        ctx.restoreGState()

        // Les deux camps, de part et d'autre de l'axe.
        for (camp, gauche) in [(campVert, true), (campRouge, false)] {
            ctx.saveGState()
            ctx.addPath(hexa)
            ctx.clip()
            ctx.setFillColor(camp)
            ctx.fill(CGRect(x: gauche ? corps.minX : centre.x, y: corps.minY,
                            width: corps.width / 2, height: corps.height))
            ctx.restoreGState()
        }

        // Le liseré : ce qui fait de l'hexagone une pièce de jeu et non une tache.
        ctx.addPath(hexa)
        ctx.setStrokeColor(liseré)
        ctx.setLineWidth(cote * 0.013)
        ctx.strokePath()

        // Le point d'interrogation, à cheval sur les deux moitiés.
        let base = NSFont.systemFont(ofSize: 100, weight: .heavy)
        let dessin = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let police = NSFont(descriptor: dessin, size: cote * 0.46) ?? base
        let texte = NSAttributedString(string: "?", attributes: [
            .font: police,
            .foregroundColor: NSColor.white,
        ])
        let ligne = CTLineCreateWithAttributedString(texte)
        let encre = CTLineGetBoundsWithOptions(ligne, .useGlyphPathBounds)
        ctx.textPosition = CGPoint(x: centre.x - encre.width / 2 - encre.minX,
                                   y: centre.y - encre.height / 2 - encre.minY)
        CTLineDraw(ligne, ctx)
    }

    static func png(cote: Int, machine: Machine) -> Data {
        let ctx = CGContext(data: nil, width: cote, height: cote, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // AppKit dessine le texte par le contexte courant : on le lui prête.
        let ancien = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        dessine(ctx, cote: CGFloat(cote), machine: machine)
        NSGraphicsContext.current = ancien

        let image = ctx.makeImage()!
        let sortie = NSMutableData()
        let dest = CGImageDestinationCreateWithData(sortie, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        return sortie as Data
    }
}

@main
struct Fabrique {
    static func main() throws {
        let racine = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let dossier = racine
            .appendingPathComponent("Sources/Resources/Assets.xcassets/AppIcon.appiconset")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)

        struct Piece { let nom: String; let cote: Int; let machine: Icone.Machine; let json: String }
        var pieces: [Piece] = [
            .init(nom: "icone-ios-1024.png", cote: 1024, machine: .ios,
                  json: #"{"filename":"icone-ios-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}"#),
        ]
        // macOS veut toute l'échelle, du menu au Finder.
        for (points, echelles) in [(16, [1, 2]), (32, [1, 2]), (128, [1, 2]), (256, [1, 2]), (512, [1, 2])] {
            for e in echelles {
                let cote = points * e
                let nom = "icone-mac-\(points)x\(points)@\(e)x.png"
                pieces.append(.init(nom: nom, cote: cote, machine: .mac,
                                    json: #"{"filename":"\#(nom)","idiom":"mac","scale":"\#(e)x","size":"\#(points)x\#(points)"}"#))
            }
        }

        for p in pieces {
            try Icone.png(cote: p.cote, machine: p.machine)
                .write(to: dossier.appendingPathComponent(p.nom))
        }

        let contents = """
        {
          "images" : [
            \(pieces.map(\.json).joined(separator: ",\n    "))
          ],
          "info" : { "author" : "xcode", "version" : 1 }
        }
        """
        try contents.write(to: dossier.appendingPathComponent("Contents.json"),
                           atomically: true, encoding: .utf8)

        // Des aperçus à part, pour juger : la grande, le galet du Mac, et la
        // petite — c'est à 64 pixels qu'une icône se juge, pas à 1024.
        try Icone.png(cote: 512, machine: .ios)
            .write(to: racine.appendingPathComponent("outils/apercu-icone.png"))
        try Icone.png(cote: 512, machine: .mac)
            .write(to: racine.appendingPathComponent("outils/apercu-icone-mac.png"))
        try Icone.png(cote: 64, machine: .ios)
            .write(to: racine.appendingPathComponent("outils/apercu-icone-64.png"))

        print("\(pieces.count) images écrites dans \(dossier.path)")
    }
}
