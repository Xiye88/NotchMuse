import AppKit

guard CommandLine.arguments.count == 3,
      let source = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fatalError("Usage: render_dmg_background.swift input.png output.png")
}

let size = source.size
let image = NSImage(size: NSSize(width: size.width / 2, height: size.height / 2))
image.lockFocus()
NSGraphicsContext.current?.cgContext.scaleBy(x: 0.5, y: 0.5)
source.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)

func drawCentered(_ string: String, y: CGFloat, size: CGFloat, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (string as NSString).draw(
        in: NSRect(x: 36, y: y, width: image.size.width * 2 - 72, height: size + 12),
        withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
    )
}

let arrow = NSBezierPath()
arrow.lineWidth = 12
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: size.width * 0.43, y: size.height * 0.50))
arrow.line(to: NSPoint(x: size.width * 0.57, y: size.height * 0.50))
arrow.move(to: NSPoint(x: size.width * 0.535, y: size.height * 0.545))
arrow.line(to: NSPoint(x: size.width * 0.58, y: size.height * 0.50))
arrow.line(to: NSPoint(x: size.width * 0.535, y: size.height * 0.455))
NSColor(calibratedRed: 1, green: 0.59, blue: 0.25, alpha: 0.96).setStroke()
arrow.stroke()

drawCentered("Drag NotchMuse to Applications", y: 152, size: 32, color: .white)
drawCentered("将 NotchMuse 拖到 Applications 文件夹", y: 112, size: 29, color: .white)
drawCentered("Not notarized. If blocked: System Settings → Privacy & Security → Open Anyway.", y: 65, size: 18, color: NSColor(white: 0.86, alpha: 1))
drawCentered("应用尚未公证。若被阻止：系统设置 → 隐私与安全性 → 仍要打开。", y: 34, size: 18, color: NSColor(white: 0.86, alpha: 1))

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render DMG background")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
