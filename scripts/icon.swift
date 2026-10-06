import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1]).appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let s = CGFloat(pixels)
        NSColor(calibratedRed: 0.07, green: 0.1, blue: 0.15, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: s*0.04,y:s*0.04,width:s*0.92,height:s*0.92), xRadius:s*0.23,yRadius:s*0.23).fill()
        NSColor(calibratedRed: 0.38,green:0.85,blue:0.77,alpha:1).setStroke()
        let line = NSBezierPath(); line.lineWidth = s*0.055; line.lineCapStyle = .round; line.lineJoinStyle = .round
        let points: [(CGFloat,CGFloat)] = [(0.2,0.5),(0.3,0.5),(0.36,0.7),(0.44,0.28),(0.53,0.77),(0.62,0.36),(0.68,0.5),(0.8,0.5)]
        for (i,p) in points.enumerated() { let point = NSPoint(x:p.0*s,y:p.1*s); if i == 0 {line.move(to:point)} else {line.line(to:point)} }; line.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
