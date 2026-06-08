import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(red: 15 / 255, green: 37 / 255, blue: 64 / 255, alpha: 1).setFill()
rect.fill()

let gradient = NSGradient(colors: [
    NSColor(red: 42 / 255, green: 74 / 255, blue: 115 / 255, alpha: 0.22),
    NSColor(red: 15 / 255, green: 37 / 255, blue: 64 / 255, alpha: 0)
])!
gradient.draw(fromCenter: NSPoint(x: size / 2, y: size / 2), radius: 40, toCenter: NSPoint(x: size / 2, y: size / 2), radius: 540, options: [])

let markWidth = CGFloat(size) * 0.58
let markHeight = CGFloat(size) * 0.50
let originX = (CGFloat(size) - markWidth) / 2
let originY = (CGFloat(size) - markHeight) / 2 - 18
let path = NSBezierPath()
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.lineWidth = CGFloat(size) * 0.045
path.move(to: NSPoint(x: originX, y: originY))
path.line(to: NSPoint(x: CGFloat(size) / 2, y: originY + markHeight))
path.line(to: NSPoint(x: originX + markWidth, y: originY))
NSColor(red: 184 / 255, green: 134 / 255, blue: 11 / 255, alpha: 1).setStroke()
path.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}

try png.write(to: URL(fileURLWithPath: "Krokva/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"))
