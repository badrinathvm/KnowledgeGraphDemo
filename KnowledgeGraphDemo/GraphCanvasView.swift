import SwiftUI

struct GraphCanvasView: View {
    let vm: GraphViewModel

    // Capture gesture start lazily so programmatic pan changes don't desync
    @State private var dragStart: CGPoint? = nil
    @State private var magnifyStart: (scale: CGFloat, pan: CGPoint)? = nil

    var body: some View {
        let nodes       = vm.positionedNodes
        let edgeList    = vm.edges
        let highlighted = vm.highlightedIds
        let selectedId  = vm.selectedNode?.id
        let scale       = vm.zoomScale
        let pan         = vm.panOffset
        let hasHL       = !highlighted.isEmpty

        GeometryReader { geo in
            Canvas { ctx, size in
                // Fixed node size — grid layout guarantees enough spacing
                let baseR:  CGFloat = 9
                let hlR:    CGFloat = min(baseR * 2.6, 20) * min(scale, 2.0)
                let dotR:   CGFloat = baseR * min(scale, 2.0)

                func sp(_ p: CGPoint) -> CGPoint {
                    CGPoint(x: p.x * scale + pan.x, y: p.y * scale + pan.y)
                }
                let margin = hlR + 24
                let vp = CGRect(x: -margin, y: -margin,
                                width: size.width + margin * 2,
                                height: size.height + margin * 2)

                let posMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, sp($0.position)) })

                // Edges — only for small graphs or when zoomed in
                if !hasHL && nodes.count <= 300 {
                    for edge in edgeList {
                        guard let src = posMap[edge.source],
                              let tgt = posMap[edge.target],
                              vp.contains(src) || vp.contains(tgt) else { continue }
                        var path = Path()
                        path.move(to: src); path.addLine(to: tgt)
                        ctx.stroke(path, with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
                    }
                }

                for pn in nodes {
                    let s = posMap[pn.id] ?? sp(pn.position)
                    guard vp.contains(s) else { continue }

                    let isHL  = highlighted.contains(pn.id)
                    let isSel = pn.id == selectedId

                    // Dim non-result background nodes when a query is active
                    if hasHL && !isHL && !isSel {
                        let r = dotR * 0.75
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: s.x-r, y: s.y-r, width: r*2, height: r*2)),
                            with: .color(nodeColor(pn.label).opacity(0.15))
                        )
                        continue
                    }

                    let r = (isHL || isSel) ? hlR : dotR
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: s.x-r, y: s.y-r, width: r*2, height: r*2)),
                        with: .color(nodeColor(pn.label).opacity(isHL ? 1.0 : 0.85))
                    )

                    if isHL {
                        // White outline ring
                        let ringR = r + 4
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: s.x-ringR, y: s.y-ringR, width: ringR*2, height: ringR*2)),
                            with: .color(Color.black.opacity(0.7)), lineWidth: 2
                        )
                        // Name label below
                        let fs = max(9, min(13, 9 * min(scale, 1.6)))
                        ctx.draw(
                            Text(pn.name).font(.system(size: fs, weight: .semibold)).foregroundStyle(Color.black.opacity(0.85)),
                            at: CGPoint(x: s.x, y: s.y + ringR + 3), anchor: .top
                        )
                    }

                    if isSel {
                        let ringR = r + (isHL ? 9 : 5)
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: s.x-ringR, y: s.y-ringR, width: ringR*2, height: ringR*2)),
                            with: .color(Color.black.opacity(0.45)), lineWidth: 1.5
                        )
                        if !isHL {
                            let fs = max(9, min(13, 9 * min(scale, 1.6)))
                            ctx.draw(
                                Text(pn.name).font(.system(size: fs)).foregroundStyle(Color.black.opacity(0.75)),
                                at: CGPoint(x: s.x, y: s.y + r + 5), anchor: .top
                            )
                        }
                    }

                    // Labels for all visible nodes when deeply zoomed
                    if !isHL && !isSel && scale > 3.0 {
                        ctx.draw(
                            Text(pn.name).font(.system(size: max(7, 7 * scale/3))).foregroundStyle(Color.black.opacity(0.55)),
                            at: CGPoint(x: s.x, y: s.y + dotR + 3), anchor: .top
                        )
                    }
                }
            }
            .background(Color(white: 0.96))
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, nodes: nodes, scale: scale, pan: pan)
            }
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { val in
                        // Capture start lazily — safe even after programmatic pan changes
                        if dragStart == nil { dragStart = vm.panOffset }
                        vm.panOffset = CGPoint(
                            x: dragStart!.x + val.translation.width,
                            y: dragStart!.y + val.translation.height
                        )
                    }
                    .onEnded { _ in dragStart = nil }
                    .simultaneously(with:
                        MagnifyGesture()
                            .onChanged { val in
                                if magnifyStart == nil {
                                    magnifyStart = (vm.zoomScale, vm.panOffset)
                                }
                                let (startScale, startPan) = magnifyStart!
                                let newScale = max(0.3, min(8.0, startScale * val.magnification))
                                let ax = val.startAnchor.x * geo.size.width
                                let ay = val.startAnchor.y * geo.size.height
                                let ratio = newScale / startScale
                                vm.zoomScale = newScale
                                vm.panOffset = CGPoint(
                                    x: ax - (ax - startPan.x) * ratio,
                                    y: ay - (ay - startPan.y) * ratio
                                )
                            }
                            .onEnded { _ in magnifyStart = nil }
                    )
            )
            .onAppear { vm.canvasSize = geo.size }
            .onChange(of: geo.size) { _, size in vm.canvasSize = size }
        }
    }

    private func handleTap(at location: CGPoint, nodes: [PositionedNode],
                           scale: CGFloat, pan: CGPoint) {
        let tap = CGPoint(x: (location.x - pan.x) / scale,
                          y: (location.y - pan.y) / scale)
        let threshold: CGFloat = 24 / scale
        let nearest = nodes.min(by: {
            hypot($0.position.x - tap.x, $0.position.y - tap.y) <
            hypot($1.position.x - tap.x, $1.position.y - tap.y)
        })
        if let n = nearest, hypot(n.position.x - tap.x, n.position.y - tap.y) < threshold {
            vm.selectedNode = (vm.selectedNode?.id == n.id) ? nil : n.node
        } else {
            vm.selectedNode = nil
        }
    }

    private func nodeColor(_ label: String) -> Color {
        switch label {
        case "Movie":  return Color(red: 0.25, green: 0.55, blue: 0.95)
        case "Person": return Color(red: 0.25, green: 0.85, blue: 0.45)
        case "Genre":  return Color(red: 1.0,  green: 0.65, blue: 0.1)
        default:       return .gray
        }
    }
}
