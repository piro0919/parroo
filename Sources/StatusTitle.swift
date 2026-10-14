import AppKit

/// メニューバーの絵。鸚鵡の影絵の右に、選んだ項目を1行か2行で描く。
/// NSStatusItem の title は1行しか出せないので、Hawky の StatusTitle を写して影絵ごと1枚の絵にする。
/// テンプレート画像にしておけば、メニューバーの明暗に合わせて OS が色を付ける
@MainActor
enum StatusTitle {
    /// メニューバーの厚み。これが上限
    private static let height: CGFloat = 22
    private static let iconSize: CGFloat = 18

    /// 2行のときの書体。上下で同じにする
    private static let stackedFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    /// 1行のときの書体
    private static let singleFont = NSFont.monospacedDigitSystemFont(
        ofSize: NSFont.systemFontSize(for: .regular), weight: .regular)

    static func image(icon: NSImage?, lines: [String]) -> NSImage {
        let stacked = lines.count > 1
        let font = stacked ? stackedFont : singleFont
        let texts = lines.map { line in
            // 色は描くときの塗りから取る。Core Text は NSColor の色の指定を読まない
            CTLineCreateWithAttributedString(
                NSAttributedString(
                    string: line,
                    attributes: [
                        .font: font,
                        NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true,
                    ]))
        }
        let widths = texts.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }

        // 字の並ぶ線。大文字の高さを、1行なら枠の真ん中に、2行なら上下の余白を揃えて置く（Hawky と同じ）
        let cap = font.capHeight
        let baselines: [CGFloat] =
            stacked
            ? [height - (height - cap * 2 - 4) / 2 - cap, (height - cap * 2 - 4) / 2]
            : [(height - cap) / 2]

        let textX = iconSize + 4
        let width = texts.isEmpty ? iconSize : ceil(textX + (widths.max() ?? 0))

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            icon?.draw(in: NSRect(x: 0, y: (height - iconSize) / 2, width: iconSize, height: iconSize))
            guard let context = NSGraphicsContext.current?.cgContext else { return true }
            context.setFillColor(NSColor.black.cgColor)
            context.textMatrix = .identity
            // 2行は左で揃える。ラベル（1w: など）の頭が上下で並ぶ
            for (text, baseline) in zip(texts, baselines) {
                context.textPosition = CGPoint(x: textX, y: baseline)
                CTLineDraw(text, context)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// 見本の値で、明るいメニューバーと暗いメニューバーに置いた絵を書き出す。1行・2行の両方を並べる
    static func renderSample(to path: String) -> Int32 {
        let icon = NSImage(named: "StatusIcon")
        icon?.size = NSSize(width: iconSize, height: iconSize)
        let now = Date()
        var usage = Usage()
        usage.week = UsageWindow(percent: 68.6, resetsAt: now.addingTimeInterval(2 * 86400 + 5 * 3600))
        usage.fiveHour = UsageWindow(percent: 42, resetsAt: now.addingTimeInterval(80 * 60))
        let samples: [[StatusItem]] = [
            Preferences.defaultLines, [.fiveHourPercent, .fiveHourResetIn], [.weekPercent], [],
        ]
        let images = samples.map { items in
            image(icon: icon, lines: items.map { Format.statusLine($0, usage: usage, now: now) })
        }

        let scale: CGFloat = 2
        let pad: CGFloat = 12
        let width = images.map(\.size.width).reduce(pad, { $0 + $1 + pad })
        let size = NSSize(width: width, height: height * 2)
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0)
        else { return 1 }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        for (row, (background, ink)) in [(NSColor(white: 0.93, alpha: 1), NSColor.black), (.black, .white)]
            .enumerated()
        {
            let y = CGFloat(1 - row) * height
            background.setFill()
            NSRect(x: 0, y: y, width: size.width, height: height).fill()
            var x = pad
            for image in images {
                // テンプレート画像は透明度だけが効く。メニューバーと同じく、文字の色で塗って置く
                let tinted = NSImage(size: image.size, flipped: false) { rect in
                    image.draw(in: rect)
                    ink.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: NSRect(x: x, y: y, width: image.size.width, height: image.size.height))
                x += image.size.width + pad
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        guard let png = rep.representation(using: .png, properties: [:]) else { return 1 }
        do {
            try png.write(to: URL(fileURLWithPath: path))
            return 0
        } catch {
            return 1
        }
    }
}
