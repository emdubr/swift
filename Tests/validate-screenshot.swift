import AppKit
import Foundation

// A returned simctl PID and a nonzero PNG can still be a white launch screen.
// Check interior pixels rather than accepting a screenshot of iOS transition.
// Deliberately excludes the status bar, which can be dark over a white screen.
guard CommandLine.arguments.count == 2,
      let data = try? Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])),
      let image = NSBitmapImageRep(data: data),
      image.pixelsWide > 100, image.pixelsHigh > 100 else {
    fputs("No decodable full-size PNG\n", stderr)
    exit(2)
}
let xs: [Double] = [0.10, 0.25, 0.50, 0.75, 0.90]
let ys: [Double] = [0.14, 0.23, 0.33, 0.50, 0.66, 0.80, 0.92]
var visible = 0
for x in xs {
    for y in ys {
        let px = min(image.pixelsWide - 1, Int(Double(image.pixelsWide) * x))
        let py = min(image.pixelsHigh - 1, Int(Double(image.pixelsHigh) * y))
        guard let c = image.colorAt(x: px, y: py)?.usingColorSpace(.deviceRGB) else {
            continue
        }
        // Accept dark UI, actual map color or accent green. Reject uniform white
        // and near-white simulator launch screens even when the status bar renders.
        if c.redComponent < 0.90 || c.greenComponent < 0.90 || c.blueComponent < 0.90 {
            visible += 1
        }
    }
}
print("Non-white interior samples: \(visible) / \(xs.count * ys.count)")
if visible < 5 {
    fputs("FAIL: only a white/blank launch screen was captured\n", stderr)
    exit(3)
}
print("PASS: visual screenshot contains rendered UI content")
