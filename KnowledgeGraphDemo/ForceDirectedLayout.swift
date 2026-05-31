import CoreGraphics

enum ForceDirectedLayout {
    nonisolated static func tick(nodes: inout [PositionedNode], edges: [GraphEdge], canvasSize: CGSize) {
        let count = nodes.count
        guard count > 0 else { return }

        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        var forces = [CGPoint](repeating: .zero, count: count)

        var indexMap = [String: Int](minimumCapacity: count)
        for i in nodes.indices { indexMap[nodes[i].id] = i }

        // Adaptive parameters for dense graphs
        let large = count > 300
        let repulsionK: CGFloat = large ? 1500 : 8000
        let cutoff:     CGFloat = large ? 120  : 300
        let cutoff2     = cutoff * cutoff
        // ε² softening prevents NaN when two nodes share the same position (dist=0 → 0*∞=NaN)
        let ε2: CGFloat = 9.0

        // Pairwise repulsion with spatial cutoff (quick-reject drops O(n²) cost for dense graphs)
        for i in 0..<count {
            for j in (i + 1)..<count {
                let dx = nodes[i].position.x - nodes[j].position.x
                let dy = nodes[i].position.y - nodes[j].position.y
                if abs(dx) > cutoff || abs(dy) > cutoff { continue }
                let dist2 = dx * dx + dy * dy
                if dist2 > cutoff2 { continue }
                let soft  = dist2 + ε2
                let dist  = sqrt(soft)
                let f     = repulsionK / soft
                let fx    = f * dx / dist
                let fy    = f * dy / dist
                forces[i].x += fx; forces[i].y += fy
                forces[j].x -= fx; forces[j].y -= fy
            }
        }

        // Spring attraction along edges
        let restLen: CGFloat = large ? 50 : 120
        for edge in edges {
            guard let si = indexMap[edge.source], let ti = indexMap[edge.target] else { continue }
            let dx   = nodes[ti].position.x - nodes[si].position.x
            let dy   = nodes[ti].position.y - nodes[si].position.y
            let dist = sqrt(dx * dx + dy * dy + ε2)
            let f    = 0.04 * (dist - restLen)
            let fx   = f * dx / dist
            let fy   = f * dy / dist
            forces[si].x += fx; forces[si].y += fy
            forces[ti].x -= fx; forces[ti].y -= fy
        }

        // Gravity toward center
        for i in 0..<count {
            forces[i].x += 0.02 * (center.x - nodes[i].position.x)
            forces[i].y += 0.02 * (center.y - nodes[i].position.y)
        }

        // Integrate, NaN-guard, clamp
        let damping: CGFloat = large ? 0.70 : 0.85
        let pad: CGFloat = 28
        let minX = pad, maxX = max(canvasSize.width  - pad, pad + 1)
        let minY = pad, maxY = max(canvasSize.height - pad, pad + 1)
        for i in 0..<count {
            var vx = (nodes[i].velocity.x + forces[i].x) * damping
            var vy = (nodes[i].velocity.y + forces[i].y) * damping
            if !vx.isFinite { vx = 0 }
            if !vy.isFinite { vy = 0 }
            nodes[i].velocity = CGPoint(x: vx, y: vy)
            let nx = nodes[i].position.x + vx
            let ny = nodes[i].position.y + vy
            nodes[i].position.x = nx.isFinite ? min(max(nx, minX), maxX) : center.x
            nodes[i].position.y = ny.isFinite ? min(max(ny, minY), maxY) : center.y
        }
    }
}
