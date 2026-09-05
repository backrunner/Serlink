import AppKit

// Reproducible typography and vector artwork; Finder overlays the real app at
// (360, 236). Keep these logical dimensions in sync with macos/dmg/settings.py.
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "macos/dmg")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 720
let height = 480
func color(_ hex: Int) -> NSColor {
  NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
          green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
  NSRect(x: x, y: CGFloat(height) - y - h, width: w, height: h)
}
for scale in [1, 2] {
  let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale,
    pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  bitmap.size = NSSize(width: width, height: height)
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

  color(0xF7FAFA).setFill()
  NSBezierPath(rect: rect(0, 0, 720, 480)).fill()
  // Quiet circuit traces frame the app without implying a drag-and-drop action.
  for mirrored in [false, true] {
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
      NSPoint(x: mirrored ? 720 - x : x, y: 480 - y)
    }
    color(0xD9E9E8).setStroke()
    for (index, y) in [190.0, 238.0, 286.0].enumerated() {
      let path = NSBezierPath()
      path.move(to: point(0, y))
      path.line(to: point(68 + CGFloat(index) * 22, y))
      path.line(to: point(100 + CGFloat(index) * 22, y + 30))
      path.line(to: point(195, y + 30))
      path.lineWidth = 1
      path.stroke()
      let node = point(195, y + 30)
      color(0xA4D8D3).setFill()
      NSBezierPath(ovalIn: NSRect(x: node.x - 3, y: node.y - 3, width: 6, height: 6)).fill()
    }
  }
  color(0xFFFFFF).setFill()
  let tile = NSBezierPath(roundedRect: rect(280, 156, 160, 166), xRadius: 28, yRadius: 28)
  tile.fill()
  color(0xE1ECEB).setStroke()
  tile.lineWidth = 1
  tile.stroke()

  func text(_ string: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, hex: Int) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (string as NSString).draw(in: rect(30, y, 660, size * 1.8), withAttributes: [
      .font: NSFont.systemFont(ofSize: size, weight: weight),
      .foregroundColor: color(hex), .paragraphStyle: paragraph,
    ])
  }
  text("Serlink", y: 43, size: 42, weight: .semibold, hex: 0x183946)
  text("SSH  /  SFTP  /  TERMINAL", y: 101, size: 12, weight: .medium, hex: 0x658087)
  text("Double-click to install & open", y: 348, size: 23, weight: .semibold, hex: 0x183946)
  text("双击安装并打开", y: 389, size: 16, weight: .regular, hex: 0x658087)
  text("macOS", y: 444, size: 11, weight: .medium, hex: 0x658087)
  color(0x20B5AF).setFill()
  NSBezierPath(rect: rect(0, 477, 720, 3)).fill()

  NSGraphicsContext.restoreGraphicsState()
  let name = scale == 1 ? "background.png" : "background@2x.png"
  try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}
