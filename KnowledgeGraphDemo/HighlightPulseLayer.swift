import SwiftUI

struct HighlightPulseLayer: View {
    let vm: GraphViewModel

    var body: some View {
        let nodes       = vm.positionedNodes
        let highlighted = vm.highlightedIds
        let scale       = vm.zoomScale
        let pan         = vm.panOffset

        if highlighted.isEmpty {
            Canvas { _, _ in }.allowsHitTesting(false)
        } else {
            TimelineView(.animation) { timeline in
                Canvas { ctx, _ in
                    let count = nodes.count
                    // Match the highlighted node radius from GraphCanvasView
                    let baseR: CGFloat = count > 500 ? 4 : count > 200 ? 6 : 12
                    let hlNodeR = min(baseR * 2.8, 14) * min(scale, 2.0)

                    let t     = timeline.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: 1.2)
                    // Tight pulse ring just outside the white highlight ring
                    let pulseR = hlNodeR + 4 + 6 * sin(phase / 1.2 * .pi * 2)
                    let opacity = 0.55 + 0.35 * sin(phase / 1.2 * .pi * 2)

                    for pn in nodes where highlighted.contains(pn.id) {
                        let sx = pn.position.x * scale + pan.x
                        let sy = pn.position.y * scale + pan.y
                        let rect = CGRect(x: sx - pulseR, y: sy - pulseR,
                                         width: pulseR * 2, height: pulseR * 2)
                        ctx.stroke(Path(ellipseIn: rect),
                                   with: .color(.yellow.opacity(opacity)), lineWidth: 2)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
